# Quick Start Guide - Manage Care

## ⚡ 5-Minute Setup

### 1. Install Flutter Dependencies
```bash
cd c:\Users\DELL\Desktop\mc
flutter pub get
```

### 2. Check Project Structure
Navigate through the project in VS Code to see:
- ✅ `lib/core/` - Core utilities, theme, constants
- ✅ `lib/data/` - Models and repositories
- ✅ `lib/domain/` - Business logic and entities
- ✅ `lib/presentation/` - UI screens and widgets
- ✅ `lib/services/` - External service integrations
- ✅ `lib/routes/` - Navigation routing

### 3. Run the App
```bash
flutter run
```

You'll see the Manage Care splash screen!

## 📋 What's Ready

### ✅ Implemented
- Complete project structure
- All directories for 9+ business types
- Core utilities and helpers
- Base models and entities
- Theme and styling system
- Common widgets (Button, TextField, AppBar, etc.)
- Authentication screens skeleton
- Service interfaces
- Route configuration

### 🔄 TODO (Next Steps)
- [ ] Firebase configuration
- [ ] Implement repositories
- [ ] Add state management (Provider/Riverpod)
- [ ] Build dashboard screens
- [ ] Implement industry-specific features
- [ ] Add offline sync capability
- [ ] Testing & QA

## 🎨 Available Business Types

The app structure supports:
1. **Pharmacy** - Prescription & drug management
2. **Retail** - POS & inventory
3. **Agriculture** - Farm & crop management
4. **Auto Repair** - Service orders & job cards
5. **Salon** - Appointments & scheduling
6. **Hotel** - Rooms & bookings
7. **Restaurant** - Tables & orders
8. **Bar/Drink** - POS & inventory
9. **Real Estate** - Properties & tenants

## 🔑 Key Features Structure

- **Authentication** - Login, Register, Business Selection
- **Dashboard** - Owner and Worker dashboards
- **Sales** - Sales tracking and receipts
- **Inventory** - Product and stock management
- **Customers** - Customer profiles and loyalty
- **Workers** - Staff management and payroll
- **Reports** - Analytics and exports
- **Settings** - Configuration and preferences

## 🛠️ Tech Stack

```
Frontend:  Flutter + Dart
State:     Provider/Riverpod
Database:  Hive (Local) + Firebase (Cloud)
Backend:   Firebase (Auth, Firestore, Storage)
UI:        Material Design + Custom Widgets
```

## 📂 Folder Guide

```
lib/
├── core/          → Utilities, theme, constants
├── data/          → Models, repositories, local DB
├── domain/        → Entities, use cases, interfaces
├── presentation/  → Screens, widgets, providers
├── services/      → Firebase, auth, payment, sync
├── routes/        → Navigation configuration
└── widgets/       → Shared UI components
```

## 🚀 First Development Task

1. **Configure Firebase**
   - Go to console.firebase.google.com
   - Create new project "manage-care"
   - Download JSON files for Android/iOS
   - Update `lib/core/config/firebase_config.dart`

2. **Implement Login**
   - Complete `AuthService` in `lib/services/auth_service.dart`
   - Connect to `LoginScreen` in `lib/presentation/auth/screens/`
   - Test with Firebase Authentication

3. **Create Dashboard**
   - Build `OwnerDashboard` screen
   - Add navigation from splash screen
   - Implement basic UI with data display

## 📱 Running on Different Platforms

```bash
# Android
flutter run -d emulator-5554

# iOS (macOS only)
flutter run -d iPhone\ 15

# Web
flutter run -d chrome
```

## 🎯 Project Architecture Pattern

**Clean Architecture** with:
- **Separation of Concerns** - Each layer has clear responsibility
- **Dependency Inversion** - Domain layer depends on abstractions
- **Testability** - Each layer can be tested independently
- **Scalability** - Easy to add new features
- **Maintainability** - Clear code organization

## 💡 Development Tips

1. **Use Constants** - Everything in `core/constants/`
2. **Follow Naming** - `_ScreenName`, `_BuildComponent`
3. **Keep It DRY** - Use shared widgets in `widgets/`
4. **State Management** - Use Provider/Riverpod throughout
5. **Error Handling** - Use custom exceptions in `core/errors/`

## 🔍 File Navigation

Important files to check:
- `pubspec.yaml` - All dependencies
- `lib/main.dart` - App entry point
- `lib/app.dart` - App configuration
- `lib/core/theme/app_theme.dart` - Theming
- `lib/routes/app_router.dart` - Navigation
- `lib/core/config/firebase_config.dart` - Firebase setup

## ❓ Common Questions

**Q: Where do I add a new screen?**
A: Create under `lib/presentation/[feature]/screens/`

**Q: How do I add state management?**
A: Create provider in `lib/[feature]/providers/`

**Q: Where should utilities go?**
A: Add to `lib/core/utils/` or `lib/services/`

**Q: How do I handle errors?**
A: Use exceptions from `lib/core/errors/exceptions.dart`

## 🆘 Help & Support

- **Flutter Docs**: https://docs.flutter.dev
- **Firebase Setup**: https://firebase.flutter.dev/docs/overview
- **Provider State Management**: https://pub.dev/packages/provider
- **Project README**: See `README.md` in root

---

**Ready to start building?** 🚀

Next: Install dependencies and configure Firebase!

