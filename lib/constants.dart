import 'dart:convert';
import 'package:http/http.dart' as http;

class Constants {
  // Default fallback URL
  static String baseUrl = 'http://localhost:8080/api/v1';

  static Future<void> loadConfig() async {
    try {
      final response = await http.get(Uri.parse('/config.json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['base_url'] != null && data['base_url'].toString().isNotEmpty) {
          baseUrl = data['base_url'].toString();
        }
      }
    } catch (e) {
      // relative call fails if debugging without server; keep the default URL
    }
  }
}
