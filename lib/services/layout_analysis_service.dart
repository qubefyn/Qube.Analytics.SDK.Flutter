import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  Future<ui.Image> _renderToImage(RenderObject renderObject, Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (renderObject is RenderBox) {
      final paintContext = _DummyPaintingContext(canvas, Offset.zero, size);
      renderObject.paint(paintContext, Offset.zero);
    }

    final picture = recorder.endRecording();
    return picture.toImage(size.width.ceil(), size.height.ceil());
  }

  Future<void> _captureOffscreenScreenshot(
      String screenName, RenderObject originalRenderObject) async {
    try {
      if (originalRenderObject is RenderRepaintBoundary) {
        final size = originalRenderObject.size;
        final clonedTree = await _cloneRenderTree(originalRenderObject);
        _maskTextFieldsInClonedTree(clonedTree);

        // Render to image
        final image = await _renderToImage(clonedTree, size);

        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final Uint8List pngBytes = byteData.buffer.asUint8List();

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

  Future<RenderRepaintBoundary> _cloneRenderTree(
      RenderRepaintBoundary original) async {
    final clone = RenderRepaintBoundary();
    final cloneBox = RenderProxyBox();
    clone.child = cloneBox;

    await _cloneChildren(original, cloneBox);

    return clone;
  }

  Future<void> _cloneChildren(
      RenderObject originalChild, RenderProxyBox parent) async {
    if (originalChild is RenderEditable) {
      final delegate = _DummyTextSelectionDelegate();
      final startHandleLayerLink = LayerLink();
      final endHandleLayerLink = LayerLink();

      final newEditable = RenderEditable(
        text: originalChild.text,
        textDirection: originalChild.textDirection,
        textAlign: originalChild.textAlign,
        cursorColor: originalChild.cursorColor,
        backgroundCursorColor: originalChild.backgroundCursorColor,
        showCursor: originalChild.showCursor,
        maxLines: originalChild.maxLines,
        minLines: originalChild.minLines,
        expands: originalChild.expands,
        selection: originalChild.selection,
        offset: ViewportOffset.zero(),
        startHandleLayerLink: startHandleLayerLink,
        endHandleLayerLink: endHandleLayerLink,
        textSelectionDelegate: delegate,
        textScaler: TextScaler.linear(originalChild.textScaleFactor),
        ignorePointer: true,
      );

      parent.child = newEditable;
    } else if (originalChild is RenderBox) {
      final newBox = RenderProxyBox();
      parent.child = newBox;

      originalChild.visitChildren((child) async {
        await _cloneChildren(child, newBox);
      });
    }
  }

  void _maskTextFieldsInClonedTree(RenderObject renderObject) {
    if (renderObject is RenderEditable && hideTextFieldContent) {
      renderObject.text = TextSpan(
        text: '*****',
        style: renderObject.text!.style,
      );
      renderObject.markNeedsPaint();
    }
    renderObject.visitChildren(_maskTextFieldsInClonedTree);
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

class _DummyTextSelectionDelegate implements TextSelectionDelegate {
  @override
  TextEditingValue get textEditingValue => TextEditingValue.empty;

  @override
  void bringIntoView(TextPosition position) {}

  @override
  void hideToolbar([bool hideHandles = true]) {}

  @override
  void userUpdateTextEditingValue(
      TextEditingValue value, SelectionChangedCause cause) {}

  @override
  bool get copyEnabled => false;

  @override
  bool get cutEnabled => false;

  @override
  bool get pasteEnabled => false;

  @override
  bool get selectAllEnabled => false;

  @override
  void copySelection(SelectionChangedCause cause) {}

  @override
  void cutSelection(SelectionChangedCause cause) {}

  @override
  Future<void> pasteText(SelectionChangedCause cause) async {}

  @override
  void selectAll(SelectionChangedCause cause) {}

  @override
  bool get liveTextInputEnabled => false;

  @override
  bool get lookUpEnabled => false;

  @override
  bool get searchWebEnabled => false;

  @override
  bool get shareEnabled => false;
}

class _DummyPaintingContext extends PaintingContext {
  @override
  final Canvas canvas;
  final Offset originOffset;
  final Size size;

  _DummyPaintingContext(this.canvas, this.originOffset, this.size)
      : super(ContainerLayer(), Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  void paintChild(RenderObject child, Offset offset) {
    if (child is RenderBox) {
      child.paint(this, offset);
    }
  }
}
