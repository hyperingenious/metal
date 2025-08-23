import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lushh/appwrite/appwrite.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const String _configUrl =
      'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/env';

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
      );

      if (res.statusCode == 200) {
        variableStatus = true;
        try {
          _config = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('Invalid JSON format in config response');
        }
      } else {
        throw Exception(
          'Failed to load config. Status code: ${res.statusCode}',
        );
      }
    } catch (e) {
      rethrow; // Let caller handle the error
    }
  }

  dynamic get(String key) => _config[key];

  Map<String, dynamic> getAll() => Map.unmodifiable(_config);
}
