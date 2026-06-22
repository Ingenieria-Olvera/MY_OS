import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'calendar_service.dart';
import 'inbox_service.dart';
import 'todos_service.dart';

/// Schedules local reminders for due todos, upcoming calendar events, and
/// time-sensitive emails. All scheduling is best-effort: a failure to
/// schedule one reminder must never block the rest of a digest refresh.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const int _todoIdBase = 100000;
  static const int _eventIdBase = 200000;
  static const int _emailIdBase = 300000;

  static const List<String> _urgentKeywords = [
    'urgent',
    'asap',
    'deadline',
    'due today',
    'due tomorrow',
    'action required',
    'time-sensitive',
    'time sensitive',
    'expires',
    'expiring',
  ];

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Cancels all previously scheduled reminders and reschedules from the
  /// current digests. Called whenever the providers refresh.
  static Future<void> scheduleAll({
    required List<TodoItem> todos,
    required List<CalendarEvent> events,
    required List<EmailMessage> emails,
  }) async {
    await _plugin.cancelAll();

    final now = DateTime.now();

    for (var i = 0; i < todos.length; i++) {
      final todo = todos[i];
      if (todo.due == null) continue;
      final dueDate = DateTime.tryParse(todo.due!);
      if (dueDate == null) continue;

      var fireAt = DateTime(dueDate.year, dueDate.month, dueDate.day, 20);
      if (fireAt.isBefore(now)) {
        fireAt = now.add(const Duration(minutes: 1));
      }

      await _schedule(
        id: _todoIdBase + i,
        title: 'Todo due ${_friendlyDate(dueDate)}',
        body: todo.text,
        at: fireAt,
      );
    }

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.allDay) continue;
      final fireAt = event.start.subtract(const Duration(minutes: 15));
      if (fireAt.isBefore(now)) continue;

      await _schedule(
        id: _eventIdBase + i,
        title: 'Starting soon: ${event.summary}',
        body: 'At ${_friendlyTime(event.start)}',
        at: fireAt,
      );
    }

    for (var i = 0; i < emails.length; i++) {
      final email = emails[i];
      if (!_isTimeSensitive(email)) continue;

      await _schedule(
        id: _emailIdBase + i,
        title: 'Time-sensitive email from ${email.sender}',
        body: email.subject,
        at: now.add(const Duration(minutes: 1)),
      );
    }
  }

  static bool _isTimeSensitive(EmailMessage email) {
    if (email.labels.any((l) => l.toUpperCase() == 'IMPORTANT')) return true;
    final haystack = '${email.subject} ${email.snippet}'.toLowerCase();
    return _urgentKeywords.any(haystack.contains);
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'Reminders',
            channelDescription: 'Due todos, upcoming events, and time-sensitive emails',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Scheduling one reminder must never block the rest of the digest.
    }
  }

  static String _friendlyDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _friendlyTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
