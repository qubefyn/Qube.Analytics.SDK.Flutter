import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

class ScreenNavigationObserver extends NavigatorObserver {
  final List<NavigationLog> navigationLogs = [];
  final List<String> scrNameStack = [];
  String? prevScrName;
  DateTime? prevInTime;
  final Map<String, String> scrNamePathMap = {};

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    var nowTime = DateTime.now();
    if (prevScrName != null) {
      var prevScrPath = scrNamePathMap[prevScrName];
      _logNavigationAsync(
        prevScrName!,
        prevScrPath!,
        prevInTime!,
        nowTime,
      );
    }
    scrNameStack.add(route.settings.name!);
    scrNamePathMap[route.settings.name!] =
        scrNameStack.join("/").replaceAll("//", "/");
    prevScrName = route.settings.name!;
    prevInTime = nowTime;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    var nowTime = DateTime.now();
    var prevScrPath = scrNamePathMap[prevScrName];
    _logNavigationAsync(
      prevScrName!,
      prevScrPath!,
      prevInTime!,
      nowTime,
    );
    prevScrName = previousRoute!.settings.name!;
    prevInTime = nowTime;
    scrNameStack.removeLast();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    var nowTime = DateTime.now();
    var prevScrPath = scrNamePathMap[prevScrName];
    _logNavigationAsync(
      prevScrName!,
      prevScrPath!,
      prevInTime!,
      nowTime,
    );
    prevScrName = newRoute!.settings.name!;
    prevInTime = nowTime;
    scrNameStack.clear();
    scrNameStack.add(prevScrName!);
    scrNamePathMap.clear();
    scrNamePathMap[prevScrName!] = prevScrName!;
  }

  Future<String?> getUniqueId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // This is the Android device ID.
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor; // This is the iOS device identifier.
    }
    return null;
  }

  // New method that handles device ID asynchronously
  Future<void> _logNavigationAsync(String pageTitle, String pagePath,
      DateTime inTime, DateTime outTime) async {
    String? deviceID =
        await getUniqueId(); // Fetch the device ID asynchronously
    if (deviceID != null) {
      logNavigation(pageTitle, pagePath, inTime, outTime, deviceID);
    }
  }

  void logNavigation(String pageTitle, String pagePath, DateTime inTime,
      DateTime outTime, String deviceID) {
    final timestamp = DateTime.now();
    final log = NavigationLog(
      pageTitle: pageTitle,
      pagePath: pagePath,
      inTime: inTime,
      outTime: outTime,
      deviceID: deviceID,
    );

    navigationLogs.add(log);
    print(log); // For debugging purposes

    // Upload log to Firestore
    _uploadLogToFirestore(log);
  }
}

Future<void> _uploadLogToFirestore(NavigationLog log) async {
  try {
    await FirebaseFirestore.instance.collection('Navigation logs').add({
      'pageTitle': log.pageTitle,
      'pagePath': log.pagePath,
      'inTime': log.inTime.toString(),
      'outTime': log.outTime.toString(),
      'deviceID': log.deviceID,
      'timestamp': DateTime.now().toString(),
    });
    print("Log uploaded to Firebase");
  } catch (e) {
    print("Error uploading log to Firebase: $e");
  }
}

class NavigationLog {
  final String pageTitle;
  final String pagePath;
  final DateTime inTime;
  final DateTime outTime;
  final String deviceID;

  NavigationLog({
    required this.pageTitle,
    required this.pagePath,
    required this.inTime,
    required this.outTime,
    required this.deviceID,
  });

  @override
  String toString() {
    return 'Page Title: $pageTitle, Page Path: $pagePath, In Time: $inTime, Out Time: $outTime, Device ID: $deviceID';
  }
}



// import 'dart:io';

// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/material.dart';

// class ScreenNavigationObserver extends NavigatorObserver {
//   final List<NavigationLog> navigationLogs = [];
//   final List<String> scrNameStack = [];
//   String? prevScrName;
//   DateTime? prevInTime;
//   final Map<String, String> scrNamePathMap = {};

//   @override
//   void didPush(Route route, Route? previousRoute) {
//     super.didPush(route, previousRoute);
//     var nowTime = DateTime.now();
//     if (prevScrName != null) {
//       var prevScrPath = scrNamePathMap[prevScrName];
//       _logNavigation(
//         prevScrName!,
//         prevScrPath!,
//         prevInTime!,
//         nowTime,
//       );
//     }
//     scrNameStack.add(route.settings.name!);
//     scrNamePathMap[route.settings.name!] =
//         scrNameStack.join("/").replaceAll("//", "/");
//     prevScrName = route.settings.name!;
//     prevInTime = nowTime;
//   }

//   @override
//   void didPop(Route route, Route? previousRoute) {
//     super.didPop(route, previousRoute);
//     var nowTime = DateTime.now();
//     var prevScrPath = scrNamePathMap[prevScrName];
//     _logNavigation(
//       prevScrName!,
//       prevScrPath!,
//       prevInTime!,
//       nowTime,
      
//     );
//     prevScrName = previousRoute!.settings.name!;
//     prevInTime = nowTime;
//     scrNameStack.removeLast();
//   }

//   @override
//   void didReplace({Route? newRoute, Route? oldRoute}) {
//     super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
//     var nowTime = DateTime.now();
//     var prevScrPath = scrNamePathMap[prevScrName];
//     _logNavigation(
//       prevScrName!,
//       prevScrPath!,
//       prevInTime!,
//       nowTime,

//     );
//     prevScrName = newRoute!.settings.name!;
//     prevInTime = nowTime;
//     scrNameStack.clear();
//     scrNameStack.add(prevScrName!);
//     scrNamePathMap.clear();
//     scrNamePathMap[prevScrName!] = prevScrName!;
//   }

//   Future<String?> getUniqueId() async {
//     final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//     if (Platform.isAndroid) {
//       AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//       return androidInfo.id; // This is the Android device ID.
//     } else if (Platform.isIOS) {
//       IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//       return iosInfo.identifierForVendor; // This is the iOS device identifier.
//     }
//     return null;
//   }

//   void _logNavigation(String pageTitle, String pagePath, DateTime inTime,
//       DateTime outTime, String deviceID) {
//     final timestamp = DateTime.now();
//     final log = NavigationLog(
//       pageTitle: pageTitle,
//       pagePath: pagePath,
//       inTime: inTime,
//       outTime: outTime,
//       deviceID: deviceID,
//     );

//     navigationLogs.add(log);
//     print(log); // For debugging purposes
//   }
// }

// class NavigationLog {
//   final String pageTitle;
//   final String pagePath;
//   final DateTime inTime;
//   final DateTime outTime;
//   final String deviceID;

//   NavigationLog({
//     required this.pageTitle,
//     required this.pagePath,
//     required this.inTime,
//     required this.outTime,
//     required this.deviceID,
//   });

//   @override
//   String toString() {
//     return 'Page Title: $pageTitle, Page Path: $pagePath, In Time: $inTime, Out Time: $outTime, Device ID: $deviceID';
//   }
// }
