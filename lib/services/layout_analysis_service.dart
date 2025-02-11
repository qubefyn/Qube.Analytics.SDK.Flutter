import 'dart:async';
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

  LayoutService(this._sdk);

  /// بدء تحليل اللاي آوت لكل صفحة كل 5 ثوانٍ.
  void startLayoutAnalysis(String screenName, Widget widgetTree) {
    _stopLayoutTimer();
    log("Starting layout analysis for screen: $screenName");

    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName, widgetTree);
    });
  }

  /// إيقاف المؤقت عند مغادرة الصفحة.
  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  /// إنشاء نسخة `Offscreen` من الشاشة والتقاط الصورة منها.
  Future<void> _analyzeLayout(String screenName, Widget widgetTree) async {
    final boundary = await _createOffscreenBoundary(widgetTree);

    if (boundary != null) {
      await _captureScreenshot(screenName, boundary);
    }
  }

  /// ✅ إنشاء نسخة `Offscreen` تحتوي على الشاشة بدون تغيير الواجهة الفعلية.
  Future<RenderRepaintBoundary?> _createOffscreenBoundary(
      Widget widgetTree) async {
    try {
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());
      final renderView = RenderView(
        view: WidgetsBinding.instance.platformDispatcher.views.first,
        configuration: ViewConfiguration(
          physicalConstraints: BoxConstraints.tight(
            WidgetsBinding.instance.platformDispatcher.views.first.physicalSize,
          ),
          logicalConstraints: BoxConstraints.tight(
            WidgetsBinding.instance.platformDispatcher.views.first.physicalSize,
          ),
          devicePixelRatio: WidgetsBinding
              .instance.platformDispatcher.views.first.devicePixelRatio,
        ),
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: RenderRepaintBoundary(),
        ),
      );

      pipelineOwner.rootNode = renderView;
      final renderBoundary = RenderRepaintBoundary();
      renderView.child = renderBoundary;

      final element = RenderObjectToWidgetAdapter<RenderBox>(
        container: renderBoundary,
        child: OffscreenWidget(widgetTree),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(element);
      buildOwner.finalizeTree();
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      return renderBoundary;
    } catch (e) {
      debugPrint("❌ Error creating offscreen boundary: $e");
      return null;
    }
  }

  /// ✅ التقاط لقطة شاشة من `Offscreen` فقط.
  Future<void> _captureScreenshot(
      String screenName, RenderRepaintBoundary boundary) async {
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 🔹 حفظ الصورة
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;

      final filePath =
          '${directory.path}/QubeScreenshots/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      debugPrint("✅ Screenshot saved: $filePath");
    } catch (e) {
      debugPrint("❌ Error capturing screenshot: $e");
    }
  }

  /// إيقاف التحليل عند مغادرة الصفحة.
  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}

/// ✅ ويدجت خاصة لرسم الشاشة في `Offscreen` فقط.
class OffscreenWidget extends StatelessWidget {
  final Widget child;

  const OffscreenWidget(this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}
