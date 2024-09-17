import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseMethods {
  Future DeviceInfo(Map<String, dynamic> DeviceInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("Device Information")
        .doc(id)
        .set(DeviceInfoMap);
  }
}
