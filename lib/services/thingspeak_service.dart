import 'dart:async'; // Native Dart timeouts
import 'dart:developer' as dev;
import 'dart:convert';
import 'package:http/http.dart' as http;

class ThingSpeakService {
  String channelId = '';
  String apiKey = '';
  final String baseUrl = 'https://api.thingspeak.com';

  static const String temperatureField = 'field1';
  static const String humidityField = 'field2';
  static const String radarField = 'field3'; 
  static const String customField4 = 'field4'; 

  void configure({required String channelId, required String apiKey}) {
    this.channelId = channelId;
    this.apiKey = apiKey;
    dev.log('✅ ThingSpeak configured: Channel=$channelId');
  }

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
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // ThingSpeak returns -1 or empty string if the channel has absolutely no entries yet
        if (json == null || json is String || json.isEmpty || json['entry_id'] == null) {
          dev.log('❌ Empty or invalid response from ThingSpeak. Ensure ESP32 has uploaded at least one data point.');
          return null;
        }

        final data = SensorData.fromJson(json);
        
        // Ensure at least one of your tracked fields isn't null
        if (data.temperature == null && data.humidity == null && data.radar == null) {
          dev.log('⚠️ Data container received, but target fields (1-3) are empty.');
          return null;
        }

        dev.log(
          '✅ Sensor data received: Temp=${data.temperature}°C, Humidity=${data.humidity}%, Radar=${data.radar}',
        );
        return data;
      } else {
        dev.log('❌ ThingSpeak API error: ${response.statusCode}');
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
        if (json == null || json['feeds'] == null) return [];
        
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

class SensorData {
  final double? temperature; 
  final double? humidity;    
  final double? radar;       
  final double? field4;      
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

  factory SensorData.fromJson(Map<String, dynamic> json) {
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