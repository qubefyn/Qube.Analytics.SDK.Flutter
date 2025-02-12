import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

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

  Future<void> _captureAndMaskScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      // Take the initial screenshot
      final originalImage = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
      await originalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // Create a bitmap from the screenshot
      final codec =
      await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      // Create a new image with masked text fields
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = boundary.size;

      // Draw the original image
      canvas.drawImage(image, Offset.zero, Paint());

      // Find and mask text fields
      if (hideTextFieldContent) {
        void maskTextFields(RenderObject object, Offset parentOffset) {
          if (object is RenderEditable) {
            final transform = object.getTransformTo(boundary);
            final offset = MatrixUtils.transformPoint(transform, Offset.zero);

            // Draw a rectangle over the text field
            final paint = Paint()
              ..color = const Color(0xFFF5F5F5)
              ..style = PaintingStyle.fill;

            canvas.drawRect(
                Rect.fromLTWH(offset.dx, offset.dy, object.size.width,
                    object.size.height),
                paint);

            // Draw a line to indicate masked content
            final linePaint = Paint()
              ..color = const Color(0xFF9E9E9E)
              ..strokeWidth = 2.0;

            canvas.drawLine(
                Offset(offset.dx + 4, offset.dy + object.size.height / 2),
                Offset(offset.dx + object.size.width - 4,
                    offset.dy + object.size.height / 2),
                linePaint);
          }

          object.visitChildren((child) {
            maskTextFields(child, parentOffset);
          });
        }

        maskTextFields(boundary, Offset.zero);
      }

      // Convert to final image
      final picture = recorder.endRecording();
      final maskedImage =
      await picture.toImage(size.width.ceil(), size.height.ceil());

      final maskedByteData =
      await maskedImage.toByteData(format: ui.ImageByteFormat.png);
      if (maskedByteData == null) return;

      // Save the image
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint("❌ خطأ: لم يتم العثور على مجلد التخزين.");
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
      await file.writeAsBytes(maskedByteData.buffer.asUint8List());

      debugPrint("✅ تم حفظ لقطة الشاشة: $filePath");

      // Cleanup
      originalImage.dispose();
      image.dispose();
      maskedImage.dispose();
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