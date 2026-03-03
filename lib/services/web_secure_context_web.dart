// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Check if current page is served over HTTPS or localhost (required for WebUSB)
/// Only available on web platform.
bool get isSecureContext {
  try {
    final location = html.window.location.protocol;
    return location == 'https:' || 
           html.window.location.hostname == 'localhost' || 
           html.window.location.hostname == '127.0.0.1';
  } catch (e) {
    return false;
  }
}
