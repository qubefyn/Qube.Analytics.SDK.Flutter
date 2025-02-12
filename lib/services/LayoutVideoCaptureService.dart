import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../qube_analytics_sdk.dart';
import 'layout_analysis_service.dart';

class LayoutVideoCaptureService {
  final QubeAnalyticsSDK _sdk;
  Timer? _captureTimer;
  bool _isCapturing = false;
  int _frameCount = 0;

  LayoutVideoCaptureService(this._sdk);

  void startCapture(String screenName) {
    if (_isCapturing) return;
    debugPrint("Starting video capture for $screenName");
    _isCapturing = true;
    _frameCount = 0;

    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      debugPrint("Capturing frame $_frameCount for $screenName");
      await _captureScreenshot(screenName);
    });
  }

  void stopCapture() {
    if (!_isCapturing) return;
    debugPrint("Stopping video capture");
    _captureTimer?.cancel();
    _isCapturing = false;
  }

  Future<void> _captureScreenshot(String screenName) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context == null) {
      debugPrint("Error: No currentContext found for capturing screenshot.");
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      debugPrint("Error: No valid RenderRepaintBoundary found.");
      return;
    }

    try {
      // Take the initial screenshot
      final originalImage = await renderObject.toImage(pixelRatio: 1.0);
      final byteData = await originalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // Create a bitmap from the screenshot
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      // Create a new image with masked text fields
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = renderObject.size;

      // Draw the original image
      canvas.drawImage(image, Offset.zero, Paint());

      // Find and mask text fields
      if (LayoutService.hideTextFieldContent) {
        void maskTextFields(RenderObject object, Offset parentOffset) {
          if (object is RenderEditable) {
            final transform = object.getTransformTo(renderObject);
            final offset = MatrixUtils.transformPoint(transform, Offset.zero);

            // Draw a rectangle over the text field
            final paint = Paint()
              ..color = const Color(0xFFF5F5F5)
              ..style = PaintingStyle.fill;

            canvas.drawRect(
                Rect.fromLTWH(offset.dx, offset.dy, object.size.width, object.size.height),
                paint);

            // Draw a line to indicate masked content
            final linePaint = Paint()
              ..color = const Color(0xFF9E9E9E)
              ..strokeWidth = 2.0;

            canvas.drawLine(
                Offset(offset.dx + 4, offset.dy + object.size.height / 2),
                Offset(offset.dx + object.size.width - 4, offset.dy + object.size.height / 2),
                linePaint);
          }

          object.visitChildren((child) {
            maskTextFields(child, parentOffset);
          });
        }

        maskTextFields(renderObject, Offset.zero);
      }

      // Convert to final image
      final picture = recorder.endRecording();
      final maskedImage = await picture.toImage(size.width.ceil(), size.height.ceil());

      final maskedByteData = await maskedImage.toByteData(format: ui.ImageByteFormat.png);
      if (maskedByteData == null) return;

      // Save the image
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint("❌ خطأ: لم يتم العثور على مجلد التخزين.");
        return;
      }

      final folderPath = '${directory.path}/QubeFrames';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final filePath = '$folderPath/frame_$_frameCount.png';
      final file = File(filePath);
      await file.writeAsBytes(maskedByteData.buffer.asUint8List());

      debugPrint("Screenshot saved: $filePath");
      _frameCount++;

      // Cleanup
      originalImage.dispose();
      image.dispose();
      maskedImage.dispose();
    } catch (e) {
      debugPrint("Error capturing screenshot: $e");
    }
  }
}