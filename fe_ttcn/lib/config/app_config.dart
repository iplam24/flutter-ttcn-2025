// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('API_BASE_URL chưa được cấu hình trong .env');
    }
    return url;
  }

  static String get loginEndpoint => '$baseUrl/api/v1/auth/login';
  static String get termsEndpoint => '$baseUrl/api/v1/timeable/terms';
  static String get scheduleEndpoint => '$baseUrl/api/v1/timeable/schedule';
}