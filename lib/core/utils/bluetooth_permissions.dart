import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPermissions {
  /// Request Bluetooth-related runtime permissions for Android/iOS.
  /// Returns true if the required permissions are granted.
  static Future<bool> requestBluetoothPermissions() async {
    try {
      if (Platform.isAndroid) {
        // On Android 12+ (S) request BLUETOOTH_SCAN and BLUETOOTH_CONNECT
        await Future.wait([
          Permission.bluetooth.request(),
          Permission.bluetoothScan.request(),
          Permission.bluetoothConnect.request(),
          Permission.locationWhenInUse.request(),
        ]);

        // Ensure at least bluetoothConnect and bluetoothScan are granted on Android 12+
        final connectGranted = await Permission.bluetoothConnect.isGranted;
        final scanGranted = await Permission.bluetoothScan.isGranted;
        final basic = await Permission.bluetooth.isGranted;

        return (basic || (connectGranted && scanGranted));
      } else if (Platform.isIOS) {
        // iOS will show NSBluetooth... descriptions from Info.plist
        final bluetooth = await Permission.bluetooth.request();
        return bluetooth.isGranted;
      }
    } catch (e) {
      print('Bluetooth permission request error: $e');
    }
    return true; // allow for platforms where permissions are not needed
  }
}

