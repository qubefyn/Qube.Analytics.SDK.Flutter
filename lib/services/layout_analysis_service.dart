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
        await _captureFullScreenshot(
            screenName, renderObject as RenderRepaintBoundary, context);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
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

  Future<void> _captureFullScreenshot(String screenName,
      RenderRepaintBoundary boundary, BuildContext context) async {
    try {
      final ScrollableState? scrollable = _findScrollableState(context);

      if (scrollable != null) {
        await _captureScrollableScreenshot(screenName, boundary, scrollable);
      } else {
        await _captureAndMaskScreenshot(screenName, boundary);
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
      await _captureAndMaskScreenshot(screenName, boundary);
    }
  }

  ScrollableState? _findScrollableState(BuildContext context) {
    try {
      return Scrollable.of(context);
    } catch (e) {
      return null;
    }
  }

  Future<void> _captureScrollableScreenshot(
    String screenName,
    RenderRepaintBoundary boundary,
    ScrollableState scrollable,
  ) async {
    final double totalHeight = scrollable.position.maxScrollExtent +
        scrollable.position.viewportDimension;
    final double viewportHeight = scrollable.position.viewportDimension;
    final double currentScrollPosition = scrollable.position.pixels;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (double i = 0; i < totalHeight; i += viewportHeight) {
      await scrollable.position.animateTo(
        i,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) continue;

      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      final drawPosition = Offset(0, i);

      canvas.drawImage(frameInfo.image, drawPosition, Paint());

      if (hideTextFieldContent) {
        _maskTextFields(boundary, canvas, drawPosition, i);
      }

      image.dispose();
      frameInfo.image.dispose();
    }

    await scrollable.position.animateTo(
      currentScrollPosition,
      duration: const Duration(milliseconds: 100),
      curve: Curves.linear,
    );

    final fullImage = await recorder.endRecording().toImage(
          boundary.size.width.ceil(),
          totalHeight.ceil(),
        );

    await _saveImage(screenName, fullImage);
  }

  void _maskTextFields(RenderObject renderObject, Canvas canvas, Offset offset,
      double scrollOffset) {
    void maskField(RenderObject object) {
      if (object is RenderEditable) {
        try {
          final transform = object.getTransformTo(renderObject);
          final objectOffset =
              MatrixUtils.transformPoint(transform, Offset.zero);
          final adjustedOffset = Offset(
              objectOffset.dx, objectOffset.dy - scrollOffset + offset.dy);

          final paint = Paint()..color = Colors.grey.shade300;
          canvas.drawRect(
              Rect.fromLTWH(adjustedOffset.dx, adjustedOffset.dy,
                  object.size.width, object.size.height),
              paint);
        } catch (e) {
          debugPrint("❌ خطأ أثناء إخفاء محتوى TextField: $e");
        }
      }
      object.visitChildren(maskField);
    }

    renderObject.visitChildren(maskField);
  }

  Future<void> _captureAndMaskScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      final maskedImage = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = boundary.size;

      canvas.drawImage(maskedImage, Offset.zero, Paint());

      if (hideTextFieldContent) {
        _maskTextFields(boundary, canvas, Offset.zero, 0);
      }

      final picture = recorder.endRecording();
      final finalImage =
          await picture.toImage(size.width.ceil(), size.height.ceil());

      await _saveImage(screenName, finalImage);

      image.dispose();
      maskedImage.dispose();
      finalImage.dispose();
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة: $e");
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

  void _logLayoutData(Map<String, dynamic> layoutData) {
    debugPrint("📜 بيانات اللاي آوت: ${jsonEncode(layoutData)}");
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
