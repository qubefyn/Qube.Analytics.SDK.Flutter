import 'dart:developer';

import 'package:flutter/material.dart';
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

  BehaviorDataService(this._sdk);

  void trackClick({
    required double x,
    required double y,
  }) {
    final behaviorData = BehaviorData(
      actionType: 'click',
      x: x,
      y: y,
      actionDateTime: DateTime.now(),
      sessionId: _sdk.sessionId,
      userId: _sdk.userData.userId,
      screenId: _sdk.lastScreenId,
    );

    _logBehaviorData(behaviorData);
  }

  void trackScroll({
    required double y,
    required double maxY,
  }) {
    final behaviorData = BehaviorData(
      actionType: 'scroll',
      y: y,
      screenY: maxY,
      actionDateTime: DateTime.now(),
      sessionId: _sdk.sessionId,
      userId: _sdk.userData.userId,
      screenId: _sdk.lastScreenId,
    );

    _logBehaviorData(behaviorData);
  }

  void _logBehaviorData(BehaviorData data) {
    log("Behavior Data: ${data.toJson()}", name: "Behavior Data");
  }

  Widget wrapWithTracking({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          trackScroll(
            y: metrics.pixels,
            maxY: metrics.maxScrollExtent,
          );
        }
        return false;
      },
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          trackClick(
            x: event.position.dx,
            y: event.position.dy,
          );
        },
        child: child,
      ),
    );
  }
}
