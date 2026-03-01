import 'package:flutter/material.dart';
import '../../core/theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Text(
          'Leaderboard',
          style: const TextStyle(color: AppTheme.gold, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
