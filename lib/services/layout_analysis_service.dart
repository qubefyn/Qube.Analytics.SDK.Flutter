import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutService {
  final QubeAnalyticsSDK _sdk;
  Timer? _layoutTimer;
  static bool hideTextFieldContent = true;

  LayoutService(this._sdk);

  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer();
    log("📸 بدء تحليل الصفحة: $screenName");
    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName);
    });
  }

  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  Future<void> _analyzeLayout(String screenName) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        final components = _extractLayoutComponents(renderObject);
        await _captureAndMaskScreenshot(
            screenName, renderObject as RenderRepaintBoundary);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  Future<void> _captureAndMaskScreenshot(String screenName, RenderRepaintBoundary boundary) async {
    try {
      final context = _sdk.repaintBoundaryKey.currentContext;
      if (context == null) return;

      final renderObject = context.findRenderObject();
      if (renderObject == null) return;

      RenderRepaintBoundary? targetBoundary = boundary;

      // Find the correct RepaintBoundary
      void findScrollableBoundary(RenderObject obj) {
        if (obj is RenderRepaintBoundary) {
          targetBoundary = obj; // Assign to the last found RepaintBoundary
        }
        obj.visitChildren(findScrollableBoundary);
      }

      renderObject.visitChildren(findScrollableBoundary);

      if (targetBoundary == null) {
        debugPrint("❌ No valid boundary found for capturing.");
        return;
      }

      // 🛑 Wait for Flutter to finish rendering before taking a screenshot
      await Future.delayed(Duration(milliseconds: 100)); // Small delay to ensure rendering
      await WidgetsBinding.instance.endOfFrame; // Ensures frame is complete

      final ui.Image image = await targetBoundary!.toImage(pixelRatio: 1.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // Save the image
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;

      final folderPath = '${directory.path}/QubeScreenshots';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final filePath = '$folderPath/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint("✅ تم حفظ لقطة الشاشة الكاملة: $filePath");

      // Cleanup
      image.dispose();
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة: $e");
    }
  }

  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  void _visitRenderObject(
      RenderObject renderObject, List<Map<String, dynamic>> components) {
    if (renderObject is RenderBox) {
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;

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

  bool _isTextField(RenderObject renderObject) {
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  String _getTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable) {
      return renderObject.text!.toPlainText();
    }
    return 'Not a TextField';
  }

  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);
    debugPrint("📜 بيانات اللاي أوت: $jsonData", wrapWidth: 1024);
    _saveLogToFile(jsonData);
  }

  Future<void> _saveLogToFile(String logData) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;

      final folderPath = '${directory.path}/QubeLogs';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final file = File('$folderPath/layout_log.txt');
      await file.writeAsString("$logData\n", mode: FileMode.append);
    } catch (e) {
      debugPrint("❌ خطأ أثناء حفظ السجل: $e");
    }
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}