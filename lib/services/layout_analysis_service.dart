import 'dart:async';
import 'dart:convert';
import 'dart:developer';
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
  ScrollController? _scrollController;

  LayoutService(this._sdk);
  void setScrollController(ScrollController? controller) {
    _scrollController = controller;
  }

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
        await _captureScrollableScreenshot(screenName, renderObject, context);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  Future<void> _captureScrollableScreenshot(String screenName,
      RenderRepaintBoundary boundary, BuildContext context) async {
    try {
      // ✅ نحاول العثور على العنصر القابل للتمرير (ListView, SingleChildScrollView, etc.)
      final scrollable = Scrollable.of(context);

      // ✅ نحصل على محتوى التمرير (scrollable content)
      final RenderBox? contentBox =
          scrollable.context.findRenderObject() as RenderBox?;
      if (contentBox == null) return;

      // ✅ نحصل على الارتفاع الكلي للمحتوى
      final totalHeight = contentBox.size.height;
      final viewportHeight = scrollable.position.viewportDimension;
      final currentScrollPosition = scrollable.position.pixels;

      // ✅ نسجل صورة الصفحة بالكامل
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final numberOfScreens = (totalHeight / viewportHeight).ceil();

      for (int i = 0; i < numberOfScreens; i++) {
        final targetScroll = i * viewportHeight;

        // ✅ نحرك الصفحة لأسفل للالتقاط التدريجي
        await scrollable.position.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );

        // ✅ ننتظر ليتم تحديث الشاشة
        await Future.delayed(const Duration(milliseconds: 300));

        // ✅ نلتقط صورة للجزء الظاهر
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final codec =
            await ui.instantiateImageCodec(byteData.buffer.asUint8List());
        final frameInfo = await codec.getNextFrame();

        // ✅ نرسم الجزء الذي تم التقاطه في الـ canvas
        final drawPosition = Offset(0, i * viewportHeight);
        canvas.drawImage(frameInfo.image, drawPosition, Paint());

        // ✅ مسح محتوى التيكست فيلدز
        if (hideTextFieldContent) {
          _maskTextFields(boundary, canvas, drawPosition);
        }

        // ✅ إغلاق الموارد
        image.dispose();
        frameInfo.image.dispose();
      }

      // ✅ نعيد الصفحة إلى مكانها الأصلي بعد اللقطة
      await scrollable.position.animateTo(
        currentScrollPosition,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );

      // ✅ نحول الصورة النهائية إلى صورة قابلة للحفظ
      final fullImage = await recorder.endRecording().toImage(
            boundary.size.width.ceil(),
            totalHeight.ceil(),
          );

      // ✅ حفظ الصورة
      await _saveImage(screenName, fullImage);

      // ✅ تنظيف الذاكرة
      fullImage.dispose();
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
      await _captureAndMaskScreenshot(screenName, boundary);
    }
  }

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

    image.dispose();
  }

  void _maskTextFields(
      RenderRepaintBoundary boundary, Canvas canvas, Offset offset) {
    void maskTextField(RenderObject object) {
      if (object is RenderEditable) {
        final transform = object.getTransformTo(boundary);
        final adjustedOffset =
            MatrixUtils.transformPoint(transform, Offset.zero);

        // ✅ نرسم مستطيل أبيض فوق التيكست فيلد
        final paint = Paint()
          ..color = const Color(0xFFF5F5F5)
          ..style = PaintingStyle.fill;

        canvas.drawRect(
          Rect.fromLTWH(
            adjustedOffset.dx,
            adjustedOffset.dy + offset.dy,
            object.size.width,
            object.size.height,
          ),
          paint,
        );

        // ✅ نرسم خط أفقي بديلاً عن النص
        final linePaint = Paint()
          ..color = const Color(0xFF9E9E9E)
          ..strokeWidth = 2.0;

        canvas.drawLine(
          Offset(adjustedOffset.dx + 4,
              adjustedOffset.dy + offset.dy + object.size.height / 2),
          Offset(adjustedOffset.dx + object.size.width - 4,
              adjustedOffset.dy + offset.dy + object.size.height / 2),
          linePaint,
        );
      }
      object.visitChildren(maskTextField);
    }

    boundary.visitChildren(maskTextField);
  }

  Future<void> _captureAndMaskScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      await _saveImage(screenName, image);
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة العادية: $e");
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
    debugPrint("📜 بيانات اللاي آوت: ${jsonEncode(layoutData)}");
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
