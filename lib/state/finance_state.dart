import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity.dart';
import '../models/goal.dart';

class FinanceState extends ChangeNotifier {
  double _safeBalance = 0.0;
  double get safeBalance => _safeBalance;

  double _monthlyIncome = 0.0;
  double get monthlyIncome => _monthlyIncome;

  double _subscriptions = 0.0;
  double get subscriptions => _subscriptions;

  double _dailyCommute = 0.0;
  double get dailyCommute => _dailyCommute;

  // ── Time Engine State ──────────────────────────────────────────────────────
  DateTime? _lastLoginDate;
  bool _hasSkippedCommuteToday = false;
  bool get hasSkippedCommuteToday => _hasSkippedCommuteToday;

  String? _profilePhotoPath;
  String? get profilePhotoPath => _profilePhotoPath;

  double get totalSavings => _goals.fold(0.0, (sum, goal) => sum + goal.savedAmount);

  /// Sum of what all goals deduct from income each month
  double get totalMonthlyGoalDeductions {
    return _goals.fold(0.0, (sum, goal) {
      int months = goal.monthsToAchieve ?? 1;
      if (months < 1) months = 1;
      return sum + (goal.targetAmount / months);
    });
  }

  List<Goal> _goals = [];
  List<Goal> get goals => _goals;

  List<Activity> _recentActivity = [];
  List<Activity> get recentActivity => _recentActivity;

  List<Map<String, dynamic>> _chatHistory = [];
  List<Map<String, dynamic>> get chatHistory => _chatHistory;

  FinanceState() {
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    _safeBalance = prefs.getDouble('safeBalance') ?? 0.0;
    _monthlyIncome = prefs.getDouble('monthlyIncome') ?? 0.0;
    _subscriptions = prefs.getDouble('subscriptions') ?? 0.0;
    _dailyCommute = prefs.getDouble('dailyCommute') ?? 0.0;
    _hasSkippedCommuteToday = prefs.getBool('hasSkippedCommuteToday') ?? false;
    _profilePhotoPath = prefs.getString('profileImagePath');

    // Load last login date
    final lastLoginStr = prefs.getString('lastLoginDate');
    if (lastLoginStr != null) {
      _lastLoginDate = DateTime.tryParse(lastLoginStr);
    }

    // Load Goals — no dummy data fallback
    final String? goalsJson = prefs.getString('goals');
    if (goalsJson != null) {
      Iterable decoded = jsonDecode(goalsJson);
      _goals = List<Goal>.from(decoded.map((model) => Goal.fromJson(model)));
    } else {
      _goals = [];
    }

    // Load Activity — no dummy data fallback
    final String? activityJson = prefs.getString('recentActivity');
    if (activityJson != null) {
      Iterable decoded = jsonDecode(activityJson);
      _recentActivity = List<Activity>.from(decoded.map((model) => Activity.fromJson(model)));
    } else {
      _recentActivity = [];
    }

    final String? chatJson = prefs.getString('chatHistory');
    if (chatJson != null) {
      Iterable decoded = jsonDecode(chatJson);
      _chatHistory = List<Map<String, dynamic>>.from(decoded);
    } else {
      _chatHistory = [
        {"role": "assistant", "content": "I'm your FinBot 3000. Ask me about your budget, or tell me you're about to buy something stupid so I can stop you."}
      ];
    }

    // Run time checks AFTER data is loaded
    await _runTimeChecks();

    notifyListeners();
  }

  /// Checks if day/month has rolled over and performs appropriate resets/rollovers
  Future<void> _runTimeChecks() async {
    final now = DateTime.now();

    if (_lastLoginDate != null) {
      final last = _lastLoginDate!;

      // ── DAILY RESET ────────────────────────────────────────────────────────
      // If the calendar day has changed, allow commute skip again
      final isDifferentDay = now.year != last.year ||
          now.month != last.month ||
          now.day != last.day;

      if (isDifferentDay) {
        _hasSkippedCommuteToday = false;
      }

      // ── MONTHLY ROLLOVER ───────────────────────────────────────────────────
      // If the calendar month (or year) has changed, perform financial rollover
      final isDifferentMonth =
          now.year != last.year || now.month != last.month;

      if (isDifferentMonth) {
        // 1. Credit monthly income
        _safeBalance += _monthlyIncome;

        // 2. Deduct subscriptions
        _safeBalance -= _subscriptions;

        // 3. Process each goal's monthly contribution
        _goals = _goals.map((goal) {
          int months = goal.monthsToAchieve ?? 1;
          if (months < 1) months = 1;
          final monthlyReq = goal.targetAmount / months;
          // Deduct from safe balance and credit to goal
          _safeBalance -= monthlyReq;
          return Goal(
            id: goal.id,
            name: goal.name,
            targetAmount: goal.targetAmount,
            monthsToAchieve: goal.monthsToAchieve,
            savedAmount: goal.savedAmount + monthlyReq,
          );
        }).toList();

        // Log the rollover as an activity
        _recentActivity.insert(0, Activity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Monthly Rollover',
          amount: _monthlyIncome,
          date: now,
          isExpense: false,
          category: 'Income',
        ));
      }
    }

