import 'dart:convert';
import 'dart:developer';

import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class CustomEventData {
  final String sessionId;
  final String userId;
  final String eventCode;
  final DateTime sendDateTime;
  final String? screenId;
  final Map<String, dynamic>? metaData;

  CustomEventData({
    required this.sessionId,
    required this.userId,
    required this.eventCode,
    required this.sendDateTime,
    this.screenId,
    this.metaData,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'userId': userId,
    'eventCode': eventCode,
    'sendDateTime': sendDateTime.toIso8601String(),
    'screenId': screenId,
    'metaData': metaData,
  };
}

class CustomEventService {
  final QubeAnalyticsSDK _sdk;

  CustomEventService(this._sdk);

  void trackEvent({
    required String eventCode,
    required String userId,
    String? screenId,
    Map<String, dynamic>? metaData,
  }) {
    final customEventData = CustomEventData(
      sessionId: _sdk.sessionId,
      userId: userId,
      eventCode: eventCode,
      sendDateTime: DateTime.now(),
      screenId: screenId,
      metaData: metaData,
    );

    _logCustomEventData(customEventData);
  }

  void _logCustomEventData(CustomEventData data) {
    log("Custom Event Data: ${jsonEncode(data.toJson())}", name: "Custom Event Data");
  }
}