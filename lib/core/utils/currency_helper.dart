/// Helper class for currency conversions and formatting
class CurrencyHelper {
  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'KES': 'KSh',
    'ZAR': 'R',
    'NGN': '₦',
    'GHS': '₵',
    'UGX': 'USh',
  };

  static String getSymbol(String currencyCode) {
    return currencySymbols[currencyCode] ?? currencyCode;
  }

  static String formatAmount(double amount, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static double convertCurrency(double amount, double exchangeRate) {
    return amount * exchangeRate;
  }
}

