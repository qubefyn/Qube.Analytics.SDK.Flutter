class SessionUtils {
  static String generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String generateScreenId(String screenPath) {
    return screenPath.hashCode.toString();
  }
}