import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'core/enums.dart';
import 'core/theme.dart';
import 'features/motion/camera_service.dart';
import 'features/motion/pace_monitor.dart';
import 'features/motion/pose_detector_service.dart';
import 'features/motion/rep_detector.dart';
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
  final PaceMonitor _paceMonitor = PaceMonitor();
  RepDetector? _repDetector;
  
  bool _initialized = false;
  String? _error;
  int _repCount = 0;
  int _paceFailCount = 0;
  String _paceStatus = 'PACE: WAITING';
  Color _paceStatusColor = AppTheme.gold;

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
        
        // Initialize RepDetector
        // May be WorkoutType.squats or WorkoutType.jumpingJacks or WorkoutType.obliqueCrunches
        _repDetector = RepDetector(
          workoutType: WorkoutType.obliqueCrunches,
          poseStream: _poseDetectorService.poseStream,
        );
        
        // Listen to Reps
        _repDetector!.repStream.listen((event) {
          if (!mounted) return;
          
          if (_repCount == 0) {
            _paceMonitor.startMonitoring();
          }
          _paceMonitor.onRepReceived();
          
          setState(() {
            _repCount++;
            _paceStatus = 'PACE: OK';
            _paceStatusColor = AppTheme.emerald;
          });
        });

        // Listen to Pace Events
        _paceMonitor.paceStream.listen((event) {
          if (!mounted) return;
          
          setState(() {
            if (event.type == PaceEventType.repOnTime) {
              _paceStatus = 'PACE: OK';
              _paceStatusColor = AppTheme.emerald;
            } else {
              _paceStatus = 'PACE: FAIL ⚠';
              _paceStatusColor = AppTheme.crimson;
              _paceFailCount++;
            }
          });
        });
      }

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _resetTest() {
    setState(() {
      _repCount = 0;
      _paceFailCount = 0;
      _paceStatus = 'PACE: WAITING';
      _paceStatusColor = AppTheme.gold;
    });
    _paceMonitor.stopMonitoring();
    _repDetector?.reset();
  }

  @override
  void dispose() {
    _paceMonitor.dispose();
    _repDetector?.dispose();
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
          
          // Layer 2: Pose Overlay
          StreamBuilder<Pose?>(
            stream: _poseDetectorService.poseStream,
            builder: (context, snapshot) {
              final pose = snapshot.data;
              if (_cameraService.controller?.value.previewSize == null) {
                return const SizedBox.shrink();
              }
              return PoseOverlayWidget(
                pose: pose,
                inputImageSize: _cameraService.controller!.value.previewSize!,
                lensDirection: _cameraService.lensDirection,
                sensorOrientation: _cameraService.sensorOrientation,
              );
            },
          ),

          // Layer 3: HUD / Info
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Pose Status
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: StreamBuilder<Pose?>(
                    stream: _poseDetectorService.poseStream,
                    builder: (context, snapshot) {
                      final hasPose = snapshot.hasData && snapshot.data != null;
                      return Text(
                        hasPose ? 'Pose: ACTIVE' : 'Pose: NULL',
                        style: TextStyle(
                          color: hasPose ? AppTheme.emerald : AppTheme.crimson,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ),
                
                // Pace Status
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _paceStatus,
                    style: TextStyle(
                      color: _paceStatusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Pace Fail Count
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pace Fails: $_paceFailCount',
                    style: const TextStyle(
                      color: AppTheme.creamWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Layer 4: Rep Counter (Bottom Center)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'REPS: $_repCount',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _resetTest,
        backgroundColor: AppTheme.gold,
        child: const Icon(Icons.refresh, color: AppTheme.midnightNavy),
      ),
    );
  }
}
