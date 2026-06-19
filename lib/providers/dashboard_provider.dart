import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:health/health.dart';
import 'dart:convert';

class Investment {
  String symbol;
  double quantity;
  double costBasis;
  double currentPrice;
  double dailyChange;
  double dailyChangePercent;

  Investment({
    required this.symbol,
    required this.quantity,
    required this.costBasis,
    this.currentPrice = 0.0,
    this.dailyChange = 0.0,
    this.dailyChangePercent = 0.0,
  });

  double get totalValue => quantity * currentPrice;
  double get totalCost => quantity * costBasis;
  double get unrealizedPL => totalValue - totalCost;
  double get unrealizedPLPercent => totalCost > 0 ? (unrealizedPL / totalCost) * 100 : 0.0;
}

class FinancialGoal {
  String name;
  double targetAmount;
  double currentAmount;
  DateTime? targetDate;

  FinancialGoal({
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
  });

  double get remainingAmount => (targetAmount - currentAmount).clamp(0, double.infinity);
  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  bool get isComplete => currentAmount >= targetAmount;

  // Months left until targetDate, at least 1 so we never divide by zero.
  int? get monthsRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final months = (targetDate!.year - now.year) * 12 + (targetDate!.month - now.month);
    return months < 1 ? 1 : months;
  }

  double? get requiredMonthlyContribution {
    final months = monthsRemaining;
    if (months == null) return null;
    return remainingAmount / months;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate?.toIso8601String(),
      };

  factory FinancialGoal.fromJson(Map<String, dynamic> data) => FinancialGoal(
        name: data['name'] as String,
        targetAmount: (data['targetAmount'] as num).toDouble(),
        currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
        targetDate: data['targetDate'] != null ? DateTime.parse(data['targetDate'] as String) : null,
      );
}

class DashboardProvider extends ChangeNotifier {
  // Hardcoded as requested
  List<Investment> investments = [
    Investment(symbol: 'QQQ', quantity: 1.0, costBasis: 445.22),
    Investment(symbol: 'SMG', quantity: 1.0, costBasis: 100.0), // Placeholder cost basis
    Investment(symbol: 'VOO', quantity: 1.0, costBasis: 400.0), // Placeholder cost basis
  ];

  bool isFetchingInvestments = false;

  DashboardProvider() {
    loadOverrides();
    refreshInvestments();
    loadGoals();
  }

