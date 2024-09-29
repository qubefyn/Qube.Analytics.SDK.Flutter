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
      _logNavigation(
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
    _logNavigation(
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
    _logNavigation(
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

  void _logNavigation(
      String pageTitle, String pagePath, DateTime inTime, DateTime outTime) {
    final timestamp = DateTime.now();
    final log = NavigationLog(
      pageTitle: pageTitle,
      pagePath: pagePath,
      inTime: inTime,
      outTime: outTime,
    );

    navigationLogs.add(log);
    print(log); // For debugging purposes
  }
}

class NavigationLog {
  final String pageTitle;
  final String pagePath;
  final DateTime inTime;
  final DateTime outTime;

  NavigationLog({
    required this.pageTitle,
    required this.pagePath,
    required this.inTime,
    required this.outTime,
  });

  @override
  String toString() {
    return 'Page Title: $pageTitle, Page Path: $pagePath, In Time: $inTime, Out Time: $outTime';
  }
}
