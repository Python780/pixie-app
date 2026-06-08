import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'dart:convert';

class ThinkSpeakService {
  // 🔑 These will be set by configure() method
  late String channelId;
  late String apiKey;
  final String baseUrl = 'https://api.thingspeak.com';

  // Field mapping (customize based on your ESP32 setup)
  static const String temperatureField = 'field1';
  static const String humidityField = 'field2';
  static const String radarField = 'field3'; // Radar/Motion sensor
  static const String customField4 = 'field4'; // Optional additional sensor

  ThinkSpeakService() {
    channelId = '';
    apiKey = '';
  }

  /// Configure ThinkSpeak credentials (call this at app startup)
  void configure({required String channelId, required String apiKey}) {
    this.channelId = channelId;
    this.apiKey = apiKey;
    dev.log('✅ ThinkSpeak configured: Channel=$channelId');
  }

  /// Check if ThinkSpeak is properly configured
  bool get isConfigured => channelId.isNotEmpty && apiKey.isNotEmpty;

  /// Fetch latest sensor reading from ThinkSpeak
  Future<SensorData?> fetchLatestSensorData() async {
    if (channelId.isEmpty || apiKey.isEmpty) {
      dev.log('❌ ThinkSpeak credentials not configured');
      dev.log('   channelId: "$channelId" (empty: ${channelId.isEmpty})');
      dev.log('   apiKey: "$apiKey" (empty: ${apiKey.isEmpty})');
      return null;
    }

    try {
      final url = Uri.parse(
        '$baseUrl/channels/$channelId/feeds/last.json?api_key=$apiKey',
      );

      dev.log('📡 Fetching sensor data from ThinkSpeak...');
      dev.log('   URL: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('ThinkSpeak API timeout');
            },
          );

      dev.log('📊 Response status: ${response.statusCode}');
      dev.log('📊 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Check if response has actual data
        if (json == null || json.isEmpty) {
          dev.log('❌ Empty response from ThinkSpeak');
          dev.log('   Response: ${response.body}');
          return null;
        }

        // For /last.json endpoint, we get a single object
        // Check if we have at least one field with data
        bool hasData = false;
        for (int i = 1; i <= 8; i++) {
          if (json['field$i'] != null) {
            hasData = true;
            break;
          }
        }

        if (!hasData) {
          dev.log('❌ ThinkSpeak channel has no field data');
          dev.log('   Response: ${response.body}');
          dev.log('   Ensure ESP32 is sending data to ThinkSpeak');
          return null;
        }

        final data = SensorData.fromJson(json);
        dev.log(
          '✅ Sensor data received: Temp=${data.temperature}°C, Humidity=${data.humidity}%, Radar=${data.radar}',
        );
        dev.log(
          '   Entry ID: ${json['entry_id']} (created: ${json['created_at']})',
        );
        dev.log('   Parsed values:');
        dev.log(
          '   - Temperature: ${data.temperature} (raw: ${json[ThinkSpeakService.temperatureField]})',
        );
        dev.log(
          '   - Humidity: ${data.humidity} (raw: ${json[ThinkSpeakService.humidityField]})',
        );
        dev.log(
          '   - Radar: ${data.radar} (raw: ${json[ThinkSpeakService.radarField]})',
        );
        dev.log('   - Timestamp: ${data.timestamp}');
        return data;
      } else {
        dev.log('❌ ThinkSpeak API error: ${response.statusCode}');
        dev.log('   Response: ${response.body}');

        // Parse error message from response
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['error'] != null) {
            dev.log('   Error: ${errorJson['error']}');
          }
        } catch (_) {}

        return null;
      }
    } on TimeoutException catch (e) {
      dev.log('⏱️ Timeout: $e');
      return null;
    } catch (e) {
      dev.log('❌ Error fetching sensor data: $e');
      dev.log('   Stack trace: $e');
      return null;
    }
  }

  /// Fetch sensor data for a specific time range (last N minutes)
  Future<List<SensorData>> fetchSensorHistory({
    required int minutes,
    int limit = 100,
  }) async {
    if (channelId.isEmpty || apiKey.isEmpty) {
      dev.log('❌ ThinkSpeak credentials not configured');
      return [];
    }

    try {
      final url = Uri.parse(
        '$baseUrl/channels/$channelId/feeds.json?api_key=$apiKey&minutes=$minutes&results=$limit',
      );

      dev.log('📊 Fetching sensor history from ThinkSpeak...');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final feeds = json['feeds'] as List;
        final data = feeds.map((feed) => SensorData.fromJson(feed)).toList();
        dev.log('✅ Retrieved ${data.length} historical records');
        return data;
      } else {
        dev.log('❌ ThinkSpeak API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      dev.log('❌ Error fetching sensor history: $e');
      return [];
    }
  }

  /// Get average sensor values for a time period
  Future<SensorData?> getAverageSensorData({required int minutes}) async {
    final history = await fetchSensorHistory(minutes: minutes);
    if (history.isEmpty) return null;

    double avgTemp = 0;
    double avgHumidity = 0;
    double avgRadar = 0;
    int count = 0;

    for (final data in history) {
      if (data.temperature != null) {
        avgTemp += data.temperature!;
      }
      if (data.humidity != null) {
        avgHumidity += data.humidity!;
      }
      if (data.radar != null) {
        avgRadar += data.radar!;
      }
      count++;
    }

    return SensorData(
      temperature: count > 0 ? avgTemp / count : null,
      humidity: count > 0 ? avgHumidity / count : null,
      radar: count > 0 ? avgRadar / count : null,
      timestamp: DateTime.now(),
      channelId: channelId,
    );
  }
}

/// Model class for sensor data from ThinkSpeak
class SensorData {
  final double? temperature; // Field1: Temperature in °C
  final double? humidity; // Field2: Humidity in %
  final double? radar; // Field3: Radar/Motion detection value
  final double? field4; // Optional additional sensor
  final DateTime? timestamp;
  final String? channelId;

  SensorData({
    this.temperature,
    this.humidity,
    this.radar,
    this.field4,
    this.timestamp,
    this.channelId,
  });

  /// Parse JSON response from ThinkSpeak API
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: _parseDouble(json[ThinkSpeakService.temperatureField]),
      humidity: _parseDouble(json[ThinkSpeakService.humidityField]),
      radar: _parseDouble(json[ThinkSpeakService.radarField]),
      field4: _parseDouble(json['field4']),
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      channelId: json['channel_id']?.toString(),
    );
  }

  /// Helper to safely parse doubles from JSON
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  String toString() {
    return 'SensorData(temp: $temperature°C, humidity: $humidity%, radar: $radar)';
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
