import 'dart:developer';

import 'package:flutter/material.dart';
 import 'core/utils/device_utils.dart';
 import 'core/utils/session_utils.dart';
import 'models/user_data.dart';
import 'models/screen_view.dart';
import 'models/behavior_data.dart';
import 'models/error_data.dart';
import 'models/custom_event.dart';


class QubeAnalyticsSDK extends NavigatorObserver {
  static final QubeAnalyticsSDK _instance = QubeAnalyticsSDK._internal();
  factory QubeAnalyticsSDK() => _instance;
  QubeAnalyticsSDK._internal();

  late String sessionId;
  late UserData userData;

  Future<void> initialize({required String appKey, required String userId}) async {
    sessionId = SessionUtils.generateSessionId();
    final deviceInfo = await DeviceUtils.getDeviceInfo();
    userData = UserData(
      userId: userId,
      deviceId: deviceInfo['deviceId'] ?? 'unknown',
      deviceType: deviceInfo['deviceType'] ?? 'unknown',
      ram: deviceInfo['ram'] ?? 0,
      cpuCores: deviceInfo['cpuCores'] ?? 0,
      ip: '127.0.0.1',
      country: 'Unknown',
    );

   log('SDK Initialized with AppKey: $appKey');
   log('User Data: ${userData.toJson()}');

    FlutterError.onError = (FlutterErrorDetails details) {
      trackError(ErrorData(
        sessionId: sessionId,
        userId: userData.userId,
        errorMessage: details.exceptionAsString(),
        errorStackTrace: details.stack.toString(),
        isCustom: false,
      ));
    };
  }

  void trackScreenView(ScreenView data) {
    log('Screen View: ${data.toJson()}');
  }

  void trackError(ErrorData data) {
    log('Error: ${data.toJson()}');
  }

  void trackBehavior(BehaviorData data) {
    log('Behavior: ${data.toJson()}');
  }

  void trackCustomEvent(CustomEvent data) {
    log('Custom Event: ${data.toJson()}');
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    final screenPath = route.settings.name ?? "/unknown";
    trackScreenView(ScreenView(
      screenId: SessionUtils.generateScreenId(screenPath),
      screenPath: screenPath,
      screenName: route.settings.name ?? "Unknown",
      visitDateTime: DateTime.now(),
      sessionId: sessionId,
    ));
  }

  static Widget attachGestureDetector(Widget child) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        _instance.trackBehavior(BehaviorData(
          actionType: "click",
          x: details.globalPosition.dx,
          y: details.globalPosition.dy,
          screenY: details.globalPosition.dy,
          actionDateTime: DateTime.now(),
          sessionId: _instance.sessionId,
          userId: _instance.userData.userId,
          screenId: SessionUtils.generateScreenId("click"),
        ));
      },
      child: child,
    );
  }
}