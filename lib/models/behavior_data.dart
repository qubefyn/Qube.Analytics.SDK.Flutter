class BehaviorData {
  final String actionType;
  final double x;
  final double y;
  final double screenY;
  final DateTime actionDateTime;
  final String sessionId;
  final String userId;
  final String screenId;

  BehaviorData({
    required this.actionType,
    required this.x,
    required this.y,
    required this.screenY,
    required this.actionDateTime,
    required this.sessionId,
    required this.userId,
    required this.screenId,
  });

  Map<String, dynamic> toJson() => {
    'actionType': actionType,
    'x': x,
    'y': y,
    'screenY': screenY,
    'actionDateTime': actionDateTime.toIso8601String(),
    'sessionId': sessionId,
    'userId': userId,
    'screenId': screenId,
  };
}