import 'package:flutter/material.dart';
import '../../core/theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Text(
          'Stats',
          style: const TextStyle(color: AppTheme.gold, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
