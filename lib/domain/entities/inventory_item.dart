class InventoryItem {
  final String id;
  final String businessId;
  final String name;
  final int quantity;

  InventoryItem(
      {required this.id,
      required this.businessId,
      required this.name,
      this.quantity = 0});
}