    // Always update last login to today
    _lastLoginDate = now;
    await saveData();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('monthlyIncome', _monthlyIncome);
    await prefs.setDouble('safeBalance', _safeBalance);
    await prefs.setDouble('subscriptions', _subscriptions);
    await prefs.setDouble('dailyCommute', _dailyCommute);
    await prefs.setBool('hasSkippedCommuteToday', _hasSkippedCommuteToday);
    if (_lastLoginDate != null) {
      await prefs.setString('lastLoginDate', _lastLoginDate!.toIso8601String());
    }

    String goalsJson = jsonEncode(_goals.map((goal) => goal.toJson()).toList());
    await prefs.setString('goals', goalsJson);

    String activityJson = jsonEncode(_recentActivity.map((act) => act.toJson()).toList());
    await prefs.setString('recentActivity', activityJson);

    String chatJson = jsonEncode(_chatHistory);
    await prefs.setString('chatHistory', chatJson);

    if (_profilePhotoPath != null) {
      await prefs.setString('profileImagePath', _profilePhotoPath!);
    } else {
      await prefs.remove('profileImagePath');
    }
  }

  void updateProfilePhoto(String? path) {
    _profilePhotoPath = path;
    saveData();
    notifyListeners();
  }

  void _recalculateSafeBalance() {
    double goalDeductions = 0;
    for (var goal in _goals) {
      int months = goal.monthsToAchieve ?? 1;
      if (months < 1) months = 1;
      goalDeductions += (goal.targetAmount / months);
    }
    _safeBalance = _monthlyIncome - _subscriptions - (_dailyCommute * 30) - goalDeductions;
  }

  void updateBaseline(double income, double subs, double commute) {
    _monthlyIncome = income;
    _subscriptions = subs;
    _dailyCommute = commute;
    _recalculateSafeBalance();
    saveData();
    notifyListeners();
  }

  void addActivity(Activity activity) {
    _recentActivity.insert(0, activity);
    if (activity.isExpense) {
      _safeBalance -= activity.amount;
    } else {
      _safeBalance += activity.amount;
    }
    saveData();
    notifyListeners();
  }

  void addGoal(Goal goal) {
    // Give the goal a 1-month head-start if it has no saved amount yet
    final headStart = goal.savedAmount == 0 && goal.monthsToAchieve != null && goal.monthsToAchieve! > 0
        ? goal.targetAmount / goal.monthsToAchieve!
        : goal.savedAmount;
    _goals.add(Goal(
      id: goal.id,
      name: goal.name,
      targetAmount: goal.targetAmount,
      monthsToAchieve: goal.monthsToAchieve,
      savedAmount: headStart,
    ));
    _recalculateSafeBalance();
    saveData();
    notifyListeners();
  }

  void deleteGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    _recalculateSafeBalance();
    saveData();
    notifyListeners();
  }

  void replaceGoals(List<Goal> newGoals) {
    // Apply 1-month head-start to any brand-new goals that have 0 saved
    _goals = newGoals.map((goal) {
      if (goal.savedAmount == 0 && goal.monthsToAchieve != null && goal.monthsToAchieve! > 0) {
        return Goal(
          id: goal.id,
          name: goal.name,
          targetAmount: goal.targetAmount,
          monthsToAchieve: goal.monthsToAchieve,
          savedAmount: goal.targetAmount / goal.monthsToAchieve!,
        );
      }
      return goal;
    }).toList();
    _recalculateSafeBalance();
    saveData();
    notifyListeners();
  }

  void addExpense(double amount, String merchant) {
    final activity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: merchant,
      amount: amount,
      date: DateTime.now(),
      isExpense: true,
    );
    addActivity(activity);
  }

  void logFlexFund(double amount) {
    final activity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Flex Fund Used',
      amount: amount,
      date: DateTime.now(),
      isExpense: true,
      category: 'Flex Fund',
    );
    addActivity(activity);
  }

  /// Deduct a flex fund purchase from safe balance and log it as recent activity
  void deductFlexFund(double amount, String itemName) {
    final activity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: itemName,
      amount: amount,
      date: DateTime.now(),
      isExpense: true,
      category: 'Flex Fund',
    );
    addActivity(activity);
  }

  /// Log a manual cash spend — deducts from safeBalance and records it
  void addManualSpend(double amount, String title) {
    final activity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: DateTime.now(),
      isExpense: true,
      category: 'Manual',
    );
    addActivity(activity);
  }

  void addChatMessage(String role, String text) {
    _chatHistory.add({"role": role, "content": text});
    saveData();
    notifyListeners();
  }

  /// Skip today's commute — refunds dailyCommute amount back to safeBalance (once per day)
  void skipDailyCommute() {
    if (_dailyCommute <= 0) return;
    if (_hasSkippedCommuteToday) return; // Already skipped today
    _hasSkippedCommuteToday = true;
    final activity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Commute Skip Refund',
      amount: _dailyCommute,
      date: DateTime.now(),
      isExpense: false,
      category: 'Refund',
    );
    addActivity(activity);
  }

  Future<void> resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _monthlyIncome = 0.0;
    _safeBalance = 0.0;
    _subscriptions = 0.0;
    _dailyCommute = 0.0;
    _goals = [];
    _recentActivity = [];
    _chatHistory = [];
    _lastLoginDate = null;
    _hasSkippedCommuteToday = false;

    notifyListeners();
  }
}
