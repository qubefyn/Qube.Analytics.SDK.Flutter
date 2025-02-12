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
  ScrollController? _scrollController;
  static bool hideTextFieldContent = true;

  LayoutService(this._sdk);

  /// ✅ تعيين `ScrollController` لالتقاط الشاشة الكاملة عند التمرير
  void setScrollController(ScrollController? controller) {
    _scrollController = controller;
  }

  /// ✅ بدء تحليل اللاي أوت واللقطات
  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer();
    log("📸 بدء تحليل الصفحة: $screenName");

    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName);
    });
  }

  /// ✅ إيقاف التحليل عند الحاجة
  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  /// ✅ تحليل اللاي أوت الحالي والتقاط الشاشة
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

  /// ✅ التقاط صورة كاملة للصفحة، بما في ذلك المحتوى القابل للتمرير
  Future<void> _captureFullScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      if (_scrollController != null && _scrollController!.hasClients) {
        final totalHeight = _scrollController!.position.maxScrollExtent +
            _scrollController!.position.viewportDimension;

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final viewportHeight = _scrollController!.position.viewportDimension;
        final originalScrollPosition = _scrollController!.position.pixels;

        int numOfScreenshots = (totalHeight / viewportHeight).ceil();

        for (int i = 0; i < numOfScreenshots; i++) {
          final targetScroll = i * viewportHeight;

          await _scrollController!.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          await Future.delayed(const Duration(milliseconds: 350));

          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) continue;

          final codec =
              await ui.instantiateImageCodec(byteData.buffer.asUint8List());
          final frameInfo = await codec.getNextFrame();

          final drawPosition = Offset(0, i * viewportHeight);
          canvas.drawImage(frameInfo.image, drawPosition, Paint());

          image.dispose();
          frameInfo.image.dispose();
        }

        await _scrollController!.animateTo(
          originalScrollPosition,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );

        final fullImage = await recorder.endRecording().toImage(
              boundary.size.width.ceil(),
              totalHeight.ceil(),
            );

        await _saveImage(screenName, fullImage);
        fullImage.dispose();
      } else {
        await _captureAndMaskScreenshot(screenName, boundary);
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
      await _captureAndMaskScreenshot(screenName, boundary);
    }
  }

  /// ✅ حفظ الصورة الملتقطة
  Future<void> _saveImage(String screenName, ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final directory = await getExternalStorageDirectory();
    if (directory == null) return;

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

  /// ✅ إخفاء محتوى التيكست فيلد أثناء التقاط الصورة
  void _maskTextFields(
      RenderRepaintBoundary boundary, Canvas canvas, Offset offset) {
    void maskTextField(RenderObject object) {
      if (object is RenderEditable) {
        final transform = object.getTransformTo(boundary);
        final adjustedOffset =
            MatrixUtils.transformPoint(transform, Offset.zero);

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

  /// ✅ التقاط صورة عادية في حال عدم وجود `ScrollController`
  Future<void> _captureAndMaskScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      await _saveImage(screenName, image);
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة العادية: $e");
    }
  }

  /// ✅ استخراج مكونات اللاي أوت
  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  /// ✅ زيارة جميع مكونات اللاي أوت وتحليلها
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

  /// ✅ تسجيل بيانات اللاي أوت
  void _logLayoutData(Map<String, dynamic> layoutData) {
    debugPrint("📜 بيانات اللاي آوت: ${jsonEncode(layoutData)}");
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
