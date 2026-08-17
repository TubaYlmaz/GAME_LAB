import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static String get serverUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.authority}';
    }
    return 'http://10.7.9.2:3000';
  }
}
