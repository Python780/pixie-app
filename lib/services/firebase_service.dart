import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/temp_user_model.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart'; // 🌟 Import local storage
import 'dart:developer' as dev;

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  TempUserModel? _currentSessionUser;

  TempUserModel? get currentSessionUser => _currentSessionUser;

  // --- ROBOT INTERACTION LOGIC ---

  /// High-efficiency initialization: Reuses device identity to prevent database bloat
  Future<TempUserModel> initializeDeviceUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1. Try to read an existing cached user identity from the phone's local storage
    final String? cachedUid = prefs.getString('pixie_uid');
    final String? cachedNickname = prefs.getString('pixie_nickname');

    if (cachedUid != null && cachedNickname != null) {
      dev.log(
        "📱 Found cached identity on device. Logging in as: $cachedNickname",
      );
      _currentSessionUser = TempUserModel(
        userId: cachedUid,
        nickname: cachedNickname,
      );

      final docRef = _db.collection('temporary_users').doc(cachedUid);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({'lastActive': FieldValue.serverTimestamp()});
      } else {
        await docRef.set({
          'userId': cachedUid,
          'nickname': cachedNickname,
          'sessionStarted': FieldValue.serverTimestamp(),
          'deleteAt': DateTime.now().add(const Duration(days: 7)),
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      return _currentSessionUser!;
    }

    // 2. If no cache exists (First-time open), generate a random identity ONLY ONCE
    dev.log("🆕 First-time install detected. Generating new unique profile...");
    final String randomId =
        "usr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}";

    final List<String> adjectives = [
      "Chippy",
      "Sparky",
      "Rusty",
      "Gizmo",
      "Bleepy",
    ];
    final List<String> nouns = [
      "Human",
      "Driver",
      "Companion",
      "Commander",
      "Pilot",
    ];
    final String randomNickname =
        "${adjectives[Random().nextInt(adjectives.length)]} ${nouns[Random().nextInt(nouns.length)]}";

    final newUser = TempUserModel(userId: randomId, nickname: randomNickname);

    // 3. Save to phone cache so it will NEVER create a duplicate row again
    await prefs.setString('pixie_uid', randomId);
    await prefs.setString('pixie_nickname', randomNickname);

    // 4. Record to Firestore once
    await _db.collection('temporary_users').doc(randomId).set(newUser.toMap());
    await _db.collection('interactions').add({
      'userId': randomId,
      'response': 'New user session started',
      'timestamp': FieldValue.serverTimestamp(),
      'deleteAt': DateTime.now().add(const Duration(days: 2)),
    });

    _currentSessionUser = newUser;
    return newUser;
  }

  // Save the Gemini response to the database
  Future<void> saveInteraction(String response) async {
    if (_currentSessionUser == null) {
      await initializeDeviceUser();
    }

    final String currentUid = _currentSessionUser?.userId ?? "anonymous_user";
    final DateTime deletionDeadline = DateTime.now().add(
      const Duration(days: 2),
    );

    await _db.collection('interactions').add({
      'userId': currentUid,
      'response': response,
      'timestamp': FieldValue.serverTimestamp(),
      // Helps the app know when this data becomes "stale"
      'deleteAt': deletionDeadline,
    });
  }

  // Fetch only the last 60 minutes of data to avoid cloud clutter
  Stream<QuerySnapshot> getRecentInteractions() {
    final String currentUid = _currentSessionUser?.userId ?? "anonymous_user";

    return _db
        .collection('interactions')
        .where('userId', isEqualTo: currentUid)
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
