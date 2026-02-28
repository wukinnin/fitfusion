import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants.dart';

class CameraService {
  CameraController? _controller;
  CameraDescription? _selectedCamera;
  int _frameCount = 0;

  final StreamController<CameraImage> _frameController =
      StreamController<CameraImage>.broadcast();

  CameraController? get controller => _controller;
  CameraDescription? get cameraDescription => _selectedCamera;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  Stream<CameraImage> get frameStream => _frameController.stream;
  
  CameraLensDirection get lensDirection => _selectedCamera?.lensDirection ?? CameraLensDirection.front;
  int get sensorOrientation => _selectedCamera?.sensorOrientation ?? 270;

  Future<void> initialize() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('noCameras', 'No cameras available on device.');
      }

      _selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );

      await _controller!.initialize();
      await _controller!.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('CameraService.initialize() failed: $e');
      rethrow;
    }
  }

  void _onFrame(CameraImage image) {
    _frameCount++;
    if (_frameCount % kFrameSkipCount != 0) return;
    _frameController.add(image);
  }

  Future<void> dispose() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    await _controller?.dispose();
    _controller = null;
    await _frameController.close();
  }
}
