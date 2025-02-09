import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutVideoCaptureService {
  final QubeAnalyticsSDK _sdk;
  Timer? _captureTimer;
  bool _isCapturing = false;
  int _frameCount = 0;

  LayoutVideoCaptureService(this._sdk);

  /// Starts capturing screenshots at regular intervals.
  void startCapture(String screenName) {
    if (_isCapturing) return; // Avoid multiple captures
    _isCapturing = true;
    _frameCount = 0;

    // Capture a screenshot every second (adjust interval as needed)
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _captureScreenshot(screenName);
    });
  }

  /// Stops capturing screenshots.
  void stopCapture() {
    if (!_isCapturing) return; // Avoid stopping if not capturing
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// Captures a screenshot of the current screen.
  Future<void> _captureScreenshot(String screenName) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context == null) return;

    final renderObject = context.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      try {
        // Capture the image as a bitmap
        final ui.Image image = await renderObject.toImage();
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final Uint8List pngBytes = byteData!.buffer.asUint8List();

        // Save the screenshot to a file
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$screenName/frame_${_frameCount}.png';
        final file = File(filePath);

        // Ensure the directory exists
        await file.parent.create(recursive: true);

        // Write the image to the file
        await file.writeAsBytes(pngBytes);

        // Log the file path (optional)
        debugPrint("Screenshot saved: $filePath");

        _frameCount++;
      } catch (e) {
        debugPrint("Error capturing screenshot: $e");
      }
    }
  }
}