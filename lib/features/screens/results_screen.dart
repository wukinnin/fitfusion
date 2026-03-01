import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Text(
          'Results',
          style: const TextStyle(color: AppTheme.gold, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
