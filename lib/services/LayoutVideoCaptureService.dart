import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qube_analytics_sdk/qube_analytics_sdk.dart';

class LayoutVideoCaptureService {
  final QubeAnalyticsSDK _sdk;
  Timer? _captureTimer;
  List<Map<String, dynamic>> _userActions = [];
  bool _isCapturing = false;

  LayoutVideoCaptureService(this._sdk);

  /// Starts capturing user actions on a specific screen.
  void startCapture(String screenName) {
    if (_isCapturing) return; // Avoid multiple captures
    _isCapturing = true;
    _userActions.clear(); // Clear previous actions
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _captureUserActions(screenName);
    });
  }

  /// Stops capturing user actions.
  void stopCapture() {
    if (!_isCapturing) return; // Avoid stopping if not capturing
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    _logUserActions();
  }

  /// Captures user actions (clicks, scrolls, etc.).
  void _captureUserActions(String screenName) {
    final action = {
      'sessionId': _sdk.sessionId,
      'screenName': screenName,
      'actionType': 'userAction', // Replace with actual action type
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'x': 100, // Example: Replace with actual coordinates
        'y': 200,
      },
    };
    _userActions.add(action);
  }

  /// Logs the captured user actions.
  void _logUserActions() {
    final logData = {
      'sessionId': _sdk.sessionId,
      'actions': _userActions,
    };
    String jsonData = jsonEncode(logData);

    // 1. Log to the console
    debugPrint("User Actions: $jsonData", wrapWidth: 1024);

    // 2. Save the log to a file
    _saveLogToFile(jsonData);
  }

  /// Saves the log data to a file for persistence.
  Future<void> _saveLogToFile(String logData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_actions_log.txt');
      await file.writeAsString("$logData\n", mode: FileMode.append);
    } catch (e) {
      debugPrint("Error writing log to file: $e");
    }
  }
}