class CustomEvent {
  final String sessionId;
  final String userId;
  final String eventCode;
  final DateTime sendDateTime;
  final String? screenId;
  final Map<String, dynamic>? metadata;

  CustomEvent({
    required this.sessionId,
    required this.userId,
    required this.eventCode,
    required this.sendDateTime,
    this.screenId,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'userId': userId,
    'eventCode': eventCode,
    'sendDateTime': sendDateTime.toIso8601String(),
    'screenId': screenId,
    'metadata': metadata,
  };
}