import 'package:flutter/foundation.dart';
import '../services/thingspeak_service.dart';
import 'dart:developer' as dev;
import 'dart:async';

class SensorProvider extends ChangeNotifier {
  final ThingSpeakService _thingSpeakService = ThingSpeakService();

  // Sensor data state
  SensorData? _currentData;
  List<SensorData> _sensorHistory = [];

  // UI state
  bool _isLoading = false;
  bool _isRefreshing = false; // ✨ Added to prevent full-screen flashing during auto-refresh
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
  bool get isRefreshing => _isRefreshing; // Expose background refresh state if needed
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  double get temperature => _currentData?.temperature ?? 0.0;
  double get humidity => _currentData?.humidity ?? 0.0;
  double get radar => _currentData?.radar ?? 0.0;

  // --- INITIALIZATION ---

  /// Configure ThingSpeak credentials and start auto-refresh
  void configureThingSpeak({
    required String channelId,
    required String apiKey,
    Duration autoRefreshInterval = const Duration(seconds: 30),
  }) {
    dev.log('🔐 Configuring SensorProvider with ThingSpeak credentials');

    _thingSpeakService.configure(channelId: channelId, apiKey: apiKey);

    // Fetch initial data with full loading screen indicator
    fetchLatestData(isInitialFetch: true);

    // Start auto-refresh
    startAutoRefresh(interval: autoRefreshInterval);
  }

  // --- FETCH METHODS ---

  /// Fetch latest sensor data from ThingSpeak
  /// [isInitialFetch] controls whether the screen triggers a full loading spinner or updates silently.
  Future<void> fetchLatestData({bool isInitialFetch = false}) async {
    if (isInitialFetch) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    
    _errorMessage = null;
    notifyListeners();

    dev.log('🔍 fetchLatestData called at ${DateTime.now()} (Initial: $isInitialFetch)');

    try {
      final data = await _thingSpeakService.fetchLatestSensorData();

      if (data != null) {
        // Cache old values safely for logging before updating state
        final oldTemp = _currentData?.temperature;
        final oldHumidity = _currentData?.humidity;
        final oldRadar = _currentData?.radar;

        final dataChanged =
            _currentData == null ||
            oldTemp != data.temperature ||
            oldHumidity != data.humidity ||
            oldRadar != data.radar;

        if (dataChanged) {
          dev.log('✅ NEW DATA RECEIVED:');
          dev.log('   Temperature: $oldTemp → ${data.temperature}°C');
          dev.log('   Humidity: $oldHumidity → ${data.humidity}%');
          dev.log('   Radar: $oldRadar → ${data.radar}');
        } else {
          dev.log('⏸️ NO CHANGE: Same data as before');
        }

        _currentData = data;
        _lastUpdateTime = DateTime.now();
        _errorMessage = null;
      } else {
        if (!_thingSpeakService.isConfigured) {
          _errorMessage = '❌ ThingSpeak not configured. Check configuration constants or your environment setup.';
        } else {
          _errorMessage = '❌ Failed to fetch sensor data - check console logs for details';
        }
        dev.log('❌ $_errorMessage');
      }
    } catch (e) {
      _errorMessage = '❌ Error: $e';
      dev.log('❌ Error fetching data: $e');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Fetch sensor history
  Future<void> fetchHistory({required int minutes, int limit = 100}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _sensorHistory = await _thingSpeakService.fetchSensorHistory(
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
      return await _thingSpeakService.getAverageSensorData(minutes: minutes);
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
      // Background refreshes pass false to ensure silent background execution
      fetchLatestData(isInitialFetch: false);
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
  String get temperatureDisplay => '${temperature.toStringAsFixed(1)}°C';
  String get humidityDisplay => '${humidity.toStringAsFixed(0)}%';
  String get radarDisplay => radar.toStringAsFixed(2);

  bool isDataFresh({int withinSeconds = 60}) {
    if (_lastUpdateTime == null) return false;
    final diff = DateTime.now().difference(_lastUpdateTime!);
    return diff.inSeconds <= withinSeconds;
  }

  String getTimeSinceUpdate() {
    if (_lastUpdateTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastUpdateTime!);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}