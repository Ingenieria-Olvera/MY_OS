import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Course {
  String name;
  double credits;
  double gradePoints; // A=4.0, B=3.0, etc.

  Course({required this.name, required this.credits, required this.gradePoints});
}

class AcademicsProvider extends ChangeNotifier {
  List<Course> pastCourses = [
    Course(name: 'CS 101', credits: 3.0, gradePoints: 4.0),
    Course(name: 'MATH 201', credits: 4.0, gradePoints: 3.0),
  ];

  List<Course> currentCourses = [
    Course(name: 'CS 201', credits: 3.0, gradePoints: 4.0), // Hypothetical grade
    Course(name: 'PHYS 101', credits: 4.0, gradePoints: 4.0),
  ];

  double get currentGPA {
    double totalPoints = 0;
    double totalCredits = 0;
    for (var c in pastCourses) {
      totalPoints += (c.credits * c.gradePoints);
      totalCredits += c.credits;
    }
    return totalCredits == 0 ? 0.0 : totalPoints / totalCredits;
  }

  double get projectedGPA {
    double totalPoints = 0;
    double totalCredits = 0;
    for (var c in pastCourses) {
      totalPoints += (c.credits * c.gradePoints);
      totalCredits += c.credits;
    }
    for (var c in currentCourses) {
      totalPoints += (c.credits * c.gradePoints);
      totalCredits += c.credits;
    }
    return totalCredits == 0 ? 0.0 : totalPoints / totalCredits;
  }

  double get distanceTo4 {
    return 4.0 - currentGPA;
  }

  // --- GPA goal path ---
  static const _targetGpaKey = 'academics_target_gpa';
  static const _remainingCreditsKey = 'academics_remaining_credits';

  double targetGPA = 4.0;
  double remainingCredits = 0.0;

  AcademicsProvider() {
    _loadGoal();
  }

  double get _completedCredits {
    double total = 0;
    for (var c in pastCourses) {
      total += c.credits;
    }
    for (var c in currentCourses) {
      total += c.credits;
    }
    return total;
  }

  double get _earnedPoints {
    double total = 0;
    for (var c in pastCourses) {
      total += c.credits * c.gradePoints;
    }
    for (var c in currentCourses) {
      total += c.credits * c.gradePoints;
    }
    return total;
  }

  /// The average grade points needed across [remainingCredits] future
  /// credits to land on [targetGPA] by the time all credits are in. Null if
  /// there are no remaining credits to plan for.
  double? get requiredAverageGradePoints {
    if (remainingCredits <= 0) return null;
    final totalCredits = _completedCredits + remainingCredits;
    final neededPoints = targetGPA * totalCredits - _earnedPoints;
    return neededPoints / remainingCredits;
  }

  bool get isGoalAchievable {
    final required = requiredAverageGradePoints;
    return required == null || required <= 4.0;
  }

  Future<void> setGoal(double targetGPA, double remainingCredits) async {
    this.targetGPA = targetGPA;
    this.remainingCredits = remainingCredits;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_targetGpaKey, targetGPA);
    await prefs.setDouble(_remainingCreditsKey, remainingCredits);
  }

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    targetGPA = prefs.getDouble(_targetGpaKey) ?? 4.0;
    remainingCredits = prefs.getDouble(_remainingCreditsKey) ?? 0.0;
    notifyListeners();
  }

  // Helper method to let user edit hypothetical grades
  void updateCurrentCourseGrade(int index, double newGrade) {
    currentCourses[index].gradePoints = newGrade;
    notifyListeners();
  }

  void addCourse(bool isPast, Course course) {
    if (isPast) {
      pastCourses.add(course);
    } else {
      currentCourses.add(course);
    }
    notifyListeners();
  }

  void updateCourseDetails(bool isPast, int index, String name, double credits, double gradePoints) {
    final course = isPast ? pastCourses[index] : currentCourses[index];
    course.name = name;
    course.credits = credits;
    course.gradePoints = gradePoints;
    notifyListeners();
  }
}
