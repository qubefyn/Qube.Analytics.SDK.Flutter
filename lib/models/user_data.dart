class UserData {
  final String userId;
  final String deviceId;
  final String deviceType;
  final int ram;
  final int cpuCores;
  final String ip;
  final String country;

  UserData({
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    required this.ram,
    required this.cpuCores,
    required this.ip,
    required this.country,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'deviceId': deviceId,
    'deviceType': deviceType,
    'ram': ram,
    'cpuCores': cpuCores,
    'ip': ip,
    'country': country,
  };
}