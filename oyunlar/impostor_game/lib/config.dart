import 'package:flutter/foundation.dart';
import 'dart:html' as html; // Web için

class AppConfig {
  // Eğer Web'de çalışıyorsa otomatik olarak tarayıcının bağlandığı adresi (localhost veya domain) alır,
  // mobil cihazdaysa (APK/iOS) belirlediğin IP'yi kullanır.
  static String get serverUrl {
    if (kIsWeb) {
      // Tarayıcının bağlandığı origin'i alır (Örn: http://localhost:3000)
      return html.window.location.origin;
    }
    return 'http://10.7.9.35:3000'; // Mobil/Emulator için varsayılan IP
  }
}