  Future<void> loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < investments.length; i++) {
      final keyQuantity = 'inv_${investments[i].symbol}_qty';
      final keyCost = 'inv_${investments[i].symbol}_cost';
      
      if (prefs.containsKey(keyQuantity)) {
        investments[i].quantity = prefs.getDouble(keyQuantity)!;
      }
      if (prefs.containsKey(keyCost)) {
        investments[i].costBasis = prefs.getDouble(keyCost)!;
      }
    }
    notifyListeners();
  }

  Future<void> saveOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    for (var inv in investments) {
      await prefs.setDouble('inv_${inv.symbol}_qty', inv.quantity);
      await prefs.setDouble('inv_${inv.symbol}_cost', inv.costBasis);
    }
  }

  void updateInvestment(int index, double newQuantity, double newCost) {
    investments[index].quantity = newQuantity;
    investments[index].costBasis = newCost;
    saveOverrides();
    notifyListeners();
  }

  Future<void> refreshInvestments() async {
    isFetchingInvestments = true;
    notifyListeners();

    try {
      for (var inv in investments) {
        final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/${inv.symbol}?interval=1d&range=1d');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final result = data['chart']['result'][0];
          final meta = result['meta'];
          
          inv.currentPrice = (meta['regularMarketPrice'] as num).toDouble();
          final previousClose = (meta['chartPreviousClose'] as num).toDouble();
          
          inv.dailyChange = inv.currentPrice - previousClose;
          inv.dailyChangePercent = (inv.dailyChange / previousClose) * 100;
        }
      }
    } catch (e) {
      debugPrint('Error fetching investments: $e');
    }

    isFetchingInvestments = false;
    notifyListeners();
  }

  // --- Financial Goals ---
  static const String _goalsKey = 'financial_goals';
  List<FinancialGoal> goals = [];

  Future<void> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_goalsKey);
    if (raw != null) {
      final List<dynamic> decoded = json.decode(raw);
      goals = decoded.map((g) => FinancialGoal.fromJson(g as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  Future<void> saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalsKey, json.encode(goals.map((g) => g.toJson()).toList()));
  }

  void addGoal(FinancialGoal goal) {
    goals.add(goal);
    saveGoals();
    notifyListeners();
  }

  void updateGoal(int index, FinancialGoal goal) {
    goals[index] = goal;
    saveGoals();
    notifyListeners();
  }

  void deleteGoal(int index) {
    goals.removeAt(index);
    saveGoals();
    notifyListeners();
  }

  // --- Calendar Data ---
  bool isGoogleCalendarConnected = false;
  bool isFetchingCalendar = false;
  String? nextEventTitle;
  String? nextEventTime;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [cal.CalendarApi.calendarReadonlyScope],
  );

  Future<void> connectGoogleCalendar() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        bool isAuthorized = await _googleSignIn.canAccessScopes([cal.CalendarApi.calendarReadonlyScope]);
        if (!isAuthorized) {
          isAuthorized = await _googleSignIn.requestScopes([cal.CalendarApi.calendarReadonlyScope]);
        }
        if (isAuthorized) {
          isGoogleCalendarConnected = true;
          await fetchNextEvent(account);
        } else {
          debugPrint('User denied calendar scope.');
        }
      }
    } catch (error) {
      debugPrint('Error signing in: $error');
    }
  }

  Future<void> fetchNextEvent(GoogleSignInAccount account) async {
    isFetchingCalendar = true;
    notifyListeners();

    try {
      final authHeaders = await account.authHeaders;
      final authenticateClient = _GoogleAuthClient(authHeaders);
      final calendarApi = cal.CalendarApi(authenticateClient);

      final events = await calendarApi.events.list(
        'primary',
        timeMin: DateTime.now().toUtc(),
        maxResults: 1,
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items != null && events.items!.isNotEmpty) {
        final nextEvent = events.items!.first;
        nextEventTitle = nextEvent.summary;
        final start = nextEvent.start?.dateTime ?? nextEvent.start?.date;
        if (start != null) {
          nextEventTime = '${start.hour}:${start.minute.toString().padLeft(2, "0")}';
        } else {
          nextEventTime = 'All day';
        }
      } else {
        nextEventTitle = null;
        nextEventTime = null;
      }
    } catch (e) {
      debugPrint('Error fetching calendar: $e');
    }

    isFetchingCalendar = false;
    notifyListeners();
  }

  // --- Health Data ---
  final Health _health = Health();
  bool isHealthConnected = false;
  bool isFetchingHealth = false;

  double totalCalories = 0.0;
  double proteinGrams = 0.0;
  double sleepHours = 0.0;
  int sleepScore = 0; // Hypothetical if supported by Health Connect, otherwise derived

  Future<void> connectHealth() async {
    isFetchingHealth = true;
    notifyListeners();

    try {
      final types = [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.NUTRITION, // For macros
        HealthDataType.SLEEP_SESSION,
      ];

      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      bool hasPermissions = await _health.hasPermissions(types, permissions: permissions) ?? false;
      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(types, permissions: permissions);
      }

      if (hasPermissions) {
        isHealthConnected = true;
        await fetchHealthData();
      }
    } catch (e) {
      debugPrint('Error connecting health: $e');
    }

    isFetchingHealth = false;
    notifyListeners();
  }

  Future<void> fetchHealthData() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = midnight.subtract(const Duration(days: 1));

    try {
      // 1. Fetch Nutrition / Calories
      final nutritionData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.NUTRITION, HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );

      totalCalories = 0.0;
      proteinGrams = 0.0;

      for (var data in nutritionData) {
        // We will sum the values (simplistic placeholder logic for now)
        if (data.type == HealthDataType.NUTRITION) {
          // Health plugin nutrition parsing depends on the specific map structure
          // For now we simulate with a baseline since parsing health connect macros can be complex in raw format
          proteinGrams += 20.0; // Placeholder parser
          totalCalories += 300.0; // Placeholder parser
        }
      }

      // 2. Fetch Sleep (from yesterday night to today)
      final sleepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION],
        startTime: yesterday.subtract(const Duration(hours: 12)),
        endTime: now,
      );

      sleepHours = 0.0;
      for (var s in sleepData) {
        final duration = s.dateTo.difference(s.dateFrom);
        sleepHours += duration.inMinutes / 60.0;
      }
    } catch (e) {
      debugPrint('Error fetching health data: $e');
    }
    notifyListeners();
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
