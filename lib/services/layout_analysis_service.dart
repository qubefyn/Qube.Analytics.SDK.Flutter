import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
      if (renderObject is RenderRepaintBoundary) {
        final components = _extractLayoutComponents(renderObject);
        await _captureFullScreenshot(screenName, renderObject, context);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  Future<void> _captureFullScreenshot(String screenName,
      RenderRepaintBoundary boundary, BuildContext context) async {
    try {
      ScrollableState? scrollable = Scrollable.of(context);

      final ScrollMetrics metrics = scrollable.position;
      final double totalHeight =
          metrics.maxScrollExtent + metrics.viewportDimension;
      final double viewportHeight = metrics.viewportDimension;
      final double originalOffset = metrics.pixels;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      int segments = (totalHeight / viewportHeight).ceil();

      for (int i = 0; i < segments; i++) {
        final double segmentOffset = i * viewportHeight;

        scrollable.position.jumpTo(segmentOffset);
        await Future.delayed(const Duration(milliseconds: 100));

        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final codec =
            await ui.instantiateImageCodec(byteData.buffer.asUint8List());
        final frameInfo = await codec.getNextFrame();

        canvas.drawImage(frameInfo.image, Offset(0, segmentOffset), Paint());

        image.dispose();
        frameInfo.image.dispose();
      }

      scrollable.position.jumpTo(originalOffset);

      // ✅ استبدلنا `final` بـ `late`
      late ui.Image fullImage;
      fullImage = await recorder.endRecording().toImage(
            boundary.size.width.ceil(),
            totalHeight.ceil(),
          );

      if (hideTextFieldContent) {
        final maskRecorder = ui.PictureRecorder();
        final maskCanvas = Canvas(maskRecorder);

        final fullImageBytes =
            await fullImage.toByteData(format: ui.ImageByteFormat.png);
        if (fullImageBytes != null) {
          final codec = await ui
              .instantiateImageCodec(fullImageBytes.buffer.asUint8List());
          final frameInfo = await codec.getNextFrame();
          maskCanvas.drawImage(frameInfo.image, Offset.zero, Paint());

          void maskTextFields(RenderObject object, Offset parentOffset) {
            if (object is RenderEditable) {
              final transform = object.getTransformTo(boundary);
              final offset = MatrixUtils.transformPoint(transform, Offset.zero);
              final double adjustedY = offset.dy - originalOffset;

              final paint = Paint()
                ..color = const Color(0xFFF5F5F5)
                ..style = PaintingStyle.fill;

              maskCanvas.drawRect(
                Rect.fromLTWH(offset.dx, adjustedY, object.size.width,
                    object.size.height),
                paint,
              );

              final linePaint = Paint()
                ..color = const Color(0xFF9E9E9E)
                ..strokeWidth = 2.0;

              maskCanvas.drawLine(
                Offset(offset.dx + 4, adjustedY + object.size.height / 2),
                Offset(offset.dx + object.size.width - 4,
                    adjustedY + object.size.height / 2),
                linePaint,
              );
            }

            object.visitChildren((child) {
              maskTextFields(child, parentOffset);
            });
          }

          maskTextFields(boundary, Offset.zero);

          fullImage = await maskRecorder.endRecording().toImage(
                boundary.size.width.ceil(),
                totalHeight.ceil(),
              );
        }
      }

      final finalImageBytes =
          await fullImage.toByteData(format: ui.ImageByteFormat.png);
      if (finalImageBytes == null) return;

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        log("❌ خطأ: لم يتم العثور على مجلد التخزين.");
        return;
      }

      final folderPath = '${directory.path}/QubeScreenshots';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final filePath =
          '$folderPath/fullscreenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(finalImageBytes.buffer.asUint8List());

      log("✅ تم حفظ لقطة الشاشة الكاملة: $filePath");

      fullImage.dispose();
    } catch (e) {
      log("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
      await _captureAndMaskScreenshot(screenName, boundary);
    }
  }

  Future<void> _captureAndMaskScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      final originalImage = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await originalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = boundary.size;

      canvas.drawImage(image, Offset.zero, Paint());

      if (hideTextFieldContent) {
        void maskTextFields(RenderObject object, Offset parentOffset) {
          if (object is RenderEditable) {
            final transform = object.getTransformTo(boundary);
            final offset = MatrixUtils.transformPoint(transform, Offset.zero);

            final paint = Paint()
              ..color = const Color(0xFFF5F5F5)
              ..style = PaintingStyle.fill;

            canvas.drawRect(
                Rect.fromLTWH(offset.dx, offset.dy, object.size.width,
                    object.size.height),
                paint);

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

      final maskedImage = await recorder.endRecording().toImage(
            size.width.ceil(),
            size.height.ceil(),
          );

      final maskedByteData =
          await maskedImage.toByteData(format: ui.ImageByteFormat.png);
      if (maskedByteData == null) return;

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        log("❌ خطأ: لم يتم العثور على مجلد التخزين.");
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

      log("✅ تم حفظ لقطة الشاشة: $filePath");

      originalImage.dispose();
      image.dispose();
      maskedImage.dispose();
    } catch (e) {
      log("❌ خطأ أثناء التقاط لقطة الشاشة: $e");
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
      return renderObject.text?.toPlainText() ?? 'Empty TextField';
    }
    return 'Not a TextField';
  }

  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);
    log("📜 بيانات اللاي أوت: $jsonData");
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
      log("❌ خطأ أثناء حفظ السجل: $e");
    }
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
