import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutService {
  final QubeAnalyticsSDK _sdk;
  Timer? _layoutTimer;

  // Static boolean to control text field content visibility
  static bool hideTextFieldContent = true;

  LayoutService(this._sdk);

  /// ✅ بدء تحليل اللاي آوت مع `widgetTree`
  void startLayoutAnalysis(String screenName, Widget widgetTree) {
    _stopLayoutTimer(); // تأكد من إيقاف أي مؤقت سابق
    log("Starting layout analysis for screen: $screenName");

    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName, widgetTree);
    });
  }

  /// ✅ إيقاف تحليل اللاي آوت
  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  /// ✅ تحليل اللاي آوت والتقاط لقطة للشاشة
  Future<void> _analyzeLayout(String screenName, Widget widgetTree) async {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        // ✅ لف `widgetTree` بـ Directionality لتجنب أخطاء `Stack`
        final wrappedWidgetTree = Directionality(
          textDirection: TextDirection.ltr, // أو rtl عند الحاجة
          child: widgetTree,
        );

        await _captureScreenshot(screenName, wrappedWidgetTree);
      }
    }
  }

  /// ✅ التقاط لقطة شاشة مع `widgetTree`
  Future<void> _captureScreenshot(String screenName, Widget widgetTree) async {
    try {
      final boundary = _sdk.repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        // ✅ لف `widgetTree` بـ Directionality إذا لم يكن محاطًا بها بالفعل
        final wrappedWidgetTree = Directionality(
          textDirection: TextDirection.ltr, // أو rtl
          child: widgetTree,
        );

        // ✅ مسح محتوى التيكست فيلد مؤقتًا
        _maskTextFieldContent(boundary);

        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData?.buffer.asUint8List();

        // ✅ استعادة النصوص الأصلية بعد اللقطة مباشرةً
        _restoreTextFieldContent(boundary);

        if (pngBytes != null) {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            final folderPath = '${directory.path}/QubeScreenshots';
            final folder = Directory(folderPath);
            if (!folder.existsSync()) {
              folder.createSync(recursive: true);
            }

            final filePath =
                '$folderPath/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
            final file = File(filePath);
            await file.writeAsBytes(pngBytes);

            debugPrint("✅ Screenshot saved: $filePath");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error capturing screenshot: $e");
    }
  }

  /// ✅ إخفاء محتوى الـ TextField مؤقتًا
  void _maskTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      renderObject.text = TextSpan(
        text: '*****', // إخفاء النص مؤقتًا
        style: renderObject.text!.style,
      );
    }
    renderObject.visitChildren(_maskTextFieldContent);
  }

  /// ✅ استعادة النصوص الأصلية بعد اللقطة
  void _restoreTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      renderObject.text = TextSpan(
        text: renderObject.text!.toPlainText(), // استعادة النص الأصلي
        style: renderObject.text!.style,
      );
    }
    renderObject.visitChildren(_restoreTextFieldContent);
  }

  /// ✅ استخراج مكونات اللاي آوت
  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  /// ✅ استخراج الخصائص من كل عنصر في `RenderObject`
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

  /// ✅ التعرف على `TextField` داخل `RenderObject`
  bool _isTextField(RenderObject renderObject) {
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  /// ✅ استخراج النص من الـ TextField
  String _getTextFieldContent(RenderObject renderObject) {
    if (renderObject is RenderEditable) {
      return renderObject.text!.toPlainText();
    }
    return 'Not a TextField';
  }

  /// ✅ حفظ بيانات اللاي آوت في ملف
  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);
    debugPrint("Layout Data: $jsonData", wrapWidth: 1024);
    _saveLogToFile(jsonData);
  }

  /// ✅ حفظ بيانات اللاي آوت في ملف نصي
  Future<void> _saveLogToFile(String logData) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint("Error: External storage directory not found.");
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
      debugPrint("Error writing log to file: $e");
    }
  }

  /// ✅ إيقاف تحليل اللاي آوت
  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
