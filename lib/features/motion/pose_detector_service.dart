import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:fitfusion/core/constants.dart';

class PoseDetectorService {
  late final PoseDetector _detector;
  StreamSubscription? _subscription;
  final StreamController<Pose?> _poseController = StreamController<Pose?>();
  bool _isProcessing = false;
  Uint8List? _frameBuffer;

  PoseDetectorService() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Stream<Pose?> get poseStream => _poseController.stream;

  void startProcessing(Stream<CameraImage> frameStream, CameraDescription camera) {
    _subscription = frameStream.listen((image) => _processFrame(image, camera));
  }

  Future<void> _processFrame(CameraImage image, CameraDescription camera) async {
    // Prevent concurrent processing — if we're already processing a frame, skip this one
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) {
        _poseController.add(null);
        return;
      }

      final poses = await _detector.processImage(inputImage);

      if (poses.isEmpty) {
        _poseController.add(null);
        return;
      }

      final pose = poses.first;

      // Filter: check that critical landmarks are reliable
      if (!_areCriticalLandmarksReliable(pose)) {
        _poseController.add(null);
        return;
      }

      _poseController.add(pose);
    } catch (e) {
      debugPrint('[PoseDetectorService] Error processing frame: $e');
      _poseController.add(null);
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    // Determine rotation from camera sensor orientation
    // Front camera on Android is typically 270 degrees
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    // Map sensor orientation degrees to InputImageRotation enum
    switch (sensorOrientation) {
      case 0:
        rotation = InputImageRotation.rotation0deg;
        break;
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation270deg; // front camera default
    }

    // Verify format is supported
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    
    // On Android, we expect NV21 (17) or YUV_420_888 (35)
    if (format == null || 
        (format != InputImageFormat.nv21 && format != InputImageFormat.yuv_420_888)) {
      debugPrint('[PoseDetectorService] Warning: Unexpected image format: ${image.format.raw}');
    }

    // WORKAROUND: ML Kit on Android often throws "ImageFormat is not supported" for YUV_420_888 (35).
    // However, it supports NV21 (17).
    // If we receive YUV_420_888, we lie and say it's NV21.
    // The byte structure (concatenated planes) is compatible enough for pose detection
    // (though chroma channels might be swapped, which doesn't affect the skeleton much).
    final processingFormat = (format == InputImageFormat.yuv_420_888) 
        ? InputImageFormat.nv21 
        : (format ?? InputImageFormat.nv21);

    // Concatenate all plane bytes
    // Optimization: Pre-calculate size and allocate once to avoid WriteBuffer overhead
    int totalBytes = 0;
    for (final Plane plane in image.planes) {
      totalBytes += plane.bytes.length;
    }
    
    // Reuse buffer if possible to avoid GC
    if (_frameBuffer == null || _frameBuffer!.length != totalBytes) {
      _frameBuffer = Uint8List(totalBytes);
    }
    
    int offset = 0;
    for (final Plane plane in image.planes) {
      _frameBuffer!.setAll(offset, plane.bytes);
      offset += plane.bytes.length;
    }

    return InputImage.fromBytes(
      bytes: _frameBuffer!,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: processingFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  bool _areCriticalLandmarksReliable(Pose pose) {
    const criticalLandmarks = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final type in criticalLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark == null) return false;
      if (landmark.likelihood < kLandmarkLikelihoodThreshold) return false;
    }
    return true;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _detector.close();
    await _poseController.close();
  }
}
