import 'dart:convert';
import 'package:http/http.dart' as http;

class Constants {
  // Default fallback URL
  static String baseUrl = 'http://localhost:8080/api/v1';

  // Google OAuth Web Client ID, loaded at runtime from /config.json. Empty
  // until a real client ID is configured server-side (GOOGLE_CLIENT_ID env),
  // in which case the Google sign-in button stays hidden.
  static String googleClientId = '169178791274-eckpjeo2aad3q9g4927q4s804jssfuom.apps.googleusercontent.com';

  static Future<void> loadConfig() async {
    try {
      final response = await http.get(Uri.parse('/config.json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['base_url'] != null && data['base_url'].toString().isNotEmpty) {
          baseUrl = data['base_url'].toString();
        }
        if (data['google_client_id'] != null) {
          googleClientId = data['google_client_id'].toString();
        }
      }
    } catch (e) {
      // relative call fails if debugging without server; keep the default URL
    }
  }
}
