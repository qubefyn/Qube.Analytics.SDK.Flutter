import 'dart:async';
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
        await _captureFullScreenshot(screenName, renderObject, context);
      }
    }
  }

  Future<void> _captureFullScreenshot(String screenName,
      RenderRepaintBoundary boundary, BuildContext context) async {
    try {
      // ✅ العثور على العنصر القابل للتمرير (ListView, ScrollView, ...etc)
      ScrollableState? scrollable = Scrollable.of(context);
      if (_scrollController == null) {
        log("❌ لا يوجد ScrollController، سيتم التقاط الجزء الظاهر فقط.");
        await _captureAndSaveScreenshot(screenName, boundary);
        return;
      }

      // ✅ حساب الارتفاع الكلي للصفحة
      final totalHeight = _scrollController!.position.maxScrollExtent +
          _scrollController!.position.viewportDimension;
      final viewportHeight = _scrollController!.position.viewportDimension;
      final originalOffset = _scrollController!.position.pixels;

      // ✅ إنشاء Canvas لدمج الصور
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      int segments = (totalHeight / viewportHeight).ceil();

      for (int i = 0; i < segments; i++) {
        final targetOffset = i * viewportHeight;

        // ✅ تحريك الـ Scroll بدون أن يشعر المستخدم
        await _scrollController!.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
        );

        // ✅ انتظار تحديث الشاشة
        await Future.delayed(const Duration(milliseconds: 200));

        // ✅ التقاط صورة لكل جزء
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final codec =
            await ui.instantiateImageCodec(byteData.buffer.asUint8List());
        final frameInfo = await codec.getNextFrame();

        canvas.drawImage(
            frameInfo.image, Offset(0, i * viewportHeight), Paint());

        image.dispose();
        frameInfo.image.dispose();
      }

      // ✅ إعادة `Scroll` إلى موضعه الأصلي
      await _scrollController!.animateTo(
        originalOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
      );

      // ✅ تحويل الصورة المجمعة إلى `Image`
      final fullImage = await recorder.endRecording().toImage(
            boundary.size.width.ceil(),
            totalHeight.ceil(),
          );

      // ✅ حفظ الصورة
      await _saveImage(screenName, fullImage);

      log("✅ تم التقاط لقطة الشاشة الكاملة بنجاح!");
    } catch (e) {
      log("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
    }
  }

  Future<void> _saveImage(String screenName, ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

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
    await file.writeAsBytes(byteData.buffer.asUint8List());

    log("✅ تم حفظ لقطة الشاشة: $filePath");
  }

  Future<void> _captureAndSaveScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      await _saveImage(screenName, image);
    } catch (e) {
      log("❌ خطأ أثناء التقاط لقطة الشاشة العادية: $e");
    }
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
