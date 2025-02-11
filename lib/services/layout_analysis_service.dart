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
        await _captureOffscreenScreenshot(screenName, renderObject);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  Future<void> _captureOffscreenScreenshot(
      String screenName, RenderObject originalRenderObject) async {
    try {
      if (originalRenderObject is RenderRepaintBoundary) {
        // احصل على الحجم الأصلي
        final size = originalRenderObject.size;

        // أنشئ صورة بيضاء فارغة بنفس الحجم
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // املأ الخلفية باللون الأبيض
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        canvas.drawRect(Offset.zero & size, paint);

        // احصل على شجرة العناصر الأصلية
        final renderElements = <RenderObject>[];
        void collectElements(RenderObject object) {
          renderElements.add(object);
          object.visitChildren(collectElements);
        }

        originalRenderObject.visitChildren(collectElements);

        // ارسم كل عنصر مع إخفاء محتوى TextFields
        for (var element in renderElements) {
          if (element is RenderBox) {
            final transform = element.getTransformTo(originalRenderObject);
            canvas.save();
            canvas.transform(transform.storage);

            if (element is RenderEditable && hideTextFieldContent) {
              // ارسم مستطيل بلون الخلفية للـ TextField
              final backgroundPaint = Paint()
                ..color = const Color(0xFFF5F5F5); // لون رمادي فاتح
              canvas.drawRect(Offset.zero & element.size, backgroundPaint);

              // ارسم النجوم بدلاً من النص
              final textPaint = Paint()
                ..color = const Color(0xFF000000); // لون أسود للنص
              canvas.drawRect(
                  Rect.fromLTWH(
                      4, element.size.height / 3, element.size.width - 8, 2),
                  textPaint);
            } else {
              try {
                // أنشئ PaintingContext مؤقت للعنصر
                final pictureRecorder = ui.PictureRecorder();
                final elementCanvas = Canvas(pictureRecorder);
                final paintContext = _CustomPaintingContext(
                    elementCanvas, Offset.zero & element.size, element.owner!);

                element.paint(paintContext, Offset.zero);
                final elementPicture = pictureRecorder.endRecording();
                canvas.drawPicture(elementPicture);
              } catch (e) {
                debugPrint('خطأ في رسم العنصر: $e');
              }
            }
            canvas.restore();
          }
        }

        // حوّل التسجيل إلى صورة
        final picture = recorder.endRecording();
        final image =
            await picture.toImage(size.width.ceil(), size.height.ceil());

        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // احفظ الصورة
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
        await file.writeAsBytes(pngBytes);

        debugPrint("✅ تم حفظ لقطة الشاشة: $filePath");

        image.dispose();
      }
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

class _CustomPaintingContext extends PaintingContext {
  @override
  final Canvas canvas;
  @override
  final Rect estimatedBounds;
  final PipelineOwner owner;

  _CustomPaintingContext(this.canvas, this.estimatedBounds, this.owner)
      : super(ContainerLayer(), estimatedBounds);

  @override
  void paintChild(RenderObject child, Offset offset) {
    if (child is RenderBox) {
      child.paint(this, offset);
    }
  }
}
