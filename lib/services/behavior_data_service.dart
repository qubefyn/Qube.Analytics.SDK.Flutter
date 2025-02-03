import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

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
      };
}

class BehaviorDataService {
  final QubeAnalyticsSDK _sdk;
  final GlobalKey repaintBoundaryKey = GlobalKey();

  BehaviorDataService(this._sdk);

  void trackClick({
    required double x,
    required double y,
    required String userId,
    String? screenId,
  }) {
    final behaviorData = BehaviorData(
      actionType: 'click',
      x: x,
      y: y,
      actionDateTime: DateTime.now(),
      sessionId: _sdk.sessionId,
      userId: userId,
      screenId: screenId,
    );

    _logBehaviorData(behaviorData);
  }

  void trackScroll({
    required double y,
    required double screenY,
    required String userId,
    String? screenId,
    double? x,
    double? screenX,
  }) {
    final behaviorData = BehaviorData(
      actionType: 'scroll',
      x: x,
      y: y,
      screenY: screenY,
      screenX: screenX,
      actionDateTime: DateTime.now(),
      sessionId: _sdk.sessionId,
      userId: userId,
      screenId: screenId,
    );

    _logBehaviorData(behaviorData);
  }

  void trackCustomAction({
    required String actionType,
    double? x,
    double? y,
    double? screenY,
    double? screenX,
    required String userId,
    String? screenId,
  }) {
    final behaviorData = BehaviorData(
      actionType: actionType,
      x: x,
      y: y,
      screenY: screenY,
      screenX: screenX,
      actionDateTime: DateTime.now(),
      sessionId: _sdk.sessionId,
      userId: userId,
      screenId: screenId,
    );

    _logBehaviorData(behaviorData);
  }

  void _logBehaviorData(BehaviorData data) {
    log("Behavior Data: ${jsonEncode(data.toJson())}", name: "Behavior Data");
  }

  void startAutomaticTracking(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackClicks(context);
    });
  }

  void _trackClicks(BuildContext context) {
    final overlay = Overlay.of(context);

    final listener = Listener(
      onPointerDown: (PointerDownEvent event) {
        final offset = event.position;
        trackClick(
          x: offset.dx,
          y: offset.dy,
          userId: _sdk.userData.userId,
          screenId: _sdk.lastScreenId,
        );
      },
      child: Container(),
    );

    overlay.insert(OverlayEntry(builder: (context) => listener));
  }

  Widget wrapWithScrollTracking({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          trackScroll(
            y: metrics.pixels,
            screenY: metrics.maxScrollExtent,
            x: metrics.pixels,
            screenX: metrics.maxScrollExtent,
            userId: _sdk.userData.userId,
            screenId: _sdk.lastScreenId,
          );
        }
        return false;
      },
      child: wrapWithClickTracking(child: child),
    );
  }

  Widget wrapWithClickTracking({required Widget child}) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          final offset = event.position;
          trackClick(
            x: offset.dx,
            y: offset.dy,
            userId: _sdk.userData.userId,
            screenId: _sdk.lastScreenId,
          );
        },
        child: child,
      ),
    );
  }

  /// 🔥 **إضافة ميزة `Heatmap Capture`**
  /// تحفظ لقطة الشاشة عند مغادرة الشاشة الحالية
  Future<void> captureHeatmap(String screenId) async {
    try {
      RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage();
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      Directory tempDir = await getTemporaryDirectory();
      String filePath = '${tempDir.path}/$screenId.png';

      File imgFile = File(filePath);
      await imgFile.writeAsBytes(pngBytes);
      print("✅ Screenshot saved: $filePath");
    } catch (e) {
      print("❌ Error capturing heatmap: $e");
    }
  }
}
