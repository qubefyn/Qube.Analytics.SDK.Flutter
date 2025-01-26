import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class BehaviorData {
  final String actionType;
  final double? x;
  final double? y;
  final double? screenY;
  final DateTime actionDateTime;
  final String sessionId;
  final String userId;
  final String? screenId;

  BehaviorData({
    required this.actionType,
    this.x,
    this.y,
    this.screenY,
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
    'actionDateTime': actionDateTime.toIso8601String(),
    'sessionId': sessionId,
    'userId': userId,
    'screenId': screenId,
  };
}

class BehaviorDataService {
  final QubeAnalyticsSDK _sdk;

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
  }) {
    final behaviorData = BehaviorData(
      actionType: 'scroll',
      y: y,
      screenY: screenY,
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
    required String userId,
    String? screenId,
  }) {
    final behaviorData = BehaviorData(
      actionType: actionType,
      x: x,
      y: y,
      screenY: screenY,
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
      _trackScrolls(context);
    });
  }

  void _trackClicks(BuildContext context) {
     final listener = Listener(
      onPointerDown: (PointerDownEvent event) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final offset = box.globalToLocal(event.position);
        trackClick(
          x: offset.dx,
          y: offset.dy,
          userId: _sdk.userData.userId,
          screenId: _sdk.lastScreenId,
        );
      },
      child: Container(), // Empty container to avoid UI changes
    );

     Overlay.of(context)?.insert(OverlayEntry(builder: (context) => listener));
  }

  void _trackScrolls(BuildContext context) {
     final notificationListener = NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          trackScroll(
            y: notification.metrics.pixels,
            screenY: notification.metrics.maxScrollExtent,
            userId: _sdk.userData.userId,
            screenId: _sdk.lastScreenId,
          );
        }
        return false;
      },
      child: Container(),
    );

     Overlay.of(context)
        ?.insert(OverlayEntry(builder: (context) => notificationListener));
  }
}