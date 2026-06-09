import 'dart:async'; // Native Dart timeouts
import 'dart:developer' as dev;
import 'dart:convert';
import 'package:http/http.dart' as http;

class ThingSpeakService {
  // 🔑 Configured via the configure() method
  String channelId = '';
  String apiKey = '';
  final String baseUrl = 'https://api.thingspeak.com';

  // Field mapping documentation (for reference)
  static const String temperatureField = 'field1';
  static const String humidityField = 'field2';
  static const String radarField = 'field3'; // Radar/Motion sensor
  static const String customField4 = 'field4'; // Optional additional sensor

  /// Configure ThingSpeak credentials (call this at app startup)
  void configure({required String channelId, required String apiKey}) {
    this.channelId = channelId;
    this.apiKey = apiKey;
    dev.log('✅ ThingSpeak configured: Channel=$channelId');
  }

  /// Check if ThingSpeak is properly configured
  bool get isConfigured => channelId.isNotEmpty && apiKey.isNotEmpty;

  /// Fetch latest sensor reading from ThingSpeak
  Future<SensorData?> fetchLatestSensorData() async {
    if (!isConfigured) {
      dev.log('❌ ThingSpeak credentials not configured');
      return null;
    }

    try {
      final url = Uri.parse(
        '$baseUrl/channels/$channelId/feeds/last.json?api_key=$apiKey',
      );

      dev.log('📡 Fetching sensor data from ThingSpeak...');

      // Uses Dart's native TimeoutException
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Check if response has actual data
        if (json == null || json.isEmpty) {
          dev.log('❌ Empty response from ThingSpeak');
          return null;
        }

        // Check if we have at least one field with data
        bool hasData = false;
        for (int i = 1; i <= 8; i++) {
          if (json['field$i'] != null) {
            hasData = true;
            break;
          }
        }

        if (!hasData) {
          dev.log('❌ ThingSpeak channel has no field data');
          dev.log('   Ensure ESP32 is sending data to ThingSpeak');
          return null;
        }

        final data = SensorData.fromJson(json);
        dev.log(
          '✅ Sensor data received: Temp=${data.temperature}°C, Humidity=${data.humidity}%, Radar=${data.radar}',
        );
        return data;
      } else {
        dev.log('❌ ThingSpeak API error: ${response.statusCode}');
        
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
      return null;
    }
  }

  /// Fetch sensor data for a specific time range (last N minutes)
  Future<List<SensorData>> fetchSensorHistory({
    required int minutes,
    int limit = 100,
  }) async {
    if (!isConfigured) {
      dev.log('❌ ThingSpeak credentials not configured');
      return [];
    }

    try {
      final url = Uri.parse(
        '$baseUrl/channels/$channelId/feeds.json?api_key=$apiKey&minutes=$minutes&results=$limit',
      );

      dev.log('📊 Fetching sensor history from ThingSpeak...');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final feeds = json['feeds'] as List;
        final data = feeds.map((feed) => SensorData.fromJson(feed)).toList();
        dev.log('✅ Retrieved ${data.length} historical records');
        return data;
      } else {
        dev.log('❌ ThingSpeak API error: ${response.statusCode}');
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

    double avgTemp = 0, avgHumidity = 0, avgRadar = 0;
    int tempCount = 0, humidityCount = 0, radarCount = 0;

    // Increment counts only when the specific sensor data is not null
    for (final data in history) {
      if (data.temperature != null) {
        avgTemp += data.temperature!;
        tempCount++;
      }
      if (data.humidity != null) {
        avgHumidity += data.humidity!;
        humidityCount++;
      }
      if (data.radar != null) {
        avgRadar += data.radar!;
        radarCount++;
      }
    }

    return SensorData(
      temperature: tempCount > 0 ? avgTemp / tempCount : null,
      humidity: humidityCount > 0 ? avgHumidity / humidityCount : null,
      radar: radarCount > 0 ? avgRadar / radarCount : null,
      timestamp: DateTime.now(),
      channelId: channelId,
    );
  }
}

/// Model class for sensor data from ThingSpeak
class SensorData {
  final double? temperature; // Field1: Temperature in °C
  final double? humidity;    // Field2: Humidity in %
  final double? radar;       // Field3: Radar/Motion detection value
  final double? field4;      // Optional additional sensor
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

  /// Parse JSON response from ThingSpeak API
  factory SensorData.fromJson(Map<String, dynamic> json) {
    // Hardcoded fields cleanly decouple the model from the service layer
    return SensorData(
      temperature: _parseDouble(json['field1']),
      humidity: _parseDouble(json['field2']),
      radar: _parseDouble(json['field3']),
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