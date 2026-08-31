import 'package:flutter/foundation.dart';

class AppConfig {
  // Eğer Web'de çalışıyorsa otomatik olarak tarayıcının bağlandığı adresi (localhost veya domain) alır,
  // mobil cihazdaysa (APK/iOS) belirlediğin IP'yi kullanır.
  static String get serverUrl {
    if (kIsWeb) return Uri.base.origin;
    return 'http://10.7.9.47:3000'; // Mobil/Emulator için varsayılan IP
  }
}
