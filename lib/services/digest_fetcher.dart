import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'vault_access.dart';
import '../constants/vault_paths.dart';

class DigestFetcher {
  static const _baseUrlKey = 'agent_base_url';

  static Future<Map<String, dynamic>?> read(
    String digestName,
    String filename, [
    String? inboxUri,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = (prefs.getString(_baseUrlKey) ?? '').trim();

    if (baseUrl.isNotEmpty) {
      try {
        final uri = Uri.parse('$baseUrl/digest/$digestName');
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
        }
      } catch (_) {
        // Fall back to SAF
      }
    }

    final uri = inboxUri ?? await resolveVaultInboxUri();
    if (uri == null) return null;
    final fileEntry = await VaultAccess.child(uri, filename);
    if (fileEntry == null) return null;
    return VaultAccess.readJson(fileEntry.uri);
  }
}
