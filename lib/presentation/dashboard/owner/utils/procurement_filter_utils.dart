bool isIngredientInventoryItem(Map<String, dynamic> item) {
  final category = (item['category'] ?? '').toString().trim();
  final normalizedCategory = category.toLowerCase();
  final explicitFlag = item['isIngredient'] == true || item['isIngredient'] == 'true';
  return explicitFlag || normalizedCategory.contains('ingredient');
}

bool isIngredientFilterActive(String? selectedCategory, {bool showIngredientsOnly = false}) {
  final normalizedCategory = selectedCategory?.trim().toLowerCase();
  return showIngredientsOnly || normalizedCategory == 'ingredient' || normalizedCategory == 'ingredients';
}
