class UserInfo {
  final String deviceType;
  final String width;
  final String height;
  final String countryCode;

  UserInfo({
    required this.deviceType,
    required this.width,
    required this.height,
    required this.countryCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceType': deviceType,
      'width': width,
      'height': height,
      'countryCode': countryCode,
    };
  }
}
