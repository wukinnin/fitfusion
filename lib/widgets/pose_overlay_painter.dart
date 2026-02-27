import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants.dart';

class PoseOverlayWidget extends StatelessWidget {
  final Pose? pose;
  final Size inputImageSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  const PoseOverlayWidget({
    super.key,
    required this.pose,
    required this.inputImageSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  @override
  Widget build(BuildContext context) {
    if (pose == null) return const SizedBox.shrink();

    return SizedBox.expand(
      child: CustomPaint(
        painter: PoseOverlayPainter(
          pose: pose!,
          inputImageSize: inputImageSize,
          lensDirection: lensDirection,
          sensorOrientation: sensorOrientation,
        ),
      ),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  final Pose pose;
  final Size inputImageSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;
  final Paint _paint;
  final Paint _linePaint;

  PoseOverlayPainter({
    required this.pose,
    required this.inputImageSize,
    required this.lensDirection,
    required this.sensorOrientation,
  })  : _paint = Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.fill,
        _linePaint = Paint()
          ..color = Colors.greenAccent.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw landmarks
    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < kLandmarkLikelihoodThreshold) continue;

      final offset = _transformCoordinates(
        landmark.x,
        landmark.y,
        size,
      );

      canvas.drawCircle(offset, 4, _paint);
    }

    // Draw connections
    void drawLine(PoseLandmarkType startType, PoseLandmarkType endType) {
      final start = pose.landmarks[startType];
      final end = pose.landmarks[endType];

      if (start == null || end == null) return;
      if (start.likelihood < kLandmarkLikelihoodThreshold ||
          end.likelihood < kLandmarkLikelihoodThreshold) {
        return;
      }

      final startOffset = _transformCoordinates(start.x, start.y, size);
      final endOffset = _transformCoordinates(end.x, end.y, size);

      canvas.drawLine(startOffset, endOffset, _linePaint);
    }

    // Torso
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Arms
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Legs
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  Offset _transformCoordinates(double x, double y, Size canvasSize) {
    // 1. Determine the logical size of the ML Kit output space
    // If rotation metadata was used, ML Kit likely returns coordinates in the UPRIGHT space.
    // However, inputImageSize is the raw buffer size (usually Landscape).
    // If sensor is 90/270, the ML Kit space is swapped (Portrait).
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double imageLogicalWidth = isRotated ? inputImageSize.height : inputImageSize.width;
    final double imageLogicalHeight = isRotated ? inputImageSize.width : inputImageSize.height;

    // 2. Normalize coordinates to [0, 1] based on logical size
    double normalizedX = x / imageLogicalWidth;
    double normalizedY = y / imageLogicalHeight;

    // 3. Mirror if FRONT camera (Flip X)
    // Front camera preview is mirrored. ML Kit detection is "reality".
    // Flip X to match preview.
    if (lensDirection == CameraLensDirection.front) {
      normalizedX = 1 - normalizedX;
    }
    
    // Note: No explicit rotation step here because ML Kit + Metadata = Upright Coordinates.

    // 4. Scale to fit canvas (BoxFit.cover logic)
    // We need to determine the scale factor that covers the screen
    final double screenAspectRatio = canvasSize.width / canvasSize.height;
    final double imageAspectRatio = imageLogicalWidth / imageLogicalHeight;
    
    double scale, offsetX, offsetY;
    
    if (screenAspectRatio > imageAspectRatio) {
      // Screen is wider than image (crop top/bottom)
      // Fit width
      scale = canvasSize.width;
      
      // Calculate drawn height preserving aspect ratio
      final double drawnHeight = canvasSize.width / imageAspectRatio;
      
      offsetX = 0;
      offsetY = (canvasSize.height - drawnHeight) / 2;
      
      return Offset(
        normalizedX * scale + offsetX,
        normalizedY * drawnHeight + offsetY
      );
    } else {
      // Screen is taller/narrower (crop left/right)
      // Fit height
      final double drawnHeight = canvasSize.height;
      final double drawnWidth = canvasSize.height * imageAspectRatio;
      
      offsetX = (canvasSize.width - drawnWidth) / 2;
      offsetY = 0;
      
      return Offset(
        normalizedX * drawnWidth + offsetX,
        normalizedY * drawnHeight + offsetY
      );
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.inputImageSize != inputImageSize ||
        oldDelegate.lensDirection != lensDirection ||
        oldDelegate.sensorOrientation != sensorOrientation;
  }
}
