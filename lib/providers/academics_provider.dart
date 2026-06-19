import 'package:flutter/material.dart';

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
