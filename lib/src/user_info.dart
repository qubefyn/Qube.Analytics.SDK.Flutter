class UserInfo {
  final String deviceID;
  final String deviceType;
  final String width;
  final String height;
  final String countryCode;

  UserInfo({
    required this.deviceID,
    required this.deviceType,
    required this.width,
    required this.height,
    required this.countryCode,
    //required Future<String?> deviceID,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceID': deviceID,
      'deviceType': deviceType,
      'width': width,
      'height': height,
      'countryCode': countryCode,
    };
  }
}
