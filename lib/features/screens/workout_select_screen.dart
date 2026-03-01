import 'package:flutter/material.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';

class WorkoutSelectScreen extends StatelessWidget {
  const WorkoutSelectScreen({super.key});

  void _onWorkoutSelected(BuildContext context, WorkoutType type) {
    Navigator.pushNamed(
      context,
      '/game',
      arguments: type,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose Your Battle',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cinzel',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _WorkoutButton(
                title: 'Squats',
                onPressed: () => _onWorkoutSelected(context, WorkoutType.squats),
              ),
              const SizedBox(height: 16),
              _WorkoutButton(
                title: 'Jumping Jacks',
                onPressed: () => _onWorkoutSelected(context, WorkoutType.jumpingJacks),
              ),
              const SizedBox(height: 16),
              _WorkoutButton(
                title: 'Side Crunches',
                onPressed: () => _onWorkoutSelected(context, WorkoutType.obliqueCrunches),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _WorkoutButton({
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.midnightNavy,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
