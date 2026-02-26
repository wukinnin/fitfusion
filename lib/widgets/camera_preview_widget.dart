import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController? controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.previewSize!.height,
          height: ctrl.value.previewSize!.width,
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }
}
