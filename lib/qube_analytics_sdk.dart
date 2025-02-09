library qube_analytics_sdk;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/services/LayoutVideoCaptureService.dart';
import 'package:qube_analytics_sdk/services/behavior_data_service.dart';
import 'package:qube_analytics_sdk/services/layout_analysis_service.dart';

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
  late BehaviorDataService behaviorDataService;
  late LayoutVideoCaptureService videoCaptureService;

  late String sessionId;
  late UserData userData;
  late String deviceId;
  String? lastScreenId;
  late LayoutService layoutService;

   final GlobalKey repaintBoundaryKey = GlobalKey();
  Future<void> initialize({String? userId}) async {
    sessionId = _generateUniqueId();
    deviceId = await _initializeDeviceId();
    final generatedUserId = userId ?? _generateUniqueId();
    userData = await _collectDeviceData(generatedUserId);
    print("SDK Initialized: ${jsonEncode(userData)}");
    behaviorDataService = BehaviorDataService(this);
    layoutService = LayoutService(this);   videoCaptureService = LayoutVideoCaptureService(this);
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

  Future<String> _getIPAddress() async {
    try {
      const url = "https://www.cloudflare.com/cdn-cgi/trace";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = _parseCloudflareResponse(response.body);
        return data['ip'] ?? "Unknown";
      }
    } catch (e) {
      print("Error fetching Public IP: $e");
    }
    return "Unknown";
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      const url = "https://www.cloudflare.com/cdn-cgi/trace";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return _parseCloudflareResponse(response.body);
      }
    } catch (e) {
      print("Error fetching device info: $e");
    }
    return {};
  }

  Map<String, String> _parseCloudflareResponse(String response) {
    final lines = response.split('\n');
    final Map<String, String> data = {};
    for (final line in lines) {
      final parts = line.split('=');
      if (parts.length == 2) {
        data[parts[0].trim()] = parts[1].trim();
      }
    }
    return data;
  }

  Future<UserData> _collectDeviceData(String userId) async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceType = "";
    int ram = 0;
    int cpuCores = 0;
    final cloudflareData = await _getDeviceInfo();

    final ip = cloudflareData['ip'] ?? "Unknown";
    final country = cloudflareData['loc'] ?? "Unknown";
    final userAgent = cloudflareData['uag'] ?? "Unknown";

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceType = "Android";
      ram = androidInfo.systemFeatures.length;
      cpuCores = androidInfo.supported64BitAbis.length;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceType = "iOS";
      ram = _estimateRamForIosDevice(iosInfo.utsname.machine);
      cpuCores = _estimateCpuCoresForIosDevice(iosInfo.utsname.machine);
    }

    return UserData(
      userId: userId,
      deviceId: deviceId,
      deviceType: deviceType,
      ram: ram,
      cpuCores: cpuCores,
      ip: ip,
      country: country,
      userAgent: userAgent,
    );
  }

  void trackScreenView(ScreenViewData data) {
    lastScreenId = data.screenId;
    print("Screen View: ${jsonEncode(data.toJson())}");
  }

  void trackError(ErrorData data) {
    print("Error: ${jsonEncode(data.toJson())}");
  }

  int _estimateRamForIosDevice(String machine) {
    const deviceRam = {
      'iPhone10,3': 3, // iPhone X
      'iPhone10,6': 3, // iPhone X Global
      'iPhone11,2': 4, // iPhone XS
      'iPhone11,4': 4, // iPhone XS Max
      'iPhone11,6': 4, // iPhone XS Max Global
      'iPhone11,8': 3, // iPhone XR
      'iPhone12,1': 4, // iPhone 11
      'iPhone12,3': 4, // iPhone 11 Pro
      'iPhone12,5': 4, // iPhone 11 Pro Max
      'iPhone13,1': 4, // iPhone 12 Mini
      'iPhone13,2': 4, // iPhone 12
      'iPhone13,3': 6, // iPhone 12 Pro
      'iPhone13,4': 6, // iPhone 12 Pro Max
      'iPhone14,4': 4, // iPhone 13 Mini
      'iPhone14,5': 6, // iPhone 13
      'iPhone14,2': 6, // iPhone 13 Pro
      'iPhone14,3': 6, // iPhone 13 Pro Max
      'iPhone14,6': 4, // iPhone SE (3rd generation)
      'iPhone15,2': 6, // iPhone 14
      'iPhone15,3': 6, // iPhone 14 Plus
      'iPhone15,4': 6, // iPhone 14 Pro
      'iPhone15,5': 6, // iPhone 14 Pro Max
      'iPhone16,1': 8, // iPhone 15
      'iPhone16,2': 8, // iPhone 15 Plus
      'iPhone16,3': 8, // iPhone 15 Pro
      'iPhone16,4': 8, // iPhone 15 Pro Max
      'iPhone17,1': 8, // iPhone 16 (Estimation)
      'iPhone17,2': 8, // iPhone 16 Plus (Estimation)
      'iPhone17,3': 8, // iPhone 16 Pro (Estimation)
      'iPhone17,4': 8, // iPhone 16 Pro Max (Estimation)
    };
    return deviceRam[machine] ?? 2;
  }

  int _estimateCpuCoresForIosDevice(String machine) {
    const deviceCores = {
      'iPhone10,3': 6, // iPhone X
      'iPhone10,6': 6, // iPhone X Global
      'iPhone11,2': 6, // iPhone XS
      'iPhone11,4': 6, // iPhone XS Max
      'iPhone11,6': 6, // iPhone XS Max Global
      'iPhone11,8': 6, // iPhone XR
      'iPhone12,1': 6, // iPhone 11
      'iPhone12,3': 6, // iPhone 11 Pro
      'iPhone12,5': 6, // iPhone 11 Pro Max
      'iPhone13,1': 6, // iPhone 12 Mini
      'iPhone13,2': 6, // iPhone 12
      'iPhone13,3': 6, // iPhone 12 Pro
      'iPhone13,4': 6, // iPhone 12 Pro Max
      'iPhone14,4': 6, // iPhone 13 Mini
      'iPhone14,5': 6, // iPhone 13
      'iPhone14,2': 6, // iPhone 13 Pro
      'iPhone14,3': 6, // iPhone 13 Pro Max
      'iPhone14,6': 6, // iPhone SE (3rd generation)
      'iPhone15,2': 6, // iPhone 14
      'iPhone15,3': 6, // iPhone 14 Plus
      'iPhone15,4': 6, // iPhone 14 Pro
      'iPhone15,5': 6, // iPhone 14 Pro Max
      'iPhone16,1': 6, // iPhone 15
      'iPhone16,2': 6, // iPhone 15 Plus
      'iPhone16,3': 6, // iPhone 15 Pro
      'iPhone16,4': 6, // iPhone 15 Pro Max
      'iPhone17,1': 6, // iPhone 16 (Estimation)
      'iPhone17,2': 6, // iPhone 16 Plus (Estimation)
      'iPhone17,3': 6, // iPhone 16 Pro (Estimation)
      'iPhone17,4': 6, // iPhone 16 Pro Max (Estimation)
    };
    return deviceCores[machine] ?? 4;
  }
}

