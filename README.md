# Manage Care - Business Management Application

Manage Care is a comprehensive Flutter application designed to help businesses manage their operations efficiently. It supports multiple business types and provides offline-first capability with seamless online synchronization.

## Features

### Supported Business Types
- **Pharmacy**: Prescription management, drug inventory, patient records
- **Retail**: POS system, multi-store management, supplier handling
- **Agriculture**: Farm management, crop cycles, livestock tracking
- **Auto Repair**: Service orders, job cards, parts inventory
- **Salon**: Appointment scheduling, stylist management, commission tracking
- **Hotel**: Room management, bookings, guest services
- **Restaurant**: Table management, order taking, kitchen display
- **Bar/Drink**: POS, inventory, bottle tracking, tabs management
- **Real Estate**: Property management, tenant tracking, rent collection

### Core Features
- **Offline Capability**: Full app functionality without internet
- **Real-time Sync**: Automatic sync when online
- **Multi-user Support**: Different roles and permissions
- **Cloud Backup**: Firebase integration for data safety
- **Analytics**: Business insights and reporting
- **Mobile Receipts**: Generate and print receipts
- **Barcode Support**: Product barcode scanning
- **Flexible Pricing**: Multiple subscription tiers

## System Requirements

- **Flutter**: ^3.9.2
- **Dart**: Latest version
- **iOS**: 12.0 or higher
- **Android**: API 24 or higher

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd manage-care
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Setup
- Create Firebase project
- Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Place files in respective directories
- Update `lib/core/config/firebase_config.dart`

### 4. Run the App
```bash
flutter run
```

## Project Structure

```
lib/
├── core/                 # Core functionality
│   ├── constants/        # App-wide constants
│   ├── theme/           # App theming
│   ├── utils/           # Utility functions
│   ├── errors/          # Exception handling
│   ├── network/         # Network utilities
│   └── config/          # Configuration files
│
├── data/                 # Data layer
│   ├── models/          # Data models
│   ├── repositories/    # Repository implementations
│   └── local/           # Local storage
│
├── domain/              # Business logic
│   ├── entities/        # Domain entities
│   ├── usecases/        # Business use cases
│   └── repositories/    # Repository interfaces
│
├── presentation/        # UI layer
│   ├── auth/            # Authentication screens
│   ├── dashboard/       # Dashboard screens
│   ├── industry_specific/ # Industry-specific features
│   └── widgets/         # Reusable widgets
│
├── services/            # External services
├── providers/           # State management
├── routes/              # Navigation routing
└── widgets/             # Common widgets
```

## Architecture

This project follows **Clean Architecture** principles:

1. **Presentation Layer**: UI components, screens, and widgets
2. **Domain Layer**: Business rules and use cases
3. **Data Layer**: Data sources and repositories

## State Management

- **Provider**: For simple state management
- **Riverpod**: For more complex state scenarios

## Database

- **Hive**: Local storage for offline capability
- **Firebase Firestore**: Cloud database
- **SQLite**: Optional additional storage

## API Integration

- **Dio**: HTTP client for API calls
- **Base URL**: Configured in environment.dart

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Building

### Android APK
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Configuration

### Environment Variables
Edit `lib/core/config/environment.dart` to switch between:
- Development
- Staging
- Production

## Troubleshooting

### Common Issues

1. **Dependencies Error**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Build Cache Issue**
   ```bash
   flutter clean
   rm -rf ios/Pods ios/Podfile.lock
   flutter pub get
   flutter run
   ```

3. **Firebase Configuration**
   - Ensure `google-services.json` is in `android/app/`
   - Ensure `GoogleService-Info.plist` is in `ios/Runner/`

## Contributing

1. Follow Flutter style guide
2. Use meaningful commit messages
3. Test changes before pushing
4. Update documentation

## License

[Your License Here]

## Support

For issues and questions:
- Create an issue on GitHub
- Contact: support@managecare.app

## Changelog

### Version 1.0.0
- Initial release
- All business types supported
- Offline-first architecture
- Firebase integration
- Multi-platform support

---

**Manage Care** - Simplifying Business Management

