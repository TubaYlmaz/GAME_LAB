import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _configuredServerUrl = String.fromEnvironment('SERVER_URL');

  static String get serverUrl {
    if (_configuredServerUrl.isNotEmpty) return _configuredServerUrl;
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return '${uri.scheme}://${uri.authority}';
      }
      // A locally opened Flutter web build has a `file:` URL.
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000';
  }
}
