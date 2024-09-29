
class TagService {
  // Function to send tag (which is DeviceID) for now just log it
  void sendTag(String tag) {
    // Simulate sending tag, later this will be replaced with Firebase logic
    print('Tag received: $tag');
    
    // In future, this is where you'll add Firebase code to send 'tag'
    // Example:
    // FirebaseFirestore.instance.collection('tags').add({'deviceID': tag});
  }
}