import 'dart:convert';
import 'package:bmsapp/pages/home.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class MongoService {
  // Replace with your actual server URL
  static const String _baseUrl = 'https://app.eeebms.com/api';


  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Initialize method - no longer needed for direct DB connection
  static Future<void> init() async {
    print('✅ API Client Initialized');
  }

  static Future<List<Object>> getBuildingsByUserId(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/buildings/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('🔍 buildings for userId $userId → ${data.length}');
        return data.map((d) => LocationData.fromMap(d)).toList();
      } else {
        throw Exception('Failed to fetch buildings: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching buildings by user: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchEvents({
    required String buildingId,
  }) async {
    try {
      // Debugging: Log the URL being requested
      print('🔗 Fetching events from URL: $_baseUrl/events/$buildingId');

      final response = await http.get(
        Uri.parse('$_baseUrl/events/$buildingId'),
        headers: _headers,
      );

      // Debugging: Log the response status code and headers
      print('🔑 Response Status Code: ${response.statusCode}');
      print('📜 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        // Debugging: Log the raw response body before parsing
        print('📄 Raw Response Body: ${response.body}');

        final List<dynamic> data = jsonDecode(response.body);
        print('🔍 Fetched ${data.length} events for buildingID $buildingId');

        return data.cast<Map<String, dynamic>>();
      } else {
        // Debugging: Log the error response body for failed status codes
        print('❗ Error Response Body: ${response.body}');
        throw Exception('Failed to fetch events: ${response.statusCode}');
      }
    } catch (e) {
      // Debugging: Log the exact error caught
      print('❌ fetchEvents error: $e');
      return [];
    }
  }

  static Future<void> saveSettings(String floorPlanId, Map<String, dynamic> settings) async {
    final url = '$_baseUrl/save-settings/$floorPlanId';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(settings),
      );
      print(settings);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['matchedCount'] == 0) {
          throw Exception('No matching settings found to update');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to save settings: ${error['error']}');
      }
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }
  static Future<void> addEvent(Map<String, dynamic> event) async {
    final url = '$_baseUrl/events';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(event),
      );
      if (response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception('Failed to add event: ${error['error']}');
      }
    } catch (e) {
      print('Error adding event: $e');
      rethrow;
    }
  }
  static Future<void> deleteEvent(String eventId) async {
    final url = '$_baseUrl/events/$eventId';
    final response = await http.delete(Uri.parse(url), headers: _headers);
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception('Failed to delete event: ${error['error']}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSurveyByBuildingName(
      String buildingName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/surveys/$buildingName'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ Found ${data.length} surveys for "$buildingName"');

        return data.map((doc) {
          return {
            'user': doc['user'] ?? 'Anonymous',
            'units': List<String>.from(doc['units'] ?? []),
            'rating': (doc['rating'] as num?)?.toDouble() ?? 0.0,
            'comment': doc['comment'] ?? '',
            'timestamp': DateTime.tryParse(doc['timestamp'] ?? '')?.toLocal() ?? DateTime.now(),
          };
        }).toList().cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch surveys: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching surveys: $e');
      return [];
    }
  }

  static Future<void> updateAirconSetting(String buildingName, String slaveId, String action,
      {dynamic value}) async {
    final payload = {
      'buildingName': buildingName,
      'slaveId': slaveId,
      'action': action,
      if (value != null) 'value': value,
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/aircon/setting'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception('Failed to update AC: ${error['error']}');
      }
    } catch (e) {
      print('Error updating AC: $e');
      rethrow;
    }
  }

  static Future<void> updateAirconPower(String buildingName, String slaveId, bool isOn) async {
    final payload = {
      'buildingName': buildingName,
      'slaveId': slaveId,
      'isOn': isOn,
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/aircon/power'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception('Failed to toggle power: ${error['error']}');
      }
    } catch (e) {
      print('Error toggling power: $e');
      rethrow;
    }
  }

  static Future<void> turnOnAircon({
    required String buildingName,
    required String slaveId,
    required double temperature,
    required String fanMode,
  }) async {
    print('=== Turning ON Aircon for $slaveId ===');

    // Map fan mode string to integer value
    final Map<String, int> fanModeMap = {
      'AUTO': 0,
      'VERY LOW': 1,
      'LOW': 2,
      'MID': 3,
      'HIGH': 4,
      'VERY HIGH': 5,
    };

    final int fanModeValue = fanModeMap[fanMode] ?? 3; // Default to MID if not found

    final payload = {
      'buildingName': buildingName,
      'slaveId': slaveId,
      'temperature': temperature,
      'fanMode': fanModeValue, // Send integer value instead of string
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/aircon/turnon'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception('Failed to turn on aircon: ${error['error']}');
      }

      print('✅ Aircon ON sequence complete for $slaveId');
    } catch (e) {
      print('Error turning on aircon: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllSensorData(
      String building, {
        String timeRange = 'today',
      }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sensor/$building?timeRange=$timeRange'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('🔍 Fetched ${data.length} docs from ${building.toLowerCase()}_readings');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch sensor data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ fetchAllSensorData error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchLatestAirconStatus(String building) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/aircon/status/$building'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('🔍 Latest aircon status (${building.toLowerCase()}_aircon_status): $data');
        return data;
      } else if (response.statusCode == 404) {
        print('⚠️ No aircon status data found for $building');
        return null;
      } else {
        throw Exception('Failed to fetch aircon status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ fetchLatestAirconStatus error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getFloorPlansByBuildingName(String buildingName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/floorplans/$buildingName'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('📄 Found ${data.length} floor plans for "$buildingName"');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch floor plans: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ getFloorPlansByBuildingName error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getZonesByFloorPlanId(
      String floorPlanId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/zones/$floorPlanId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch zones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ getZonesByFloorPlanId error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchLatestSensorData(String building) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sensor/latest/$building'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        print('⚠️ No data found for $building');
        return null;
      } else {
        throw Exception('Failed to fetch latest sensor data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ fetchLatestSensorData error: $e');
      return null;
    }
  }

  // Helper methods for formatting (keeping for compatibility)
  static String _formatMongoDate(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return "$dayName $monthName $day ${date.year}";
  }

  static String _formatMongoMonth(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
  }

  // No longer needed - data processing is done on server
  static Map<String, dynamic> _flattenEnergyReadings(Map<String, dynamic> doc) {
    // This method is now handled by the server
    // Keeping for backward compatibility, but should not be used
    return doc;
  }
  // mongodb.dart
  static Future<Map<String, dynamic>> getSettings(String floorPlanId) async {
    final url = '$_baseUrl/get-settings/$floorPlanId';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Corrected Fix: Access the top-level settings object
        final innerSettings = data['settings'] ?? {};
        print('Retrieved Smart Temperature Control Settings:');
        print('  Smart Temp Control: ${innerSettings['smartTempControl'] ?? 'NONE'}');
        print('  Min Temp: ${innerSettings['setPointTempRange']?['min']?.toDouble() ?? 'NONE'}');
        print('  Max Temp: ${innerSettings['setPointTempRange']?['max']?.toDouble() ?? 'NONE'}');
        print('  Desired Temp: ${innerSettings['desiredRoomTemp']?.toDouble() ?? 'NONE'}');
        print('${innerSettings['dailySettings']}');

        return {
          'smart_temp_control': innerSettings['smartTempControl'] ?? false,
          'min_temp': innerSettings['setPointTempRange']?['min']?.toDouble() ?? 20.0,
          'max_temp': innerSettings['setPointTempRange']?['max']?.toDouble() ?? 25.0,
          'desired_temp': innerSettings['desiredRoomTemp']?.toDouble() ?? 22.0,
          'daily_settings': {
            'monday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['monday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['monday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['monday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['monday']?['autoSwitchOffTime']
              ),
            },
            'tuesday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['tuesday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['tuesday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['tuesday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['tuesday']?['autoSwitchOffTime']
              ),
            },
            'wednesday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['wednesday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['wednesday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['wednesday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['wednesday']?['autoSwitchOffTime']
              ),
            },
            'thursday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['thursday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['thursday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['thursday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['thursday']?['autoSwitchOffTime']
              ),
            },
            'friday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['friday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['friday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['friday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['friday']?['autoSwitchOffTime']
              ),
            },
            'saturday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['saturday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['saturday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['saturday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['saturday']?['autoSwitchOffTime']
              ),
            },
            'sunday': {
              'preCoolingEnabled': innerSettings['dailySettings']?['sunday']?['preCoolingEnabled'] ?? false,
              'preCoolingTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['sunday']?['preCoolingTime']
              ),
              'autoSwitchOffEnabled': innerSettings['dailySettings']?['sunday']?['autoSwitchOffEnabled'] ?? false,
              'autoSwitchOffTime': _parseTimeStringToDouble(
                  innerSettings['dailySettings']?['sunday']?['autoSwitchOffTime']
              ),
            },
          }
        };
      } else {
        throw Exception('Failed to fetch settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching settings: $e');
      rethrow;
    }
  }
  static Future<List<Map<String, dynamic>>> fetchPredictedEnergyW512({
    String timeRange = 'today',
  }) async {
    try {
      // Construct the URL with the timeRange query parameter
      final Uri url = Uri.parse('$_baseUrl/predicted-energy/w512?timeRange=$timeRange');

      print('🔗 Fetching W512 predicted energy data for timeRange: $timeRange from URL: $url');

      final response = await http.get(
        url,
        headers: _headers,
      );

      print('🔑 W512 Predicted Energy Response Status Code: ${response.statusCode}');
      // Optional: print headers if needed for debugging
      // print('📜 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        // Parse the JSON response body
        final List<dynamic> data = jsonDecode(response.body);

        print('📄 Fetched ${data.length} W512 predicted energy records for timeRange: $timeRange');

        // Cast the list of dynamic maps to List<Map<String, dynamic>>
        // Ensure the data structure matches what your Dart code expects
        return data.cast<Map<String, dynamic>>();
      } else {
        // Handle non-200 status codes
        print('❗ W512 Predicted Energy Error Response Body: ${response.body}');
        throw Exception('Failed to fetch W512 predicted energy data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle network errors, JSON parsing errors, etc.
      print('❌ fetchPredictedEnergyW512 error: $e');
      // Returning an empty list might be appropriate, or rethrow depending on your app's error handling strategy
      return [];
      // If you want the caller to handle the exception, use: rethrow;
    }
  }

  /// Fetches predicted energy data for SPGG.
  ///
  /// Optionally specify a [timeRange] (e.g., 'today', 'week', 'month', 'year', 'all').
  /// Defaults to 'today'.
  static Future<List<Map<String, dynamic>>> fetchPredictedEnergySPGG({
    String timeRange = 'today',
  }) async {
    try {
      // Construct the URL with the timeRange query parameter
      final Uri url = Uri.parse('$_baseUrl/predicted-energy/spgg?timeRange=$timeRange');

      print('🔗 Fetching SPGG predicted energy data for timeRange: $timeRange from URL: $url');

      final response = await http.get(
        url,
        headers: _headers,
      );

      print('🔑 SPGG Predicted Energy Response Status Code: ${response.statusCode}');
      // Optional: print headers if needed for debugging
      // print('📜 Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        // Parse the JSON response body
        final List<dynamic> data = jsonDecode(response.body);

        print('📄 Fetched ${data.length} SPGG predicted energy records for timeRange: $timeRange');

        // Cast the list of dynamic maps to List<Map<String, dynamic>>
        // Ensure the data structure matches what your Dart code expects
        return data.cast<Map<String, dynamic>>();
      } else {
        // Handle non-200 status codes
        print('❗ SPGG Predicted Energy Error Response Body: ${response.body}');
        throw Exception('Failed to fetch SPGG predicted energy data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle network errors, JSON parsing errors, etc.
      print('❌ fetchPredictedEnergySPGG error: $e');
      // Returning an empty list might be appropriate, or rethrow depending on your app's error handling strategy
      return [];
      // If you want the caller to handle the exception, use: rethrow;
    }
  }

// ... (other methods in the MongoService class)

  // Close method - no longer needed for API client
  static Future<void> close() async {
    print('🛑 API Client closed');
  }
  static double _parseTimeStringToDouble(dynamic timeValue) {
    if (timeValue is double) return timeValue;
    if (timeValue is int) return timeValue.toDouble();

    if (timeValue is String) {
      final parts = timeValue.split(':');
      if (parts.length == 2) {
        try {
          final hour = int.parse(parts[0]);
          return hour.toDouble();
        } catch (_) {}
      }
    }
    return 7.0; // Default value
  }

}
