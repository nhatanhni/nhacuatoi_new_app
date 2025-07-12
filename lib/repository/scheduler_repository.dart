// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SchedulerRepository {
  final String _baseUrl = 'http://nhacuatoi.com.vn:3000';

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? '';
  }

  Future<List<Map<String, dynamic>>> getSchedules(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/IoT_Scheduler/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return responseBody;
    } else {
      throw Exception('Failed to get schedules');
    }
  }

  Future<Map<String, dynamic>> getScheduleById(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/IoT_Scheduler/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return Map<String, dynamic>.from(responseBody['Data']);
    } else {
      print(response.statusCode);
      throw Exception('Failed to get schedule');
    }
  }

  Future<List<Map<String, dynamic>>> getScheduleBySerial(String serial) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/api/IoT_Scheduler/GetSchedulerSerial?serial=$serial'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(responseBody['Data']);
    } else {
      print(response.statusCode);
      throw Exception('Failed to load schedule');
    }
  }

  Future<void> createSchedule(Map<String, dynamic> schedule) async {
    final bearerToken = await _getToken();
    // print(bearerToken);
    final response = await http.post(
      Uri.parse('$_baseUrl/api/IoT_Scheduler'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      body: jsonEncode(schedule),
    );

    if (response.statusCode != 200) {
      // print("Status code: ${response.statusCode}");
      throw Exception('Failed to create schedule');
    }
  }

  Future<void> updateSchedule(String id, Map<String, dynamic> updates) async {
    // Get the current state of the schedule
    final currentSchedule = await getScheduleById(id);

    // Update the fields
    final updatedSchedule = {...currentSchedule, ...updates};

    final response = await http.put(
      Uri.parse('$_baseUrl/api/IoT_Scheduler'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
      body: jsonEncode(updatedSchedule),
    );

    if (response.statusCode != 200) {
      print(response.statusCode);
      throw Exception('Failed to update schedule');
    }
  }

  Future<void> deleteSchedule(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/IoT_Scheduler'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
      body: jsonEncode([
        {'id': id} // use list of json objects - not just a single object
      ]),
    );

    if (response.statusCode != 200) {
      print(response.statusCode);
      throw Exception('Failed to delete schedule');
    }
  }

  Future<void> deleteScheduleWithGet(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/IoT_Scheduler/DeleteById/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
    );

    if (response.statusCode != 200) {
      print(response.statusCode);
      throw Exception('Failed to delete schedule');
    }
  }
}
