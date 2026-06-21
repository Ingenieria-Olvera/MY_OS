import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/vault_paths.dart';
import '../services/calendar_service.dart';

class CalendarProvider extends ChangeNotifier {
  List<CalendarEvent> events = [];
  List<DaySuggestion> suggestions = [];
  bool isLoading = true;

  CalendarProvider() {
    refresh();
  }

  CalendarEvent? get nextEvent {
    final now = DateTime.now();
    for (final event in events) {
      if (!event.allDay && event.end.isAfter(now)) return event;
    }
    return null;
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    final inboxDir = Directory(vaultInboxPath);
    events = await CalendarDigest.readEvents(inboxDir);
    suggestions = await CalendarDigest.readSuggestions(inboxDir);
    isLoading = false;
    notifyListeners();
  }
}
