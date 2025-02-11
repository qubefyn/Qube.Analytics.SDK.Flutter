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

  LayoutService(this._sdk);

  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer();
    log("Starting layout analysis for screen: $screenName");
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
        await _captureScreenshot(screenName, renderObject);
        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  Future<void> _captureScreenshot(String screenName, RenderObject renderObject) async {
    try {
      if (renderObject is RenderRepaintBoundary) {
        final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final Uint8List modifiedImageBytes = await _hideTextFieldsInImage(pngBytes, renderObject);

        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          debugPrint("Error: External storage directory not found.");
          return;
        }

        final folderPath = '${directory.path}/QubeScreenshots';
        final folder = Directory(folderPath);
        if (!folder.existsSync()) {
          folder.createSync(recursive: true);
        }

        final filePath = '$folderPath/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(modifiedImageBytes);

        debugPrint("Screenshot saved: $filePath");
      } else {
        debugPrint("RenderObject is not a RenderRepaintBoundary, cannot capture screenshot.");
      }
    } catch (e) {
      debugPrint("Error capturing screenshot: $e");
    }
  }

  Future<Uint8List> _hideTextFieldsInImage(Uint8List imageBytes, RenderObject rootRenderObject) async {
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint();
    canvas.drawImage(image, ui.Offset.zero, paint);

    final List<Rect> textFields = _getTextFieldRects(rootRenderObject);
    final textFieldPaint = ui.Paint()..color = ui.Color(0xFFFFFFFF);

    for (final rect in textFields) {
      canvas.drawRect(rect, textFieldPaint);
    }

    final ui.Image modifiedImage = await recorder.endRecording().toImage(image.width, image.height);
    final ByteData? byteData = await modifiedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List() ?? imageBytes;
  }

  List<Rect> _getTextFieldRects(RenderObject rootRenderObject) {
    final List<Rect> textFields = [];

    void visit(RenderObject renderObject) {
      if (renderObject is RenderBox) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;

        if (_isTextField(renderObject)) {
          textFields.add(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
        }
      }
      renderObject.visitChildren(visit);
    }

    visit(rootRenderObject);
    return textFields;
  }

  bool _isTextField(RenderObject renderObject) {
    return renderObject.runtimeType.toString().contains('EditableText');
  }

  void _logLayoutData(Map<String, dynamic> layoutData) {
    String jsonData = jsonEncode(layoutData);
    debugPrint("Layout Data: $jsonData", wrapWidth: 1024);
    _saveLogToFile(jsonData);
  }

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

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}
