import 'package:flutter_test/flutter_test.dart';
import 'package:my_os/services/todos_service.dart';

void main() {
  group('stableTodoId', () {
    test('matches the sha1-based id python/todos_aggregator.py computes', () {
      // Mirrors python's `_stable_id(rel_path, text)`: sha1("rel_path|text")[:16].
      expect(stableTodoId('My Todos.md', 'Buy milk'), '68fef0f6bff5ad67');
    });

    test('is stable for the same inputs and differs for different text', () {
      final a = stableTodoId('note.md', 'Call mom');
      final b = stableTodoId('note.md', 'Call mom');
      final c = stableTodoId('note.md', 'Call dad');
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
