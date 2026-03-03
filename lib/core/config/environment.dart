/// Environment configuration
enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static const Environment currentEnvironment = Environment.development;

  static String get apiBaseUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return 'https://dev-api.managecare.app';
      case Environment.staging:
        return 'https://staging-api.managecare.app';
      case Environment.production:
        return 'https://api.managecare.app';
    }
  }

  static bool get isProduction {
    return currentEnvironment == Environment.production;
  }

  static bool get isDevelopment {
    return currentEnvironment == Environment.development;
  }

  static bool get isStaging {
    return currentEnvironment == Environment.staging;
  }

  static bool get enableLogging {
    return !isProduction;
  }
}

