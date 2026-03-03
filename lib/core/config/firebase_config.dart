import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase configuration
class FirebaseConfig {
  static const String projectId = 'manage-care';
  static const String apiKey = 'YOUR_API_KEY';
  static const String appId = 'YOUR_APP_ID';
  static const String messagingSenderId = 'YOUR_MESSAGING_SENDER_ID';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    } else if (Platform.isIOS) {
      return ios;
    } else if (Platform.isAndroid) {
      return android;
    }
    throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.');
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDGnOZ1WtdvPkTgxRk3oJk9mL2pQ3rXzT8',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'manage-care',
    storageBucket: 'manage-care.appspot.com',
    iosBundleId: 'com.managecare',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDGnOZ1WtdvPkTgxRk3oJk9mL2pQ3rXzT8',
    appId: '1:123456789012:android:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'manage-care',
    storageBucket: 'manage-care.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGnOZ1WtdvPkTgxRk3oJk9mL2pQ3rXzT8',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'manage-care',
    storageBucket: 'manage-care.appspot.com',
    authDomain: 'manage-care.firebaseapp.com',
  );

  // Firestore collections
  static const String usersCollection = 'users';
  static const String businessCollection = 'businesses';
  static const String salesCollection = 'sales';
  static const String inventoryCollection = 'inventory';
  static const String customersCollection = 'customers';
  static const String workersCollection = 'workers';

  // Storage buckets
  static const String businessImagesBucket = 'business_images';
  static const String userAvatarsBucket = 'user_avatars';
  static const String receiptsBucket = 'receipts';
}

