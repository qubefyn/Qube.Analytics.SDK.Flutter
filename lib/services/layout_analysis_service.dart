import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    debugPrint("📸 بدء تحليل الشاشة: $screenName");
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
        await _captureFullScreenshot(screenName, renderObject);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  /// ✅ **التقاط لقطة شاشة كاملة بدون تحريك الصفحة**
  Future<void> _captureFullScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      // التقاط الصورة باستخدام `toImage`
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);

      // ✅ إخفاء محتوى التيكست فيلد داخل الصورة
      final maskedImage = await _maskTextFields(image, boundary);

      // ✅ حفظ الصورة
      await _saveImage(screenName, maskedImage);

      debugPrint("✅ تم التقاط الشاشة كاملة بنجاح!");
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
    }
  }

  /// ✅ **إخفاء محتوى TextField داخل الصورة دون تغيير واجهة المستخدم**
  Future<ui.Image> _maskTextFields(
      ui.Image originalImage, RenderRepaintBoundary boundary) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // ✅ رسم الصورة الأصلية أولاً
    canvas.drawImage(originalImage, Offset.zero, paint);

    // ✅ العثور على حقول النص وإخفائها
    void maskTextField(RenderObject object) {
      if (object is RenderEditable) {
        final transform = object.getTransformTo(boundary);
        final offset = MatrixUtils.transformPoint(transform, Offset.zero);

        // ✅ رسم مستطيل أبيض فوق النص
        final rectPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        canvas.drawRect(
          Rect.fromLTWH(
              offset.dx, offset.dy, object.size.width, object.size.height),
          rectPaint,
        );

        // ✅ رسم خط أفقي بديل عن النص
        final linePaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 2.0;

        canvas.drawLine(
          Offset(offset.dx + 4, offset.dy + object.size.height / 2),
          Offset(offset.dx + object.size.width - 4,
              offset.dy + object.size.height / 2),
          linePaint,
        );
      }
      object.visitChildren(maskTextField);
    }

    boundary.visitChildren(maskTextField);

    // ✅ تحويل الصورة المعدلة إلى `ui.Image`
    return await recorder.endRecording().toImage(
          originalImage.width,
          originalImage.height,
        );
  }

  /// ✅ **حفظ الصورة في التخزين**
  Future<void> _saveImage(String screenName, ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

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
    await file.writeAsBytes(byteData.buffer.asUint8List());

    debugPrint("✅ تم حفظ لقطة الشاشة: $filePath");
  }

  /// ✅ **استخراج بيانات مكونات الشاشة**
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
      });
    }
    renderObject.visitChildren((child) {
      _visitRenderObject(child, components);
    });
  }

  bool _isTextField(RenderObject renderObject) {
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  void _logLayoutData(Map<String, dynamic> layoutData) {
    debugPrint("📜 بيانات الشاشة: ${jsonEncode(layoutData)}");
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
