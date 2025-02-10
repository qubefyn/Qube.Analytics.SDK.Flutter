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

  // التحكم في إخفاء محتوى TextField
  static bool hideTextFieldContent = true;

  LayoutService(this._sdk);

  /// ✅ بدء تحليل الواجهة لكل صفحة
  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer(); // إيقاف أي مؤقت سابق
    log("📸 بدء تحليل الواجهة للشاشة: $screenName");

    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName);
    });
  }

  /// ⛔ إيقاف مؤقت التحليل
  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  /// ✅ تحليل الواجهة والتقاط لقطة شاشة
  Future<void> _analyzeLayout(String screenName) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        final components = _extractLayoutComponents(renderObject);

        // ✅ إخفاء النصوص أثناء التقاط الصورة
        Map<RenderEditable, String> originalTexts = {};
        _maskTextFieldContent(renderObject, originalTexts);

        // ✅ التقاط الصورة
        await _captureScreenshot(screenName, renderObject);

        // ✅ استعادة النصوص بعد التقاط الصورة فورًا
        _restoreTextFieldContent(renderObject, originalTexts);

        // ✅ تسجيل البيانات
        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  /// ✅ إخفاء محتوى TextField أثناء اللقطة
  void _maskTextFieldContent(
      RenderObject renderObject, Map<RenderEditable, String> originalTexts) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      // حفظ النص الأصلي
      originalTexts[renderObject] = renderObject.text!.toPlainText();

      // إخفاء المحتوى أثناء اللقطة فقط
      renderObject.text = TextSpan(
        text: '*******',
        style: renderObject.text!.style,
      );

      // إعادة رسم الشاشة فورًا
      renderObject.markNeedsPaint();
    }

    renderObject.visitChildren((child) {
      _maskTextFieldContent(child, originalTexts);
    });
  }

  /// ✅ استعادة محتوى TextField بعد اللقطة مباشرة
  void _restoreTextFieldContent(
      RenderObject renderObject, Map<RenderEditable, String> originalTexts) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      if (originalTexts.containsKey(renderObject)) {
        renderObject.text = TextSpan(
          text: originalTexts[renderObject]!,
          style: renderObject.text!.style,
        );

        // إعادة رسم الشاشة فورًا
        renderObject.markNeedsPaint();
      }
    }

    renderObject.visitChildren((child) {
      _restoreTextFieldContent(child, originalTexts);
    });
  }

  /// ✅ التقاط لقطة الشاشة وحفظها
  Future<void> _captureScreenshot(
      String screenName, RenderObject renderObject) async {
    try {
      if (renderObject is RenderRepaintBoundary) {
        final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // حفظ الصورة
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          debugPrint("❌ خطأ: لم يتم العثور على مسار التخزين الخارجي.");
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
      } else {
        debugPrint(
            "❌ RenderObject ليس RenderRepaintBoundary، لا يمكن التقاط لقطة شاشة.");
      }
    } catch (e) {
      debugPrint("❌ خطأ في التقاط لقطة الشاشة: $e");
    }
  }

  /// ✅ استخراج مكونات الشاشة
  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  /// ✅ زيارة جميع المكونات وتحليلها
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

  /// ✅ التحقق مما إذا كان المكون TextField
  bool _isTextField(RenderObject renderObject) {
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  /// ✅ جلب محتوى TextField (إذا كان متاحًا)
  String _getTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable) {
      return renderObject.text!.toPlainText();
    }
    return 'Not a TextField';
  }

  /// ✅ تسجيل بيانات الواجهة
  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);
    debugPrint("📋 بيانات الواجهة: $jsonData", wrapWidth: 1024);
    _saveLogToFile(jsonData);
  }

  /// ✅ حفظ السجلات في ملف
  Future<void> _saveLogToFile(String logData) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint("❌ خطأ: لم يتم العثور على مسار التخزين الخارجي.");
        return;
      }

      final folderPath = '${directory.path}/QubeLogs';
      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final file = File('$folderPath/layout_log.txt');
      await file.writeAsString("$logData\n", mode: FileMode.append);
    } catch (e) {
      debugPrint("❌ خطأ في كتابة السجل إلى الملف: $e");
    }
  }

  /// ⛔ إيقاف تحليل الواجهة
  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
