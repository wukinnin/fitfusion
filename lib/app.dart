import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/motion/camera_service.dart';
import 'widgets/camera_preview_widget.dart';

class FitFusionApp extends StatelessWidget {
  const FitFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFusion',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const _TempSplashScreen(),
        '/home': (context) => const _TempHomeScreen(),
        '/select': (context) => const _StubScreen(name: 'Workout Select'),
        '/game': (context) => const CameraTestScreen(),
        '/results': (context) => const _StubScreen(name: 'Results'),
        '/leaderboard': (context) => const _StubScreen(name: 'Leaderboard'),
        '/stats': (context) => const _StubScreen(name: 'Stats'),
      },
    );
  }
}

/// Temporary splash that auto-navigates to /home after 1 second.
class _TempSplashScreen extends StatefulWidget {
  const _TempSplashScreen();

  @override
  State<_TempSplashScreen> createState() => _TempSplashScreenState();
}

class _TempSplashScreenState extends State<_TempSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Text(
          'FitFusion',
          style: TextStyle(
            color: AppTheme.gold,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Temporary stub screen. Will be replaced screen by screen in later tasks.
class _StubScreen extends StatelessWidget {
  final String name;
  const _StubScreen({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Text(
          name,
          style: const TextStyle(color: AppTheme.gold, fontSize: 24),
        ),
      ),
    );
  }
}

/// Temporary home screen with a button to test the camera.
class _TempHomeScreen extends StatelessWidget {
  const _TempHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/game'),
          child: const Text('Test Camera'),
        ),
      ),
    );
  }
}

/// Temporary screen to verify the camera feed works in isolation.
class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  final CameraService _cameraService = CameraService();
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.midnightNavy,
        body: Center(
          child: Text(
            'Camera error: $_error',
            style: const TextStyle(color: AppTheme.crimson, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppTheme.midnightNavy,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraPreviewWidget(controller: _cameraService.controller),
    );
  }
}
