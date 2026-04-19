import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save a message to Firestore
  Future<void> saveMessage(String message) async {
    await _firestore.collection('messages').add({
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get Message
  Future<List<String>> getMessages() async {
    final snapshot = await _firestore.collection('messages').get();

    return snapshot.docs
        .map((doc) => doc['text'] as String)
        .toList();
  }

  // real-time updates
  Stream<List<String>> listenMessages() {
    return _firestore
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc['text'] as String).toList());
  }
}