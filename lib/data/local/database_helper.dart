import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hive/hive.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (kIsWeb) {
      // On web we don't use sqflite. Return a lightweight fake database
      // object so callers that await `database` don't fail. Actual
      // CRUD operations on web are handled by the methods below using
      // Hive boxes.
      return _WebDatabase.instance as Database;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Non-web: initialize sqflite database
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'business_manager.db');

    return await openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sales table
    // storeId/updatedAt/category/warehouseId are written by the various
    // offline-checkout call sites (retail, restaurant, wholesale, worker
    // sales) but weren't part of the original schema, causing "no such
    // column" failures the first time a sale was recorded offline.
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        businessId TEXT NOT NULL,
        customerId TEXT,
        totalAmount REAL NOT NULL,
        discountAmount REAL DEFAULT 0,
        taxAmount REAL DEFAULT 0,
        finalAmount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        createdBy TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'pending',
        storeId TEXT,
        category TEXT,
        warehouseId TEXT,
        syncAttempts INTEGER DEFAULT 0,
        lastSyncError TEXT,
        lastSyncAttemptAt TEXT,
        workerId TEXT,
        workerName TEXT,
        saleType TEXT,
        paymentBreakdown TEXT
      )
    ''');

    // Sale items table
    // pricingMode/inventoryUnit/saleUnit/saleUnitMultiplier/inventoryQuantity
    // are written by RetailProvider's offline checkout for the same reason.
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitPrice REAL NOT NULL,
        discount REAL DEFAULT 0,
        total REAL NOT NULL,
        pricingMode TEXT,
        inventoryUnit TEXT,
        saleUnit TEXT,
        saleUnitMultiplier REAL,
        inventoryQuantity REAL,
        FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Inventory table
    // stock mirrors quantity (some call sites read/write 'stock' instead of
    // 'quantity' to match the Firestore-side field naming) and storeId is
    // written by worker inventory screens — both caused "no such column"
    // failures when missing.
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        businessId TEXT NOT NULL,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        category TEXT,
        description TEXT,
        unitPrice REAL NOT NULL,
        costPrice REAL,
        quantity REAL NOT NULL,
        stock REAL,
        minStockLevel REAL DEFAULT 0,
        unit TEXT DEFAULT 'pcs',
        expiryDate TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'pending',
        storeId TEXT,
        wholesalePrice REAL,
        distributorPrice REAL,
        saleUnit TEXT,
        saleUnitMultiplier REAL,
        emoji TEXT
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        businessId TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        city TEXT,
        state TEXT,
        loyaltyPoints INTEGER DEFAULT 0,
        totalPurchases REAL DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'pending'
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT NOT NULL,
        attempts INTEGER DEFAULT 0,
        lastAttempt TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_sales_business ON sales(businessId)');
    await db.execute('CREATE INDEX idx_sales_sync ON sales(syncStatus)');
    await db.execute(
        'CREATE INDEX idx_inventory_business ON inventory(businessId)');
    await db.execute(
        'CREATE INDEX idx_customers_business ON customers(businessId)');
  }

  Future<void> _addColumnsIfMissing(
    Database db,
    String table,
    Map<String, String> columns,
  ) async {
    for (final entry in columns.entries) {
      try {
        await db.execute(
            'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}');
      } catch (e) {
        // Already present (or some other non-fatal issue) — safe to skip,
        // since these migrations may run more than once across versions.
        debugPrint('[DatabaseHelper] Skipping $table.${entry.key} migration: $e');
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Each block is independently gated on oldVersion so that a database
    // that already ran an earlier migration (e.g. one that reached version 2
    // during testing before the version-3 fix existed) still picks up later
    // additions — onUpgrade only re-runs the blocks whose version threshold
    // the stored oldVersion hasn't already cleared.
    if (oldVersion < 2) {
      // Existing installs created the tables without these columns (see
      // _onCreate); add them in place so already-installed apps don't hit
      // "no such column" the next time an offline sale is recorded.
      await _addColumnsIfMissing(db, 'sales', {
        'updatedAt': 'TEXT',
        'storeId': 'TEXT',
        'category': 'TEXT',
        'warehouseId': 'TEXT',
      });
      await _addColumnsIfMissing(db, 'sale_items', {
        'pricingMode': 'TEXT',
        'inventoryUnit': 'TEXT',
        'saleUnit': 'TEXT',
        'saleUnitMultiplier': 'REAL',
        'inventoryQuantity': 'REAL',
      });
    }
    if (oldVersion < 3) {
      await _addColumnsIfMissing(db, 'inventory', {
        'stock': 'REAL',
        'storeId': 'TEXT',
      });
    }
    if (oldVersion < 4) {
      // Retry-safety: track how many times a sale has failed to sync and
      // why, so repeatedly-broken records can be told apart from ones that
      // simply haven't had a chance to sync yet, instead of retrying (and
      // failing) forever unnoticed.
      await _addColumnsIfMissing(db, 'sales', {
        'syncAttempts': 'INTEGER DEFAULT 0',
        'lastSyncError': 'TEXT',
        'lastSyncAttemptAt': 'TEXT',
      });
    }
    if (oldVersion < 5) {
      // Offline sales only stored the worker under `createdBy`, which never
      // made it to Firestore's `workerId`/`workerName` fields on sync — the
      // worker's name showed as "Unknown" once the sale came back online.
      await _addColumnsIfMissing(db, 'sales', {
        'workerId': 'TEXT',
        'workerName': 'TEXT',
      });
    }
    if (oldVersion < 6) {
      await _addColumnsIfMissing(db, 'sales', {
        'saleType': 'TEXT',
      });
    }
    if (oldVersion < 9) {
      // Mixed payments are stored as JSON text locally so offline sales can
      // retain their cash/card/transfer split until sync.
      await _addColumnsIfMissing(db, 'sales', {
        'paymentBreakdown': 'TEXT',
      });
    }
    if (oldVersion < 7) {
      await _addColumnsIfMissing(db, 'inventory', {
        'wholesalePrice': 'REAL',
        'saleUnit': 'TEXT',
        'saleUnitMultiplier': 'REAL',
        'emoji': 'TEXT',
      });
    }
    if (oldVersion < 8) {
      await _addColumnsIfMissing(db, 'inventory', {
        'distributorPrice': 'REAL',
      });
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) {
      final box = await Hive.openBox(table);
      // If an id is provided, use it as key to allow deterministic retrieval
      final key = data['id'] ?? data['Id'] ?? data['ID'];
      if (key != null) {
        await box.put(key.toString(), data);
        return 0;
      }
      return await box.add(data) as int;
    }

    final db = await database;
    return await db.insert(table, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    if (kIsWeb) {
      final box = await Hive.openBox(table);
      final values = box.values.cast<dynamic>().toList();

      Iterable<Map<String, dynamic>> results = values
          .where((v) => v is Map)
          .map((v) => Map<String, dynamic>.from(v as Map));

      // Very small where parser: supports 'col = ?' and 'col < ?'
      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        if (where.contains('<')) {
          final col = where.split('<')[0].trim();
          final cmp = whereArgs[0];
          results = results.where((m) {
            final val = m[col];
            if (val is num && cmp is num) return val < cmp;
            if (val is String) return val.compareTo(cmp.toString()) < 0;
            return false;
          });
        } else if (where.contains('=')) {
          final col = where.split('=')[0].trim();
          final cmp = whereArgs[0];
          results = results.where((m) => m[col] == cmp);
        }
      }

      // Ordering (simple single-field support)
      if (orderBy != null && orderBy.isNotEmpty) {
        final parts = orderBy.split(' ');
        final col = parts[0];
        final desc = parts.length > 1 && parts[1].toLowerCase() == 'desc';
        final list = results.toList();
        list.sort((a, b) {
          final av = a[col];
          final bv = b[col];
          if (av is Comparable && bv is Comparable) {
            return desc ? bv.compareTo(av) : av.compareTo(bv);
          }
          return 0;
        });
        results = list;
      }

      if (limit != null && limit > 0) {
        results = results.take(limit);
      }

      return results.toList();
    }

    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (kIsWeb) {
      final box = await Hive.openBox(table);
      final entries = box.toMap().entries
          .where((e) {
            if (where == null) return true;
            if (whereArgs == null || whereArgs.isEmpty) return false;
            if (where.contains('=')) {
              final col = where.split('=')[0].trim();
              return (e.value as Map)[col] == whereArgs[0];
            }
            return false;
          })
          .toList();

      for (final e in entries) {
        final updated = Map<String, dynamic>.from(e.value as Map)
          ..addAll(data);
        await box.put(e.key, updated);
      }
      return entries.length;
    }

    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (kIsWeb) {
      final box = await Hive.openBox(table);
      if (where == null) {
        await box.clear();
        return 0;
      }

      final toDelete = box.toMap().entries.where((e) {
        if (whereArgs == null || whereArgs.isEmpty) return false;
        if (where.contains('=')) {
          final col = where.split('=')[0].trim();
          return (e.value as Map)[col] == whereArgs[0];
        }
        return false;
      }).toList();

      for (final e in toDelete) {
        await box.delete(e.key);
      }

      return toDelete.length;
    }

    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  // Sync operations
  Future<void> addToSyncQueue({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) {
      final box = await Hive.openBox('sync_queue');
      final id = DateTime.now().millisecondsSinceEpoch;
      final entry = {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'data': jsonEncode(data),
        'attempts': 0,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await box.put(id, entry);
      return;
    }

    final db = await database;
    await db.insert('sync_queue', {
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'data': jsonEncode(data),
      'attempts': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    if (kIsWeb) {
      final box = await Hive.openBox('sync_queue');
      final items = box.values
          .where((v) => v is Map)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((m) => (m['attempts'] as int? ?? 0) < 3)
          .toList();
      items.sort((a, b) {
        try {
          final da = DateTime.parse(a['createdAt'] as String);
          final dbb = DateTime.parse(b['createdAt'] as String);
          return da.compareTo(dbb);
        } catch (_) {
          return 0;
        }
      });
      return items;
    }

    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'attempts < ?',
      whereArgs: [3],
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> removeSyncItem(int id) async {
    if (kIsWeb) {
      final box = await Hive.openBox('sync_queue');
      await box.delete(id);
      return;
    }

    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncAttempt(int id) async {
    if (kIsWeb) {
      final box = await Hive.openBox('sync_queue');
      final entry = box.get(id);
      if (entry is Map) {
        final updated = Map<String, dynamic>.from(entry)
          ..['attempts'] = (entry['attempts'] as int? ?? 0) + 1
          ..['lastAttempt'] = DateTime.now().toIso8601String();
        await box.put(id, updated);
      }
      return;
    }

    final db = await database;
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET attempts = attempts + 1, 
          lastAttempt = ? 
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }

  // Clear all data
  Future<void> clearAllData() async {
    if (kIsWeb) {
      await Hive.deleteBoxFromDisk('sales');
      await Hive.deleteBoxFromDisk('sale_items');
      await Hive.deleteBoxFromDisk('inventory');
      await Hive.deleteBoxFromDisk('customers');
      await Hive.deleteBoxFromDisk('sync_queue');
      return;
    }

    final db = await database;
    await db.delete('sales');
    await db.delete('sale_items');
    await db.delete('inventory');
    await db.delete('customers');
    await db.delete('sync_queue');
  }

  // Close database
  Future<void> close() async {
    if (kIsWeb) {
      try {
        await Hive.close();
      } catch (_) {}
      return;
    }

    final db = await database;
    await db.close();
    _database = null;
  }
}

/// Lightweight fake Database used only to satisfy callers that `await` the
/// `database` getter on web. Actual data access uses Hive in web mode.
class _WebDatabase {
  _WebDatabase._();

  static final _WebDatabase instance = _WebDatabase._();

  Future<void> delete(String table) async {
    final box = await Hive.openBox(table);
    await box.clear();
  }

  Future<void> close() async {
    try {
      await Hive.close();
    } catch (_) {}
  }
}

