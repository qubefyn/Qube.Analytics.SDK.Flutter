import 'dart:async';
import 'dart:convert';
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
            screenName, renderObject as RenderRepaintBoundary);

        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  Future<void> _captureFullScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      // Find ScrollableState using BuildContext
      ScrollableState? scrollable;
      if (_sdk.repaintBoundaryKey.currentContext != null) {
        // Find the nearest Scrollable ancestor
        scrollable = Scrollable.of(_sdk.repaintBoundaryKey.currentContext!);
      }

      if (scrollable != null) {
        // Save original scroll position
        final originalOffset = scrollable.position.pixels;

        // Get full scroll extent
        final maxScrollExtent = scrollable.position.maxScrollExtent;
        final viewportDimension = scrollable.position.viewportDimension;

        // Calculate total height
        final totalHeight = maxScrollExtent + viewportDimension;

        // Create a larger recorder for full content
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // Capture content in segments
        double currentScroll = 0;
        while (currentScroll < totalHeight) {
          // Scroll to position
          await scrollable.position.animateTo(
            currentScroll,
            duration: const Duration(milliseconds: 100),
            curve: Curves.linear,
          );

          // Allow frame to be rendered
          await Future.delayed(const Duration(milliseconds: 100));

          // Capture current viewport
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) continue;

          // Convert to image and draw
          final codec =
              await ui.instantiateImageCodec(byteData.buffer.asUint8List());
          final frameInfo = await codec.getNextFrame();

          // Draw at appropriate vertical position
          canvas.drawImage(
            frameInfo.image,
            Offset(0, currentScroll),
            Paint(),
          );

          // Mask text fields in this segment
          if (hideTextFieldContent) {
            void maskTextFields(RenderObject object, Offset parentOffset) {
              if (object is RenderEditable) {
                final transform = object.getTransformTo(boundary);
                final offset =
                    MatrixUtils.transformPoint(transform, Offset.zero);

                // Adjust vertical position based on current scroll
                final adjustedOffset =
                    Offset(offset.dx, offset.dy + currentScroll);

                // Draw masking rectangle
                final paint = Paint()
                  ..color = const Color(0xFFF5F5F5)
                  ..style = PaintingStyle.fill;

                canvas.drawRect(
                    Rect.fromLTWH(adjustedOffset.dx, adjustedOffset.dy,
                        object.size.width, object.size.height),
                    paint);

                // Draw indicator line
                final linePaint = Paint()
                  ..color = const Color(0xFF9E9E9E)
                  ..strokeWidth = 2.0;

                canvas.drawLine(
                    Offset(adjustedOffset.dx + 4,
                        adjustedOffset.dy + object.size.height / 2),
                    Offset(adjustedOffset.dx + object.size.width - 4,
                        adjustedOffset.dy + object.size.height / 2),
                    linePaint);
              }

              object.visitChildren((child) {
                maskTextFields(child, parentOffset);
              });
            }

            maskTextFields(boundary, Offset(0, currentScroll));
          }

          // Clean up
          image.dispose();
          frameInfo.image.dispose();

          // Move to next segment
          currentScroll += viewportDimension;
        }

        // Restore original scroll position
        await scrollable.position.animateTo(
          originalOffset,
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        );

        // Convert final picture to image
        final fullImage = await recorder.endRecording().toImage(
              boundary.size.width.ceil(),
              totalHeight.ceil(),
            );

        // Save the image
        final byteData =
            await fullImage.toByteData(format: ui.ImageByteFormat.png);
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
            '$folderPath/fullscreenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(byteData.buffer.asUint8List());

        debugPrint("✅ تم حفظ لقطة الشاشة الكاملة: $filePath");

        // Cleanup
        fullImage.dispose();
      } else {
        // Fallback to normal screenshot if no scrollable found
        await _captureAndMaskScreenshot(screenName, boundary);
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء التقاط لقطة الشاشة الكاملة: $e");
    }
  }

  Future<void> _captureAndMaskScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      // Take the initial screenshot
      final originalImage = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await originalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // Create a bitmap from the screenshot
      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      // Create a new image with masked text fields
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = boundary.size;

      // Draw the original image
      canvas.drawImage(image, Offset.zero, Paint());

      // Find and mask text fields
      if (hideTextFieldContent) {
        void maskTextFields(RenderObject object, Offset parentOffset) {
          if (object is RenderEditable) {
            final transform = object.getTransformTo(boundary);
            final offset = MatrixUtils.transformPoint(transform, Offset.zero);

            // Draw a rectangle over the text field
            final paint = Paint()
              ..color = const Color(0xFFF5F5F5)
              ..style = PaintingStyle.fill;

            canvas.drawRect(
                Rect.fromLTWH(offset.dx, offset.dy, object.size.width,
                    object.size.height),
                paint);

            // Draw a line to indicate masked content
            final linePaint = Paint()
              ..color = const Color(0xFF9E9E9E)
              ..strokeWidth = 2.0;

            canvas.drawLine(
                Offset(offset.dx + 4, offset.dy + object.size.height / 2),
                Offset(offset.dx + object.size.width - 4,
                    offset.dy + object.size.height / 2),
                linePaint);
          }

          object.visitChildren((child) {
            maskTextFields(child, parentOffset);
          });
        }

        maskTextFields(boundary, Offset.zero);
      }

      // Convert to final image
      final picture = recorder.endRecording();
      final maskedImage =
          await picture.toImage(size.width.ceil(), size.height.ceil());

      final maskedByteData =
          await maskedImage.toByteData(format: ui.ImageByteFormat.png);
      if (maskedByteData == null) return;

      // Save the image
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
      await file.writeAsBytes(maskedByteData.buffer.asUint8List());

      debugPrint("✅ تم حفظ لقطة الشاشة: $filePath");

      // Cleanup
      originalImage.dispose();
      image.dispose();
      maskedImage.dispose();
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
