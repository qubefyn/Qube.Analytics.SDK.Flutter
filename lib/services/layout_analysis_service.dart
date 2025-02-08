import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutService {
  final QubeAnalyticsSDK _sdk;
  Timer? _layoutTimer;

  LayoutService(this._sdk);

  void startLayoutAnalysis(String screenName) {
    _stopLayoutTimer(); // Ensure no previous timer is running
    _layoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _analyzeLayout(screenName);
    });
  }

  void _stopLayoutTimer() {
    _layoutTimer?.cancel();
    _layoutTimer = null;
  }

  void _analyzeLayout(String screenName) {
    final context = _sdk.repaintBoundaryKey.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        final components = _extractLayoutComponents(renderObject);
        final layoutData = {
          'screenName': screenName,
          'currentTime': DateTime.now().toIso8601String(),
          'components': components,
        };
        _logLayoutData(layoutData);
      }
    }
  }

  List<Map<String, dynamic>> _extractLayoutComponents(RenderBox renderObject) {
    final components = <Map<String, dynamic>>[];
    _visitRenderObject(renderObject, components);
    return components;
  }

  void _visitRenderObject(RenderObject renderObject, List<Map<String, dynamic>> components) {
    if (renderObject is RenderBox) {
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      components.add({
        'type': renderObject.runtimeType.toString(),
        'x': offset.dx,
        'y': offset.dy,
        'width': size.width,
        'height': size.height,
      });
    }

    renderObject.visitChildren((child) {
      _visitRenderObject(child, components);
    });
  }

  void _logLayoutData(Map<String, dynamic> layoutData) {
    log("Layout Data, ${jsonEncode(layoutData)}");
  }

  void stopLayoutAnalysis() {
    _stopLayoutTimer();
  }
}