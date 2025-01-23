import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'deviceId': androidInfo.id,
        'deviceType': 'Android',
        'ram': androidInfo.systemFeatures.length,
        'cpuCores': androidInfo.supported64BitAbis.length,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'deviceId': iosInfo.identifierForVendor,
        'deviceType': 'iOS',
        'ram': 2,
        'cpuCores': 4,
      };
    }
    return {};
  }
}