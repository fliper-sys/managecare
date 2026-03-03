# Manage Care - Copilot Instructions

## Project Overview
Manage Care is a comprehensive Flutter business management application supporting offline and online operations for 9+ different business types including pharmacy, retail, agriculture, auto repair, salon, hotel, restaurant, bar, and real estate.

## Workspace Setup Completed
- [x] Flutter project created for Android, iOS, and Web platforms
- [x] Complete directory structure implemented with clean architecture principles
- [x] Core layer files (theme, constants, utils, errors, config)
- [x] Data layer with models and repositories structure
- [x] Domain layer with entities and use cases
- [x] Presentation layer directory structure for all business types
- [x] Common widgets created (AppBar, Button, TextField, etc.)
- [x] pubspec.yaml configured with all necessary dependencies

## Project Structure
```
lib/
├── core/        # Business logic, theme, utilities
├── data/        # Models, repositories, local storage
├── domain/      # Entities, use cases, abstract repositories
├── presentation/ # UI screens and widgets for all features
├── services/     # Firebase, auth, payment, etc.
├── providers/    # Global state management
├── routes/       # Navigation routing
└── widgets/      # Shared/common UI widgets
```

## Next Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Firebase
- Set up Firebase project at console.firebase.google.com
- Add google-services.json for Android
- Add GoogleService-Info.plist for iOS
- Update firebase_config.dart with credentials

### 3. Implement Data Layer
- Create repository implementations
- Set up local database (Hive)
- Implement sync service for offline capability

### 4. Create Authentication Flow
- Login/Register screens
- Session management
- Token refresh logic

### 5. Build Presentation Layer
- Implement screens for each business type
- Create navigation routes
- Add providers for state management

### 6. Testing
- Write unit tests
- Create widget tests
- Implement integration tests

## Key Dependencies
- **Flutter SDK**: ^3.9.2
- **Provider/Riverpod**: State management
- **Firebase**: Backend services
- **Hive**: Local database
- **Dio**: HTTP client
- **Go Router**: Navigation

## Development Tips
- Use clean architecture principles throughout
- Keep presentation logic in providers/state management
- Implement offline-first approach with Hive
- Use constants for all hard-coded values
- Follow Flutter naming conventions

## Build Commands
```bash
# Development
flutter run

# Android Build
flutter build apk --release

# iOS Build  
flutter build ios --release

# Web Build
flutter build web --release
```

## Support
For detailed API documentation: https://api.flutter.dev/
Flutter documentation: https://docs.flutter.dev/

