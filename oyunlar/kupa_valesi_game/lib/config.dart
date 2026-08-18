import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static String get serverUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return '${uri.scheme}://${uri.authority}';
      }
      // A locally opened Flutter web build has a `file:` URL.
      return 'http://localhost:3000';
    }
    return 'http://10.7.9.2:3000';
  }
}
