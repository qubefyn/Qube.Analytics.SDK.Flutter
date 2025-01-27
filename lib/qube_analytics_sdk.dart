library qube_analytics_sdk;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// User Data Model
class UserData {
  final String userId;
  final String deviceId;
  final String deviceType;
  final int ram;
  final int cpuCores;
  final String ip;
  final String country;
  final String userAgent;

  UserData({
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    required this.ram,
    required this.cpuCores,
    required this.ip,
    required this.country,
    required this.userAgent,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'deviceId': deviceId,
        'deviceType': deviceType,
        'ram': ram,
        'cpuCores': cpuCores,
        'ip': ip,
        'country': country,
        'userAgent': userAgent,
      };
}

// Screen View Data Model
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

// Error Data Model
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

// Qube Analytics SDK
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

  Future<void> initialize({String? userId}) async {
    sessionId = _generateUniqueId();
    deviceId = await _initializeDeviceId();
    final generatedUserId = userId ?? _generateUniqueId();
    userData = await _collectDeviceData(generatedUserId);
    print("SDK Initialized: ${jsonEncode(userData)}");

    // Set error tracking
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

  String _generateUniqueId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  Future<String> _initializeDeviceId() async {
    String? storedDeviceId = await _storage.read(key: _deviceIdKey);

    if (storedDeviceId != null) {
      return storedDeviceId;
    }

    final newDeviceId = await _generateDeviceId();
    await _storage.write(key: _deviceIdKey, value: newDeviceId);
    return newDeviceId;
  }

  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceIdentifier = "";

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceIdentifier =
          "${androidInfo.id}-${androidInfo.model}-${androidInfo.product}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceIdentifier =
          "${iosInfo.identifierForVendor}-${iosInfo.utsname.machine}-${iosInfo.systemName}";
    }

    return deviceIdentifier.hashCode.toString();
  }

  Future<Map<String, String>> _getCloudflareData() async {
    try {
      const url = "https://www.cloudflare.com/cdn-cgi/trace";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = response.body.split('\n');
        final map = {
          for (var line in data)
            if (line.contains('=')) ...{line.split('=')[0]: line.split('=')[1]}
        };
        return {
          "ip": map['ip'] ?? "Unknown",
          "country": map['loc'] ?? "Unknown",
          "userAgent": map['uag'] ?? "Unknown",
        };
      }
    } catch (e) {
      print("Error fetching Cloudflare data: $e");
    }
    return {"ip": "Unknown", "country": "Unknown", "userAgent": "Unknown"};
  }

  Future<UserData> _collectDeviceData(String userId) async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceType = "";
    int ram = 0;
    int cpuCores = 0;

    // Fetch IP, Country, and User-Agent using Cloudflare Trace
    final cloudflareData = await _getCloudflareData();

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
      ip: cloudflareData["ip"]!,
      country: cloudflareData["country"]!,
      userAgent: cloudflareData["userAgent"]!,
    );
  }

  void trackScreenView(ScreenViewData data) {
    lastScreenId = data.screenId; // Save the last screen ID
    print("Screen View: ${jsonEncode(data.toJson())}");
  }

  void trackError(ErrorData data) {
    print("Error: ${jsonEncode(data.toJson())}");
  }
}
