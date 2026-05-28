import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final total = await _analyticsService.getTotalQueries();
    final topicDistribution = await _analyticsService.getTopicDistribution();
    final emotionDistribution = await _analyticsService
        .getEmotionDistribution();
    final mostCommonTopic = await _analyticsService.getMostCommonTopic();
    final recentInteractions = await _analyticsService.getRecentInteractions(
      limit: 10,
    );
    return {
      'total': total,
      'topics': topicDistribution,
      'emotions': emotionDistribution,
      'mostCommonTopic': mostCommonTopic,
      'recentInteractions': recentInteractions,
    };
  }

  Widget _buildPieChart(Map<String, int> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No analytics data available yet.'));
    }

    final total = data.values.fold<int>(0, (sum, item) => sum + item);
    final sections = data.entries.map((entry) {
      final value = entry.value.toDouble();
      return PieChartSectionData(
        title: '${entry.key} (${entry.value})',
        value: value,
        radius: 70,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    return AspectRatio(
      aspectRatio: 1.4,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          borderData: FlBorderData(show: false),
          pieTouchData: PieTouchData(enabled: true),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pixie Analytics'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF121212),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load analytics: ${snapshot.error}'),
            );
          }

          final data = snapshot.data ?? {};
          final total = data['total'] as int? ?? 0;
          final topics = Map<String, int>.from(
            data['topics'] as Map<String, dynamic>? ?? {},
          );
          final emotions = Map<String, int>.from(
            data['emotions'] as Map<String, dynamic>? ?? {},
          );
          final mostCommonTopic = data['mostCommonTopic'] as String?;
          final recentInteractions =
              data['recentInteractions'] as List<AnalyticsInteraction>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: const Color(0xFF1F1F1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analytics Summary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Total queries: $total',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Top topic: ${mostCommonTopic ?? 'None yet'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Topic distribution',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPieChart(topics),
                ),
                const SizedBox(height: 16),
                Text(
                  'Emotion distribution',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPieChart(emotions),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recent interactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...recentInteractions.reversed.map((interaction) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(interaction.timestamp),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You: ${interaction.userQuery}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pixie: ${interaction.pixieResponse}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Topics: ${interaction.topics.isNotEmpty ? interaction.topics.join(', ') : 'none'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Emotion: ${interaction.emotion}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
