import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/providers/drink_provider.dart';

void main() {
  group('DrinkProvider category filtering', () {
    test('recognizes drink categories and ignores unrelated inventory', () {
      expect(DrinkProvider.isDrinkCategory('Drinks'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Drinks/Bar'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Beverages'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Alcoholic Drinks'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Alcolic'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Whiskey'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Juice'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Soft Drinks'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Energy Drinks'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Water'), isTrue);
      expect(DrinkProvider.isDrinkCategory('Food'), isFalse);
      expect(DrinkProvider.isDrinkCategory('Household'), isFalse);
    });
  });
}
