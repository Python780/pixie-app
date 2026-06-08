import 'package:flutter/foundation.dart';
import '../services/thinkspeak_service.dart';
import 'dart:developer' as dev;
import 'dart:async';

class SensorProvider extends ChangeNotifier {
  final ThinkSpeakService _thinkSpeakService = ThinkSpeakService();

  // Sensor data state
  SensorData? _currentData;
  List<SensorData> _sensorHistory = [];

  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdateTime;

  // Auto-refresh timer
  Timer? _refreshTimer;

  SensorProvider() {
    dev.log('📊 SensorProvider initialized');
  }

  // --- GETTERS ---
  SensorData? get currentData => _currentData;
  List<SensorData> get sensorHistory => _sensorHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  double get temperature => _currentData?.temperature ?? 0.0;
  double get humidity => _currentData?.humidity ?? 0.0;
  double get radar => _currentData?.radar ?? 0.0;

  // --- INITIALIZATION ---

  /// Configure ThinkSpeak credentials and start auto-refresh
  void configureThinkSpeak({
    required String channelId,
    required String apiKey,
    Duration autoRefreshInterval = const Duration(seconds: 30),
  }) {
    dev.log('🔐 Configuring SensorProvider with ThinkSpeak credentials');
    dev.log('   channelId: "$channelId"');
    dev.log('   apiKey: "$apiKey"');

    _thinkSpeakService.configure(channelId: channelId, apiKey: apiKey);

    dev.log(
      '   Service channelId after configure: "${_thinkSpeakService.channelId}"',
    );
    dev.log(
      '   Service apiKey after configure: "${_thinkSpeakService.apiKey}"',
    );

    // Start auto-refresh
    startAutoRefresh(interval: autoRefreshInterval);

    // Fetch initial data
    fetchLatestData();
  }

  // --- FETCH METHODS ---

  /// Fetch latest sensor data from ThinkSpeak
  Future<void> fetchLatestData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    dev.log('🔍 fetchLatestData called at ${DateTime.now()}');

    try {
      final data = await _thinkSpeakService.fetchLatestSensorData();

      if (data != null) {
        // Check if data actually changed
        final dataChanged =
            _currentData == null ||
            _currentData!.temperature != data.temperature ||
            _currentData!.humidity != data.humidity ||
            _currentData!.radar != data.radar;

        if (dataChanged) {
          dev.log('✅ NEW DATA RECEIVED:');
          dev.log(
            '   Temperature: ${_currentData?.temperature} → ${data.temperature}°C',
          );
          dev.log('   Humidity: ${_currentData?.humidity} → ${data.humidity}%');
          dev.log('   Radar: ${_currentData?.radar} → ${data.radar}');
          dev.log(
            '   ThinkSpeak Entry ID: ${data.channelId} (updated at ${data.timestamp})',
          );
        } else {
          dev.log(
            '⏸️ NO CHANGE: Same data as before (Entry ID: ${data.channelId})',
          );
        }

        _currentData = data;
        _lastUpdateTime = DateTime.now();
        _errorMessage = null;
      } else {
        // Service returned null - could be many reasons
        if (!_thinkSpeakService.isConfigured) {
          _errorMessage =
              '❌ ThinkSpeak not configured. Check .env for THINKSPEAK_CHANNEL_ID and THINKSPEAK_API_KEY';
        } else {
          _errorMessage =
              '❌ Failed to fetch sensor data - check console logs for details';
        }
        dev.log('❌ $_errorMessage');
      }
    } catch (e) {
      _errorMessage = '❌ Error: $e';
      dev.log('❌ Error fetching data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch sensor history
  Future<void> fetchHistory({required int minutes, int limit = 100}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _sensorHistory = await _thinkSpeakService.fetchSensorHistory(
        minutes: minutes,
        limit: limit,
      );
      dev.log('✅ Fetched ${_sensorHistory.length} historical records');
    } catch (e) {
      _errorMessage = 'Error fetching history: $e';
      dev.log('❌ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get average sensor values
  Future<SensorData?> getAverageData({required int minutes}) async {
    try {
      return await _thinkSpeakService.getAverageSensorData(minutes: minutes);
    } catch (e) {
      dev.log('❌ Error getting average data: $e');
      return null;
    }
  }

  // --- AUTO-REFRESH ---

  /// Start automatic data refresh
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      fetchLatestData();
    });
    dev.log('🔄 Auto-refresh started (${interval.inSeconds}s interval)');
  }

  /// Stop automatic refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    dev.log('⏹️ Auto-refresh stopped');
  }

  // --- UTILITY ---

  /// Format temperature for display
  String get temperatureDisplay => '${temperature.toStringAsFixed(1)}°C';

  /// Format humidity for display
  String get humidityDisplay => '${humidity.toStringAsFixed(0)}%';

  /// Format radar value for display
  String get radarDisplay => '${radar.toStringAsFixed(2)}';

  /// Check if data is fresh (within last N seconds)
  bool isDataFresh({int withinSeconds = 60}) {
    if (_lastUpdateTime == null) return false;
    final diff = DateTime.now().difference(_lastUpdateTime!);
    return diff.inSeconds <= withinSeconds;
  }

  /// Get time since last update
  String getTimeSinceUpdate() {
    if (_lastUpdateTime == null) return 'Never';

    final diff = DateTime.now().difference(_lastUpdateTime!);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
