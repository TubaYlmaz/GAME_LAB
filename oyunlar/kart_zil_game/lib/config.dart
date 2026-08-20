import 'package:flutter/foundation.dart';

class AppConfig {
  static const _configuredServerUrl = String.fromEnvironment('SERVER_URL');

  static String get serverUrl {
    if (_configuredServerUrl.isNotEmpty) return _configuredServerUrl;
    if (kIsWeb) return Uri.base.origin;
    return 'http://localhost:3000';
  }
}
