import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/system.dart';
import 'api.dart';

class UnitService extends Api {
  Future<List<dynamic>> getUnits() async {
    try {
      String url = this.baseUrl + this.apiUrl + '/unit';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var units = jsonDecode(response.body);
        log("Units API Response: ${response.body}");

        // Store units in local database for offline access
        if (units != null && units['data'] != null) {
          System().insert('units', jsonEncode(units['data']));
          return units['data'] as List<dynamic>;
        } else {
          log("No units data found in response");
          return [];
        }
      } else {
        log("Units API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching units: ${e.toString()}");
      return [];
    }
  }

  // Get specific unit by ID
  Future<Map<String, dynamic>?> getUnitById(String unitId) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/unit/$unitId';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var unit = jsonDecode(response.body);
        log("Unit details API Response: ${response.body}");

        if (unit != null && unit['data'] != null) {
          return unit['data'] as Map<String, dynamic>;
        } else {
          log("No unit data found for ID: $unitId");
          return null;
        }
      } else {
        log("Unit API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching unit by ID: ${e.toString()}");
      return null;
    }
  }
}
