class TempUserModel {
  final String userId;
  final String nickname;
  final DateTime sessionStarted;
  final DateTime deleteAt; // 🌟 Cloud TTL auto-purge marker

  TempUserModel({
    required this.userId,
    required this.nickname,
    DateTime? sessionStarted,
  })  : sessionStarted = sessionStarted ?? DateTime.now(),
        // Calculate the exact deletion deadline (Exactly 7 days from now)
        deleteAt = (sessionStarted ?? DateTime.now()).add(const Duration(days: 7));

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nickname': nickname,
      'sessionStarted': sessionStarted.toIso8601String(),
      'deleteAt': deleteAt, // 🌟 Saved as a native Timestamp for the Cloud TTL engine
    };
  }
}