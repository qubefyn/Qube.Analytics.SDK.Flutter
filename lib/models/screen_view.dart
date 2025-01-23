class ScreenView {
  final String screenId;
  final String screenPath;
  final String screenName;
  final DateTime visitDateTime;
  final String sessionId;

  ScreenView({
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