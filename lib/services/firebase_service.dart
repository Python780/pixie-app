import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- ROBOT INTERACTION LOGIC ---

  // Save the Gemini response to the database
  Future<void> saveInteraction(String response) async {
    await _db.collection('interactions').add({
      'response': response,
      'timestamp': FieldValue.serverTimestamp(),
      // Helps the app know when this data becomes "stale"
      'expireAt': DateTime.now().add(const Duration(hours: 1)),
    });
  }

  // Fetch only the last 60 minutes of data to avoid cloud clutter
  Stream<QuerySnapshot> getRecentInteractions() {
    DateTime oneHourAgo = DateTime.now().subtract(const Duration(minutes: 60));

    return _db
        .collection('interactions')
        .where('timestamp', isGreaterThan: oneHourAgo)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- GENERAL MESSAGE LOGIC (Your Friend's Code) ---

  Future<void> saveMessage(String message) async {
    await _db.collection('messages').add({
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> listenMessages() {
    return _db
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc['text'] as String).toList(),
        );
  }
}
