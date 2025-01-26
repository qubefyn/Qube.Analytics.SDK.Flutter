class ErrorData {
  final String sessionId;
  final String userId;
  final String? screenId;
  final String errorMessage;
  final String errorStackTrace;
  final bool isCustom;

  ErrorData({
    required this.sessionId,
    required this.userId,
    this.screenId,
    required this.errorMessage,
    required this.errorStackTrace,
    required this.isCustom,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'screenId': screenId,
        'errorMessage': errorMessage,
        'errorStackTrace': errorStackTrace,
        'isCustom': isCustom,
      };
}
