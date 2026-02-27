import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants.dart';

class PoseOverlayWidget extends StatelessWidget {
  final Pose? pose;
  final Size imageSize;

  const PoseOverlayWidget({
    super.key,
    required this.pose,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    if (pose == null) return const SizedBox.shrink();

    return SizedBox.expand(
      child: CustomPaint(
        painter: PoseOverlayPainter(pose: pose!, imageSize: imageSize),
      ),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Paint _paint;
  final Paint _linePaint;

  PoseOverlayPainter({required this.pose, required this.imageSize})
      : _paint = Paint()
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

      // Front camera is mirrored — flip x
      // landmark.x and landmark.y are normalized coordinates (0.0 - 1.0)
      // but ML Kit Pose Detection returns absolute coordinates based on the input image size
      // Wait, the prompt says:
      // "Convert normalized coordinates to screen coordinates:
      // final screenX = size.width - (landmark.x * size.width);
      // final screenY = landmark.y * size.height;"
      
      // Checking ML Kit documentation/experience:
      // Pose landmarks are usually absolute coordinates (pixels) relative to the InputImage.
      // However, the prompt explicitly says "landmark.x * size.width".
      // This implies the prompt assumes landmarks are normalized OR it wants me to normalize them first if they aren't.
      
      // Let's check the InputImage creation in PoseDetectorService.
      // We pass `metadata: InputImageMetadata(size: Size(image.width, image.height) ...)`
      // The ML Kit Pose Detection library documentation says:
      // "The x, y coordinates are relative to the image frame." (Usually pixels).
      
      // BUT, let's look at `CONTEXT.md`:
      // "306→- Landmark coordinates are normalized (0.0–1.0) relative to image dimensions. Multiply by image width/height to get pixel positions for overlay drawing."
      
      // Actually, standard google_mlkit_pose_detection returns absolute coordinates (pixels).
      // However, I must follow the prompt's instruction.
      // If the prompt says "landmark.x * size.width", it thinks they are normalized.
      // If they are NOT normalized, this code will be wrong (landmark.x will be like 300, 300 * width is huge).
      
      // Let's re-read CONTEXT.md rule 306 carefully.
      // It claims they are normalized.
      
      // However, I know for a fact `google_mlkit_pose_detection` returns pixel coordinates.
      // To satisfy the "normalized" requirement and the calculation formula in the prompt, 
      // I should probably treat them as if they need to be normalized relative to `imageSize` (the input image size)
      // and then scaled to `size` (the canvas size).
      
      // The prompt gives me `Size imageSize` in the widget.
      // In the painter, I have `Size size` (canvas size).
      
      // Formula in prompt:
      // `final screenX = size.width - (landmark.x * size.width);`
      // This assumes `landmark.x` is 0..1.
      
      // If `landmark.x` is in pixels (0..imageSize.width), then normalized is `landmark.x / imageSize.width`.
      // So the correct formula to achieve what the prompt asks (mapping input image to screen) is:
      // normalizedX = landmark.x / imageSize.width;
      // screenX = size.width - (normalizedX * size.width);
      
      // Wait, looking at the prompt again:
      // "Convert normalized coordinates to screen coordinates: // ... final screenX = size.width - (landmark.x * size.width);"
      
      // If I follow the prompt LITERALLY and `landmark.x` is pixels, it breaks.
      // If I assume the prompt implies "use the normalized value of the landmark", I should calculate that normalized value.
      // The `Pose` object from `google_mlkit_pose_detection` has `x`, `y`, `z` in image coordinates.
      
      // I will normalize them first to be safe and robust, matching the intent of the "normalized" comment.
      
      final normalizedX = landmark.x / imageSize.width;
      final normalizedY = landmark.y / imageSize.height;

      final screenX = size.width - (normalizedX * size.width);
      final screenY = normalizedY * size.height;

      canvas.drawCircle(Offset(screenX, screenY), 4, _paint);
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

      final startNormX = start.x / imageSize.width;
      final startNormY = start.y / imageSize.height;
      final startX = size.width - (startNormX * size.width);
      final startY = startNormY * size.height;

      final endNormX = end.x / imageSize.width;
      final endNormY = end.y / imageSize.height;
      final endX = size.width - (endNormX * size.width);
      final endY = endNormY * size.height;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), _linePaint);
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
