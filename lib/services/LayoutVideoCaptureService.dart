import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../qube_analytics_sdk.dart';

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
      final ui.Image image = await renderObject.toImage();
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint("Error: Failed to convert image to byte data.");
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Get the external storage directory (next to Downloads, Pictures, etc.)
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint("Error: External storage directory not found.");
        return;
      }

      // Create a custom folder (e.g., QubeFrames)
      final folderPath = '${directory.path}/QubeFrames';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      // Save the frame in the custom folder
      final filePath = '$folderPath/frame_${_frameCount}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      debugPrint("Screenshot saved: $filePath");
      _frameCount++;
    } catch (e) {
      debugPrint("Error capturing screenshot: $e");
    }
  }
}