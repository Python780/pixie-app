import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as dev;

class AnalyticsInteraction {
  final String userQuery;
  final String pixieResponse;
  final String emotion;
  final DateTime timestamp;
  final List<String> topics;

  AnalyticsInteraction({
    required this.userQuery,
    required this.pixieResponse,
    required this.emotion,
    required this.timestamp,
    required this.topics,
  });

  Map<String, dynamic> toMap() => {
    'userQuery': userQuery,
    'pixieResponse': pixieResponse,
    'emotion': emotion,
    'timestamp': timestamp.toIso8601String(),
    'topics': topics,
  };

  factory AnalyticsInteraction.fromMap(Map<String, dynamic> map) =>
      AnalyticsInteraction(
        userQuery: map['userQuery'] ?? '',
        pixieResponse: map['pixieResponse'] ?? '',
        emotion: map['emotion'] ?? 'neutral',
        timestamp: DateTime.parse(
          map['timestamp'] ?? DateTime.now().toIso8601String(),
        ),
        topics: List<String>.from(map['topics'] ?? []),
      );
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _storageKey = 'pixie_analytics_interactions';
  static const int _maxStoredInteractions = 500;

  // Topic keywords for categorization
  static final Map<String, List<String>> _topicKeywords = {
    'weather': [
      'weather',
      'temperature',
      'rain',
      'sunny',
      'cloudy',
      'snow',
      'wind',
      'forecast',
      'humidity',
    ],
    'time': ['time', 'clock', 'hour', 'minute', 'when', 'current time'],
    'joke': ['joke', 'funny', 'laugh', 'humor', 'make me laugh', 'tell a joke'],
    'news': ['news', 'breaking', 'headline', 'recent', 'happening'],
    'math': [
      'calculate',
      'math',
      'plus',
      'minus',
      'multiply',
      'divide',
      'equation',
      'number',
    ],
    'greeting': [
      'hi',
      'hello',
      'hey',
      'good morning',
      'good afternoon',
      'how are you',
    ],
    'music': ['music', 'song', 'play', 'artist', 'album', 'spotify', 'sound'],
    'sports': [
      'sports',
      'game',
      'score',
      'football',
      'basketball',
      'soccer',
      'tennis',
      'match',
    ],
    'general': ['tell me', 'explain', 'what is', 'how', 'why', 'about'],
  };

  /// Log a new interaction
  Future<void> logInteraction({
    required String userQuery,
    required String pixieResponse,
    required String emotion,
  }) async {
    try {
      final topics = _extractTopics(userQuery);
      final interaction = AnalyticsInteraction(
        userQuery: userQuery,
        pixieResponse: pixieResponse,
        emotion: emotion,
        timestamp: DateTime.now(),
        topics: topics,
      );

      final prefs = await SharedPreferences.getInstance();
      final interactionsJson = prefs.getString(_storageKey) ?? '[]';
      final List<dynamic> interactions = jsonDecode(interactionsJson);

      interactions.add(interaction.toMap());

      // Keep only the last N interactions to avoid storage bloat
      if (interactions.length > _maxStoredInteractions) {
        interactions.removeRange(
          0,
          interactions.length - _maxStoredInteractions,
        );
      }

      await prefs.setString(_storageKey, jsonEncode(interactions));
      dev.log('📊 Analytics logged: $topics');
    } catch (e) {
      dev.log('Analytics logging failed: $e');
    }
  }

  /// Get all stored interactions
  Future<List<AnalyticsInteraction>> getInteractions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interactionsJson = prefs.getString(_storageKey) ?? '[]';
      final List<dynamic> data = jsonDecode(interactionsJson);
      return data
          .map(
            (item) =>
                AnalyticsInteraction.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      dev.log('Failed to retrieve interactions: $e');
      return [];
    }
  }

  /// Get topic distribution (count of each topic)
  Future<Map<String, int>> getTopicDistribution() async {
    try {
      final interactions = await getInteractions();
      final topicCounts = <String, int>{};

      for (final interaction in interactions) {
        for (final topic in interaction.topics) {
          topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
        }
      }

      // Add 'untagged' for queries with no topics
      final untagged = interactions.where((i) => i.topics.isEmpty).length;
      if (untagged > 0) {
        topicCounts['untagged'] = untagged;
      }

      return topicCounts;
    } catch (e) {
      dev.log('Failed to get topic distribution: $e');
      return {};
    }
  }

  /// Get emotion distribution
  Future<Map<String, int>> getEmotionDistribution() async {
    try {
      final interactions = await getInteractions();
      final emotionCounts = <String, int>{};

      for (final interaction in interactions) {
        final emotion = interaction.emotion;
        emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
      }

      return emotionCounts;
    } catch (e) {
      dev.log('Failed to get emotion distribution: $e');
      return {};
    }
  }

  /// Get total query count
  Future<int> getTotalQueries() async {
    final interactions = await getInteractions();
    return interactions.length;
  }

  /// Get most common topic
  Future<String?> getMostCommonTopic() async {
    final distribution = await getTopicDistribution();
    if (distribution.isEmpty) return null;
    return distribution.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get recent interactions (last N)
  Future<List<AnalyticsInteraction>> getRecentInteractions({
    int limit = 10,
  }) async {
    final interactions = await getInteractions();
    return interactions.length > limit
        ? interactions.sublist(interactions.length - limit)
        : interactions;
  }

  /// Clear all analytics data
  Future<void> clearAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      dev.log('📊 Analytics cleared');
    } catch (e) {
      dev.log('Failed to clear analytics: $e');
    }
  }

  /// Extract topics from user query
  List<String> _extractTopics(String query) {
    final lowerQuery = query.toLowerCase();
    final foundTopics = <String>{};

    _topicKeywords.forEach((topic, keywords) {
      for (final keyword in keywords) {
        if (lowerQuery.contains(keyword)) {
          foundTopics.add(topic);
          break;
        }
      }
    });

    return foundTopics.toList();
  }
}
