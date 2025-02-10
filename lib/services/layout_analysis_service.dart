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

  /// Masks the content of text fields temporarily before taking a screenshot.
  void _maskTextFieldContent(
      RenderObject renderObject, Map<RenderEditable, String> originalTexts) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      // حفظ النص الأصلي
      originalTexts[renderObject] = renderObject.text!.toPlainText();

      // إخفاء المحتوى مؤقتًا
      renderObject.text = TextSpan(
        text: '*******', // إخفاء المحتوى أثناء اللقطة فقط
        style: renderObject.text!.style,
      );
    }

    renderObject.visitChildren((child) {
      _maskTextFieldContent(child, originalTexts);
    });
  }

  /// Restores the original content of text fields after taking a screenshot.
  void _restoreTextFieldContent(
      RenderObject renderObject, Map<RenderEditable, String> originalTexts) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      // استعادة النص الأصلي
      if (originalTexts.containsKey(renderObject)) {
        renderObject.text = TextSpan(
          text: originalTexts[renderObject]!, // استعادة المحتوى
          style: renderObject.text!.style,
        );
      }
    }

    renderObject.visitChildren((child) {
      _restoreTextFieldContent(child, originalTexts);
    });
  }

  /// Captures a screenshot while temporarily hiding text field content.
  Future<void> _captureScreenshot(
      String screenName, RenderObject renderObject) async {
    try {
      if (renderObject is RenderRepaintBoundary) {
        // إنشاء خريطة لحفظ النصوص الأصلية قبل إخفائها
        Map<RenderEditable, String> originalTexts = {};

        // إخفاء النصوص قبل اللقطة
        _maskTextFieldContent(renderObject, originalTexts);

        // التقاط الصورة
        final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // إعادة النصوص الأصلية بعد اللقطة مباشرةً
        _restoreTextFieldContent(renderObject, originalTexts);

        // حفظ الصورة في التخزين
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          debugPrint("Error: External storage directory not found.");
          return;
        }

        final folderPath = '${directory.path}/QubeScreenshots';
        final folder = Directory(folderPath);
        if (!folder.existsSync()) {
          folder.createSync(recursive: true);
        }

        final filePath =
            '$folderPath/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        debugPrint("✅ Screenshot saved: $filePath");
      } else {
        debugPrint(
            "RenderObject is not a RenderRepaintBoundary, cannot capture screenshot.");
      }
    } catch (e) {
      debugPrint("❌ Error capturing screenshot: $e");
    }
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
