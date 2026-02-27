import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'core/theme.dart';
import 'features/motion/camera_service.dart';
import 'features/motion/pose_detector_service.dart';
import 'widgets/camera_preview_widget.dart';
import 'widgets/pose_overlay_painter.dart';

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
  final PoseDetectorService _poseDetectorService = PoseDetectorService();
  
  bool _initialized = false;
  String? _error;
  Pose? _currentPose;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.initialize();
      
      // Start pose detection
      if (_cameraService.cameraDescription != null) {
        _poseDetectorService.startProcessing(
          _cameraService.frameStream,
          _cameraService.cameraDescription!,
        );
        
        // Listen for poses
        _poseDetectorService.poseStream.listen((pose) {
          if (mounted) {
            setState(() {
              _currentPose = pose;
            });
          }
        });
      }

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _poseDetectorService.dispose();
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
      body: Stack(
        children: [
          // Layer 1: Camera Feed
          CameraPreviewWidget(controller: _cameraService.controller),
          
          // Layer 2: Pose Overlay (Debug)
          PoseOverlayWidget(
            pose: _currentPose,
            imageSize: const Size(640, 480), // Default for ResolutionPreset.low
          ),
          
          // Layer 3: Debug Info
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentPose != null ? 'Pose: ACTIVE' : 'Pose: NULL',
                style: TextStyle(
                  color: _currentPose != null ? AppTheme.emerald : AppTheme.crimson,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
