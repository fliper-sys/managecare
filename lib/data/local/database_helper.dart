import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Skip database initialization on web platform
    if (kIsWeb) {
      throw Exception('Database not available on web platform');
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'business_manager.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sales table
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
        syncStatus TEXT DEFAULT 'pending'
      )
    ''');

    // Sale items table
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
        FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Inventory table
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
        minStockLevel REAL DEFAULT 0,
        unit TEXT DEFAULT 'pcs',
        expiryDate TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'pending'
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add migration logic for version 2
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
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
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
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
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'attempts < ?',
      whereArgs: [3],
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> removeSyncItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncAttempt(int id) async {
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
    final db = await database;
    await db.delete('sales');
    await db.delete('sale_items');
    await db.delete('inventory');
    await db.delete('customers');
    await db.delete('sync_queue');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

