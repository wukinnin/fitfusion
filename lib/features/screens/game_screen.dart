import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../motion/camera_service.dart';
import '../motion/pace_monitor.dart';
import '../motion/pose_detector_service.dart';
import '../motion/rep_detector.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../widgets/pose_overlay_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final CameraService _cameraService = CameraService();
  final PoseDetectorService _poseDetectorService = PoseDetectorService();
  final PaceMonitor _paceMonitor = PaceMonitor();
  RepDetector? _repDetector;
  
  bool _isInit = false;
  bool _initialized = false;
  String? _error;
  bool _permissionDenied = false;
  int _repCount = 0;
  int _paceFailCount = 0;
  String _paceStatus = 'PACE: WAITING';
  Color _paceStatusColor = AppTheme.gold;
  
  // Default to squats if something goes wrong, but we expect an argument
  WorkoutType _workoutType = WorkoutType.squats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is WorkoutType) {
        _workoutType = args;
      }
      _initCamera();
      _isInit = true;
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  Future<void> _initCamera() async {
    try {
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() => _permissionDenied = true);
        }
        return;
      }

      await _cameraService.initialize();
      
      if (_cameraService.cameraDescription != null) {
        _poseDetectorService.startProcessing(
          _cameraService.frameStream,
          _cameraService.cameraDescription!,
        );
        
        // Initialize RepDetector with the selected workout type
        _repDetector = RepDetector(
          workoutType: _workoutType,
          poseStream: _poseDetectorService.poseStream,
        );
        
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

  String _getWorkoutName() {
    switch (_workoutType) {
      case WorkoutType.squats:
        return 'SQUATS';
      case WorkoutType.jumpingJacks:
        return 'JUMPING JACKS';
      case WorkoutType.obliqueCrunches:
        return 'SIDE CRUNCHES';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: AppTheme.midnightNavy,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, color: AppTheme.crimson, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _permissionDenied = false);
                    _initCamera();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
                  child: const Text('Retry', style: TextStyle(color: AppTheme.midnightNavy)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.midnightNavy,
        body: Center(
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: AppTheme.crimson),
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
          CameraPreviewWidget(controller: _cameraService.controller),
          
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

          // Top Info Panel
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
              ),
              child: Text(
                _getWorkoutName(),
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Right Status Panel
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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

          // Bottom Center Rep Counter
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'REPS',
                    style: TextStyle(
                      color: AppTheme.creamWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  Text(
                    '$_repCount',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                ],
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
