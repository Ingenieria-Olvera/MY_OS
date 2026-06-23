import 'dart:convert';
import 'package:http/http.dart' as http;

class AgentError implements Exception {
  final String message;
  AgentError(this.message);

  @override
  String toString() => message;
}

/// Talks to the local agent's `/chat` endpoint (see python/agent/server.py),
/// running on the user's own machine over the home network — never a remote
/// service.
class AgentService {
  static Future<String> sendMessage(String baseUrl, String message) async {
    final uri = Uri.parse('$baseUrl/chat');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw AgentError('Could not reach the local agent at $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw AgentError('Agent returned ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['reply'] as String? ?? '';
  }

  /// Posts a correction to a suggested category/urgency (plus an optional
  /// free-text reason) to the agent's `/feedback` endpoint, which appends it
  /// to `Feedback Log.md` in the vault (see python/agent/feedback.py) — the
  /// raw signal a future learned classifier would train on.
  static Future<void> sendFeedback(
    String baseUrl, {
    required String text,
    String? suggestedCategory,
    String? chosenCategory,
    String? suggestedUrgency,
    String? chosenUrgency,
    String? reason,
  }) async {
    final uri = Uri.parse('$baseUrl/feedback');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'suggested_category': suggestedCategory,
              'chosen_category': chosenCategory,
              'suggested_urgency': suggestedUrgency,
              'chosen_urgency': chosenUrgency,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AgentError('Could not reach the local agent at $baseUrl: $e');
    }
    if (response.statusCode != 200) {
      throw AgentError('Agent returned ${response.statusCode}: ${response.body}');
    }
  }
}
