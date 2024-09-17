import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:qube_analytics_sdk/src/user_info.dart';
import 'package:http/http.dart' as http;

class TraceInfo {
  final String ip;
  final String loc;

  TraceInfo({required this.ip, required this.loc});

  @override
  String toString() {
    return 'IP: $ip, Location: $loc';
  }
}

Future<TraceInfo> fetchTraceData() async {
  final url = Uri.parse('https://www.cloudflare.com/cdn-cgi/trace');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // Convert response body into a map by splitting the response string into key-value pairs
    Map<String, String> traceData = {};
    List<String> lines = response.body.split('\n');

    for (var line in lines) {
      if (line.contains('=')) {
        List<String> parts = line.split('=');
        traceData[parts[0]] = parts[1];
      }
    }

    // Extract the 'ip' and 'loc' from the trace data
    String ip = traceData['ip'] ?? 'Unknown';
    String loc = traceData['loc'] ?? 'Unknown';

    return TraceInfo(ip: ip, loc: loc);
  } else {
    throw Exception('Failed to load trace data');
  }
}

class UniqueDeviceIdService {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Future<UserInfo?> getUserInfo(BuildContext context) async {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    // Fetch location info from Cloudflare's trace service
    TraceInfo traceInfo = await fetchTraceData();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return UserInfo(
          deviceType: androidInfo.device,
          width: width.toString(),
          height: height.toString(),
          countryCode: traceInfo.loc, // Use the actual country code from trace
        );

      case TargetPlatform.iOS:
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return UserInfo(
          deviceType: iosInfo.utsname.machine,
          width: width.toString(),
          height: height.toString(),
          countryCode: traceInfo.loc, // Use the actual country code from trace
        );

      default:
        return null;
    }
  }
}
