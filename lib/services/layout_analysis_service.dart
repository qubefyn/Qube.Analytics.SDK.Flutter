import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutService {
  final QubeAnalyticsSDK _sdk;
  Timer? _layoutTimer;

  // Static boolean to control text field content visibility
  static bool hideTextFieldContent = true;

  LayoutService(this._sdk);

  /// Starts the layout analysis for a specific screen.
  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer(); // Ensure no previous timer is running
    log("Starting layout analysis for screen: $screenName");
    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName);
    });
  }

  /// Stops the layout analysis timer.
  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  /// Analyzes the layout of the current screen and logs the data.
  Future<void> _analyzeLayout(String screenName) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        // Extract layout components (e.g., TextFormFields)
        final components = _extractLayoutComponents(renderObject);

        // Capture screenshot
        await _captureScreenshot(screenName, renderObject);

        // Log layout data
        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  /// Captures a screenshot of the current screen.
  Future<void> _captureScreenshot(
      String screenName, RenderObject renderObject) async {
    try {
      if (renderObject is RenderRepaintBoundary) {
        // Create an offscreen render object
        final offscreenRenderObject = _createOffscreenRenderObject(renderObject);

        // Mask text field content in the offscreen render object
        _maskTextFieldContent(offscreenRenderObject);

        final ui.Image image = await offscreenRenderObject.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Get the external storage directory (next to Downloads, Pictures, etc.)
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          debugPrint("Error: External storage directory not found.");
          return;
        }

        // Create a custom folder (e.g., QubeScreenshots)
        final folderPath = '${directory.path}/QubeScreenshots';
        final folder = Directory(folderPath);
        if (!folder.existsSync()) {
          folder.createSync(recursive: true);
        }

        // Save the screenshot in the custom folder
        final filePath =
            '$folderPath/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        debugPrint("Screenshot saved: $filePath");

        // No need to restore text field content since it was modified in the offscreen render object
      } else {
        debugPrint(
            "RenderObject is not a RenderRepaintBoundary, cannot capture screenshot.");
      }
    } catch (e) {
      debugPrint("Error capturing screenshot: $e");
    }
  }

  /// Creates an offscreen render object for screenshot capture.
  RenderRepaintBoundary _createOffscreenRenderObject(RenderRepaintBoundary original) {
    // Clone the original render object and return it
    // This is a simplified example; in practice, you may need to deep clone the render tree
    return original;
  }

  /// Masks the content of text fields in the render tree.
  void _maskTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      // Replace the text content with a placeholder (e.g., "*****")
      renderObject.text = TextSpan(
        text: '*****',
        style: renderObject.text!.style,
      );
    }
    renderObject.visitChildren(_maskTextFieldContent);
  }

  /// Extracts layout components and detects TextFields.
  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  /// Visits each RenderObject to extract its properties.
  void _visitRenderObject(
      RenderObject renderObject, List<Map<String, dynamic>> components) {
    if (renderObject is RenderBox) {
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;

      // Check if the widget is a TextField
      bool isTextField = _isTextField(renderObject);

      components.add({
        'type': renderObject.runtimeType.toString(),
        'x': offset.dx,
        'y': offset.dy,
        'width': size.width,
        'height': size.height,
        'isTextField': isTextField,
        'content': isTextField && !hideTextFieldContent
            ? _getTextFieldContent(renderObject)
            : 'Hidden',
      });
    }
    renderObject.visitChildren((child) {
      _visitRenderObject(child, components);
    });
  }

  /// Checks if the RenderObject is a TextField.
  bool _isTextField(RenderObject renderObject) {
    // You can add more conditions to detect TextFields
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  /// Gets the content of a TextField (if applicable).
  String _getTextFieldContent(RenderObject renderObject) {
    // Example: Access the text content of a TextField
    if (renderObject is RenderEditable) {
      return renderObject.text!.toPlainText();
    }
    return 'Not a TextField';
  }

  /// Logs the layout data to the console and saves it to a file.
  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);

    // 1. Log to the console
    debugPrint("Layout Data: $jsonData", wrapWidth: 1024);

    // 2. Save the log to a file
    _saveLogToFile(jsonData);
  }

  /// Saves the log data to a file for persistence.
  Future<void> _saveLogToFile(String logData) async {
    try {
      // Get the external storage directory (next to Downloads, Pictures, etc.)
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint("Error: External storage directory not found.");
        return;
      }

      // Create a custom folder (e.g., QubeLogs)
      final folderPath = '${directory.path}/QubeLogs';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      // Save the log file in the custom folder
      final file = File('$folderPath/layout_log.txt');
      await file.writeAsString("$logData\n", mode: FileMode.append);
    } catch (e) {
      debugPrint("Error writing log to file: $e");
    }
  }

  /// Stops the layout analysis.
  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}