abstract class ScreenTracker {
  String get screenName {
    return runtimeType.toString();
  }
}

class QubeNavigatorObserver extends NavigatorObserver {
  final GlobalKey repaintBoundaryKey; // ✅ مفتاح الـ RepaintBoundary
  Timer? _screenshotTimer; // ✅ مؤقت لأخذ لقطة كل 5 ثوانٍ
  final QubeAnalyticsSDK _sdk;
  QubeNavigatorObserver(this.repaintBoundaryKey , this._sdk);

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
    _sdk.layoutService.startLayoutAnalysis(screenName);
    // ✅ بدء أخذ اللقطات بشكل متكرر
    // _startScreenshotTimer(screenName);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);_sdk.layoutService.stopLayoutAnalysis();
    _stopScreenshotTimer(); // ✅ إيقاف المؤقت عند الخروج من الشاشة
  }

  /// ✅ استخراج اسم الشاشة
  String _extractScreenName(Route<dynamic> route) {
    return route.settings.name ?? route.runtimeType.toString();
  }

  /// ✅ بدء المؤقت لأخذ لقطة كل 5 ثوانٍ
  void _startScreenshotTimer(String screenName) {
    _stopScreenshotTimer(); // التأكد من عدم تشغيل مؤقت آخر
    _screenshotTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _captureScreenshot(screenName);
    });
  }

  /// ✅ إيقاف المؤقت عند الخروج من الشاشة
  void _stopScreenshotTimer() {
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
  }

  /// ✅ التقاط لقطة الشاشة وحفظها
  Future<void> _captureScreenshot(String routeName) async {
    try {
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        final pngBytes = byteData?.buffer.asUint8List();

        if (pngBytes != null) {
          final directory = await getApplicationDocumentsDirectory();
          final screenshotsDir = Directory('${directory.path}/screenshots');

          if (!screenshotsDir.existsSync()) {
            screenshotsDir.createSync(recursive: true);
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${screenshotsDir.path}/$routeName-$timestamp.png';
          final file = File(filePath);
          await file.writeAsBytes(pngBytes);

          debugPrint('✅ Screenshot saved: $filePath');
        } else {
          debugPrint('❌ Failed to convert image to bytes.');
        }
      } else {
        debugPrint('❌ Render boundary is null. Screenshot not captured.');
      }
    } catch (e) {
      debugPrint('❌ Error capturing screenshot: $e');
    }
  }
}