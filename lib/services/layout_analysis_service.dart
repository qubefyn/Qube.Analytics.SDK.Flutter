import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutService {
  final QubeAnalyticsSDK _sdk;
  Timer? _layoutTimer;

  // خريطة لحفظ النصوص الأصلية لكل TextField
  final Map<RenderEditable, String> _originalTextFieldContents = {};

  // تفعيل أو تعطيل إخفاء النصوص في الصور
  static bool hideTextFieldContent = true;

  LayoutService(this._sdk);

  /// بدء تحليل اللاي أوت للصفحة الحالية
  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer(); // إيقاف أي مؤقت سابق
    log("📸 بدء تحليل الصفحة: $screenName");
    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName);
    });
  }

  /// إيقاف مؤقت تحليل اللاي أوت
  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  /// تحليل الصفحة وأخذ لقطة
  Future<void> _analyzeLayout(String screenName) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        // استخراج بيانات اللاي أوت
        final components = _extractLayoutComponents(renderObject);

        // أخذ لقطة
        await _captureScreenshot(screenName, renderObject);

        // تسجيل بيانات اللاي أوت
        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  /// أخذ لقطة شاشة وإخفاء محتويات `TextField` أثناء العملية فقط
  Future<void> _captureScreenshot(
      String screenName, RenderObject renderObject) async {
    try {
      if (renderObject is RenderRepaintBoundary) {
        // 1️⃣ **حفظ محتويات جميع TextFields الأصلية**
        _saveOriginalTextFieldContents(renderObject);

        // 2️⃣ **إخفاء محتوى TextFields قبل التقاط الصورة**
        _maskTextFieldContent(renderObject);

        // **التقاط اللقطة بعد تحديث واجهة المستخدم**
        SchedulerBinding.instance.addPostFrameCallback((_) async {
          final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
          final ByteData? byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) return;
          final Uint8List pngBytes = byteData.buffer.asUint8List();

          // 4️⃣ **إعادة المحتوى الأصلي فورًا بعد التقاط الصورة**
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _restoreTextFieldContent(renderObject);
          });

          // 5️⃣ **حفظ الصورة في التخزين**
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

          debugPrint("✅ لقطة الشاشة تم حفظها: $filePath");
        });
      } else {
        debugPrint(
            "❌ RenderObject ليس RenderRepaintBoundary، لا يمكن التقاط لقطة.");
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة: $e");
    }
  }

  /// 1️⃣ **حفظ النصوص الأصلية لـ `TextField`**
  void _saveOriginalTextFieldContents(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      _originalTextFieldContents[renderObject] =
          renderObject.text!.toPlainText();
    }
    renderObject.visitChildren(_saveOriginalTextFieldContents);
  }

  /// 2️⃣ **إخفاء محتويات `TextField` مؤقتًا**
  void _maskTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      renderObject.text = TextSpan(
        text: '*****', // استبدال النص بالمحتوى المخفي
        style: renderObject.text!.style,
      );
      renderObject.markNeedsPaint();
    }
    renderObject.visitChildren(_maskTextFieldContent);
  }

  /// 3️⃣ **إعادة النصوص الأصلية بعد التقاط الصورة**
  void _restoreTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      if (_originalTextFieldContents.containsKey(renderObject)) {
        renderObject.text = TextSpan(
          text: _originalTextFieldContents[renderObject]!,
          style: renderObject.text!.style,
        );
        renderObject.markNeedsPaint();
      }
    }
    renderObject.visitChildren(_restoreTextFieldContent);
  }

  /// استخراج مكونات الصفحة والتعرف على `TextField`
  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  /// فحص كل `RenderObject` في الشجرة لاستخراج بيانات اللاي أوت
  void _visitRenderObject(
      RenderObject renderObject, List<Map<String, dynamic>> components) {
    if (renderObject is RenderBox) {
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;

      // التحقق مما إذا كان `TextField`
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

  /// التحقق مما إذا كان العنصر `TextField`
  bool _isTextField(RenderObject renderObject) {
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  /// استخراج النص من `TextField` (إذا كان موجودًا)
  String _getTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable) {
      return renderObject.text!.toPlainText();
    }
    return 'Not a TextField';
  }

  /// تسجيل بيانات اللاي أوت وحفظها في ملف
  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);
    debugPrint("📜 بيانات اللاي أوت: $jsonData", wrapWidth: 1024);
    _saveLogToFile(jsonData);
  }

  /// حفظ بيانات اللاي أوت في ملف
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

  /// إيقاف تحليل اللاي أوت
  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
