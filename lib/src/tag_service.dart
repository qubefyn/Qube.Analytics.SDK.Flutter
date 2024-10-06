import 'package:cloud_firestore/cloud_firestore.dart';

class TagService {
  // Function to send tag (which is DeviceID) for now just log it
  Future<void> sendTag(String tag, String deviceID) async {
    try {
      // Add the device ID as a tag to Firebase Firestore
      await FirebaseFirestore.instance.collection('Tags').add({
        'Tag': tag,
        'deviceID': deviceID,
        'timestamp': DateTime.now().toString(),
      });

      print('Tag uploaded: $tag');
    } catch (e) {
      print('Error uploading tag: $e');
    }
  }
}
