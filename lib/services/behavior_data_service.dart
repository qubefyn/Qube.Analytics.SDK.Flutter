import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class BehaviorData {
  final String actionType;
  final double? x;
  final double? y;
  final double? screenY;
  final double? screenX;
  final DateTime actionDateTime;
  final String sessionId;
  final String userId;
  final String? screenId;
  final String? screenshotPath;

  BehaviorData({
    required this.actionType,
    this.x,
    this.y,
    this.screenY,
    this.screenX,
    required this.actionDateTime,
    required this.sessionId,
    required this.userId,
    this.screenId,
    this.screenshotPath,
  });

  Map<String, dynamic> toJson() => {
        'actionType': actionType,
        'x': x,
        'y': y,
        'screenY': screenY,
        'screenX': screenX,
        'actionDateTime': actionDateTime.toIso8601String(),
        'sessionId': sessionId,
        'userId': userId,
        'screenId': screenId,
        'screenshotPath': screenshotPath,
      };
}

class BehaviorDataService {
  final QubeAnalyticsSDK _sdk;

  BehaviorDataService(this._sdk);

  Future<String?> _captureScreenshot(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData?.buffer.asUint8List();

      if (buffer != null) {
        final directory = await getApplicationDocumentsDirectory();
        final screenshotPath =
            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';

        final file = File(screenshotPath);
        await file.writeAsBytes(buffer);
        return screenshotPath;
      }
    } catch (e) {
      log("Error capturing screenshot: $e", name: "Screenshot");
    }
    return null;
  }

  Future<void> trackClick({
    required double x,
    required double y,
    required GlobalKey repaintBoundaryKey,
  }) async {
    final screenshotPath = await _captureScreenshot(repaintBoundaryKey);
    log("Click captured at ($x, $y). Screenshot saved at: $screenshotPath");
  }

  Future<void> trackScroll({
    required double y,
    required double maxY,
    required GlobalKey repaintBoundaryKey,
  }) async {
    final screenshotPath = await _captureScreenshot(repaintBoundaryKey);
    log("Scroll detected. Position: $y/$maxY. Screenshot saved at: $screenshotPath");
  }

  Widget wrapWithTracking(
      {required Widget child, required GlobalKey repaintBoundaryKey}) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            trackScroll(
              y: metrics.pixels,
              maxY: metrics.maxScrollExtent,
              repaintBoundaryKey: repaintBoundaryKey,
            );
          }
          return false;
        },
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            trackClick(
              x: event.position.dx,
              y: event.position.dy,
              repaintBoundaryKey: repaintBoundaryKey,
            );
          },
          child: child,
        ),
      ),
    );
  }
}
