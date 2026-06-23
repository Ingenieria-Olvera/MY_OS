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

  static Future<void> sendFeedback({
    required String baseUrl,
    required String text,
    String? suggestedCategory,
    String? chosenCategory,
    String? suggestedUrgency,
    String? chosenUrgency,
    String? reason,
  }) async {
    final uri = Uri.parse('$baseUrl/feedback');
    try {
      final response = await http
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
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw AgentError('Feedback endpoint returned ${response.statusCode}');
      }
    } catch (e) {
      throw AgentError('Could not send feedback: $e');
    }
  }

  static Future<bool> toggleTodo({
    required String baseUrl,
    required String text,
  }) async {
    final uri = Uri.parse('$baseUrl/todos/toggle');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw AgentError('Todos toggle returned ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['found'] == true;
    } catch (e) {
      throw AgentError('Could not toggle todo: $e');
    }
  }

  static Future<void> addCalendarEvent({
    required String baseUrl,
    required String summary,
    required String start,
    required String end,
    String? account,
  }) async {
    final uri = Uri.parse('$baseUrl/calendar/add');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'summary': summary,
              'start': start,
              'end': end,
              'account': account,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw AgentError('Calendar add returned ${response.statusCode}');
      }
    } catch (e) {
      throw AgentError('Could not add calendar event: $e');
    }
  }

  static Future<void> deleteCalendarEvent({
    required String baseUrl,
    required String id,
    String? account,
  }) async {
    final uri = Uri.parse('$baseUrl/calendar/delete');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'account': account,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw AgentError('Calendar delete returned ${response.statusCode}');
      }
    } catch (e) {
      throw AgentError('Could not delete calendar event: $e');
    }
  }
}
