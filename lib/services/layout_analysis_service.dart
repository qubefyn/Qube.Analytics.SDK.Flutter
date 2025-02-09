import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../qube_analytics_sdk.dart';

class LayoutService {
  final QubeAnalyticsSDK _sdk;
  Timer? _layoutTimer;
  bool _isAnalyzing = false;

  LayoutService(this._sdk);

  void startLayoutAnalysis(String screenName) {
    if (_isAnalyzing) return;
    debugPrint("Starting layout analysis for $screenName");
    _isAnalyzing = true;

    _layoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _captureLayout(screenName);
    });
  }

  void stopLayoutAnalysis() {
    if (!_isAnalyzing) return;
    debugPrint("Stopping layout analysis");
    _layoutTimer?.cancel();
    _isAnalyzing = false;
  }

  void _captureLayout(String screenName) {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context == null) {
      debugPrint("Error: No currentContext found for layout analysis.");
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      debugPrint("Error: No valid RenderRepaintBoundary found.");
      return;
    }

    debugPrint("Layout analysis captured for $screenName.");
  }
}
