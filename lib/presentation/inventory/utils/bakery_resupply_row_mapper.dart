/// Converts a snake_case `bakery_resupplies` row from the backend into the
/// camelCase shape the bakery screens were originally written against when
/// they read Firestore documents.
Map<String, dynamic> bakeryResupplyRowToJson(Map<String, dynamic> row) => {
      'id': row['id'],
      'businessId': row['business_id'],
      'inventoryId': row['inventory_id'],
      'inventoryName': row['inventory_name'],
      'quantity': row['quantity'],
      'unit': row['unit'],
      'bakerId': row['baker_id'],
      'bakerName': row['baker_name'],
      'notes': row['notes'],
      'performedById': row['performed_by_id'],
      'performedByName': row['performed_by_name'],
      'expectedProductionAmount': row['expected_production_amount'],
      'actualProductionAmount': row['actual_production_amount'],
      'productionUnit': row['production_unit'],
      'productionItemName': row['production_item_name'],
      'createdAt': row['created_at'],
    };
