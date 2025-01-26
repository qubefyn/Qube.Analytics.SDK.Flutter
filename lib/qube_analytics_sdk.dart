import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'services/behavior_data_service.dart';

class UserData {
  final String userId;
  final String deviceId;
  final String deviceType;
  final int ram;
  final int cpuCores;
  final String ip;
  final String country;

  UserData({
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    required this.ram,
    required this.cpuCores,
    required this.ip,
    required this.country,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'deviceId': deviceId,
    'deviceType': deviceType,
    'ram': ram,
    'cpuCores': cpuCores,
    'ip': ip,
    'country': country,
  };
}

class ScreenViewData {
  final String screenId;
  final String screenPath;
  final String screenName;
  final DateTime visitDateTime;
  final String sessionId;

  ScreenViewData({
    required this.screenId,
    required this.screenPath,
    required this.screenName,
    required this.visitDateTime,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'screenId': screenId,
    'screenPath': screenPath,
    'screenName': screenName,
    'visitDateTime': visitDateTime.toIso8601String(),
    'sessionId': sessionId,
  };
}

class ErrorData {
  final String sessionId;
  final String deviceId;
  final String? screenId;
  final String errorMessage;
  final String errorStackTrace;
  final bool isCustom;

  ErrorData({
    required this.sessionId,
    required this.deviceId,
    this.screenId,
    required this.errorMessage,
    required this.errorStackTrace,
    required this.isCustom,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'deviceId': deviceId,
    'screenId': screenId,
    'errorMessage': errorMessage,
    'errorStackTrace': errorStackTrace,
    'isCustom': isCustom,
  };
}

class QubeAnalyticsSDK {
  static final QubeAnalyticsSDK _instance = QubeAnalyticsSDK._internal();
  factory QubeAnalyticsSDK() => _instance;
  QubeAnalyticsSDK._internal();

  static const _deviceIdKey = "device_id";
  static const _storage = FlutterSecureStorage();

  late String sessionId;
  late UserData userData;
  late String deviceId;
  String? lastScreenId;

  late BehaviorDataService behaviorDataService;

  Future<void> initialize({String? userId, }) async {
    sessionId = _generateUniqueId();
    deviceId = await _initializeDeviceId();
    final generatedUserId = userId ?? _generateUniqueId();
    userData = await _collectDeviceData(generatedUserId);
    print("SDK Initialized: ${jsonEncode(userData)}");

    behaviorDataService = BehaviorDataService(this);

    FlutterError.onError = (FlutterErrorDetails details) {
      trackError(ErrorData(
        sessionId: sessionId,
        deviceId: deviceId,
        screenId: lastScreenId,
        errorMessage: details.exceptionAsString(),
        errorStackTrace: details.stack.toString(),
        isCustom: false,
      ));
    };
  }

  String _generateUniqueId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<String> _initializeDeviceId() async {
    String? storedDeviceId = await _storage.read(key: _deviceIdKey);
    if (storedDeviceId != null) return storedDeviceId;

    final newDeviceId = await _generateDeviceId();
    await _storage.write(key: _deviceIdKey, value: newDeviceId);
    return newDeviceId;
  }

  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceIdentifier = "";

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceIdentifier = "${androidInfo.id}-${androidInfo.model}-${androidInfo.product}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceIdentifier = "${iosInfo.identifierForVendor}-${iosInfo.utsname.machine}-${iosInfo.systemName}";
    }

    return deviceIdentifier.hashCode.toString();
  }

  Future<String> _getIPAddress() async {
    try {
      const url = "https://api64.ipify.org?format=json";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ip'];
      }
    } catch (e) {
      print("Error fetching Public IP: $e");
    }
    return "Unknown";
  }

  Future<String> _getCountry(String ipAddress) async {
    try {
      const apiKey = "df508899a9aa3c8b27e8cbedcb2dffb4";
      final url = "http://api.ipapi.com/$ipAddress?access_key=$apiKey&fields=country_name&output=json";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['country_name'] ?? "Unknown";
      } else {
        print("Failed to fetch country: ${response.body}");
      }
    } catch (e) {
      print("Error fetching country: $e");
    }
    return "Unknown";
  }

  Future<UserData> _collectDeviceData(String userId) async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceType = "";
    int ram = 0;
    int cpuCores = 0;
    final ipAddress = await _getIPAddress();
    final country = await _getCountry(ipAddress);

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceType = "Android";
      ram = androidInfo.systemFeatures.length;
      cpuCores = androidInfo.supported64BitAbis.length;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceType = "iOS";
      ram = 2;
      cpuCores = 4;
    }

    return UserData(
      userId: userId,
      deviceId: deviceId,
      deviceType: deviceType,
      ram: ram,
      cpuCores: cpuCores,
      ip: ipAddress,
      country: country,
    );
  }

  void trackScreenView(ScreenViewData data) {
    lastScreenId = data.screenId;
    print("Screen View: ${jsonEncode(data.toJson())}");
  }

  void trackError(ErrorData data) {
    print("Error: ${jsonEncode(data.toJson())}");
  }

  void trackClick({required double x, required double y, String? screenId}) {
    behaviorDataService.trackClick(
      x: x,
      y: y,
      userId: userData.userId,
      screenId: screenId ?? lastScreenId,
    );
  }

  void trackScroll({required double y, required double screenY, String? screenId}) {
    behaviorDataService.trackScroll(
      y: y,
      screenY: screenY,
      userId: userData.userId,
      screenId: screenId ?? lastScreenId,
    );
  }

  void trackCustomAction({
    required String actionType,
    double? x,
    double? y,
    double? screenY,
    String? screenId,
  }) {
    behaviorDataService.trackCustomAction(
      actionType: actionType,
      x: x,
      y: y,
      screenY: screenY,
      userId: userData.userId,
      screenId: screenId ?? lastScreenId,
    );
  }
}

abstract class ScreenTracker {
  String get screenName {
    return runtimeType.toString();
  }
}

class QubeNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    final sdk = QubeAnalyticsSDK();
    final screenName = _extractScreenName(route);

    sdk.trackScreenView(ScreenViewData(
      screenId: screenName.hashCode.toString(),
      screenPath: screenName,
      screenName: screenName,
      visitDateTime: DateTime.now(),
      sessionId: sdk.sessionId,
    ));
  }

  String _extractScreenName(Route<dynamic> route) {
    try {
      if (route.navigator?.context.widget is ScreenTracker) {
        return (route.navigator!.context.widget as ScreenTracker).screenName;
      }
    } catch (e) {
      print('Error extracting screen name: $e');
    }

    return route.settings.name ?? route.runtimeType.toString();
  }
}