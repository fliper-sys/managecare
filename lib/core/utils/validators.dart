/// Validators for form inputs
class Validators {
  static String? validateEmail(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value!)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Password is required';
    }
    if ((value?.length ?? 0) < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\d{10,}$');
    if (!phoneRegex.hasMatch(value!.replaceAll(RegExp(r'\D'), ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value?.isEmpty ?? true) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value!);
    if (amount == null || amount <= 0) {
      return 'Please enter a valid amount';
    }
    return null;
  }
}

