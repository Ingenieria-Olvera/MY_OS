import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/academics_provider.dart';
import '../theme/app_theme.dart';

class AcademicsScreen extends StatelessWidget {
  const AcademicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('ACADEMICS')),
      body: Consumer<AcademicsProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewCards(provider),
                const SizedBox(height: 32),
                const Text('CURRENT COURSES', style: TextStyle(color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                _buildCourseList(context, provider, isPast: false),
                const SizedBox(height: 32),
                const Text('PAST COURSES', style: TextStyle(color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                _buildCourseList(context, provider, isPast: true),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentPurple,
        onPressed: () => _showAddCourseDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final creditsController = TextEditingController();
    final gradeController = TextEditingController();
    bool isPast = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Add Course', style: TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Course Name', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextField(
                controller: creditsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Credits', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextField(
                controller: gradeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Grade Points (e.g. 4.0)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Past Course?', style: TextStyle(color: AppTheme.textPrimary)),
                  Switch(
                    value: isPast,
                    activeColor: AppTheme.accentPurple,
                    onChanged: (val) => setState(() => isPast = val),
                  ),
                ],
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text;
                final credits = double.tryParse(creditsController.text) ?? 3.0;
                final grade = double.tryParse(gradeController.text) ?? 4.0;
                if (name.isNotEmpty) {
                  Provider.of<AcademicsProvider>(context, listen: false)
                      .addCourse(isPast, Course(name: name, credits: credits, gradePoints: grade));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add', style: TextStyle(color: AppTheme.accentPurple)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(AcademicsProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            title: 'Current GPA',
            value: provider.currentGPA.toStringAsFixed(2),
            color: AppTheme.statusGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            title: 'Projected GPA',
            value: provider.projectedGPA.toStringAsFixed(2),
            color: AppTheme.accentPurple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            title: 'Distance to 4.0',
            value: provider.distanceTo4.toStringAsFixed(2),
            color: AppTheme.statusOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCourseList(BuildContext context, AcademicsProvider provider, {required bool isPast}) {
    final courses = isPast ? provider.pastCourses : provider.currentCourses;

    if (courses.isEmpty) {
      return const Text('No courses found.', style: TextStyle(color: AppTheme.textSecondary));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: courses.length,
        separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
        itemBuilder: (context, index) {
          final course = courses[index];
          return ListTile(
            title: Text(course.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text('${course.credits} Credits', style: const TextStyle(color: AppTheme.textSecondary)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => _showEditCourseDetailsDialog(context, provider, index, isPast),
                ),
                GestureDetector(
                  onTap: isPast ? null : () => _showEditGradeDialog(context, provider, index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPast ? AppTheme.statusGreen.withOpacity(0.1) : AppTheme.accentPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.gradePoints.toStringAsFixed(1),
                      style: TextStyle(
                        color: isPast ? AppTheme.statusGreen : AppTheme.accentPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditGradeDialog(BuildContext context, AcademicsProvider provider, int index) {
    final course = provider.currentCourses[index];
    final controller = TextEditingController(text: course.gradePoints.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Hypothetical Grade: ${course.name}', style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Grade Points (e.g. 4.0)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? course.gradePoints;
              provider.updateCurrentCourseGrade(index, val);
              Navigator.pop(context);
            },
            child: const Text('Simulate', style: TextStyle(color: AppTheme.accentPurple)),
          ),
        ],
      ),
    );
  }

  void _showEditCourseDetailsDialog(BuildContext context, AcademicsProvider provider, int index, bool isPast) {
    final course = isPast ? provider.pastCourses[index] : provider.currentCourses[index];
    final nameController = TextEditingController(text: course.name);
    final creditsController = TextEditingController(text: course.credits.toString());
    final gradeController = TextEditingController(text: course.gradePoints.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Course', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Course Name', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextField(
                controller: creditsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Credits', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextField(
                controller: gradeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Grade Points (e.g. 4.0)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text;
              final credits = double.tryParse(creditsController.text) ?? course.credits;
              final grade = double.tryParse(gradeController.text) ?? course.gradePoints;
              if (name.isNotEmpty) {
                provider.updateCourseDetails(isPast, index, name, credits, grade);
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.accentPurple)),
          ),
        ],
      ),
    );
  }
}
