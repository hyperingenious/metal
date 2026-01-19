import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lushh/appwrite/appwrite.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static String get baseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
  }

  static String get _configUrl => '$baseUrl/api/v1/env';

  Map<String, dynamic> _config = {};
  bool variableStatus = false;

  Future<void> loadBootstrapConfig() async {
    try {
      // Create JWT via Appwrite
      final jwtResponse = await account.createJWT();
      final jwt = jwtResponse.jwt; // Extract the token string

      // Fetch config from server
      final res = await http.get(
        Uri.parse(_configUrl),
        headers: {'Authorization': 'Bearer $jwt', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        variableStatus = true;
        try {
          _config = jsonDecode(res.body) as Map<String, dynamic>;
          debugPrint('Config loaded successfully from $_configUrl');
        } catch (e) {
          debugPrint('Invalid JSON format in config response: $e');
        }
      } else {
        debugPrint('Failed to load config. Status code: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading bootstrap config from $_configUrl: $e');
      // Do not rethrow, let the app use defaults or handle missing config gracefully
    }
  }

  dynamic get(String key) => _config[key];

  Map<String, dynamic> getAll() => Map.unmodifiable(_config);
}
