import 'dart:convert' as convert;
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:pos_final/api_end_points.dart';

import '../config.dart';

class Api {
  String baseUrl = Config.baseUrl,
      apiUrl = ApiEndPoints.apiUrl,
      clientId = Config().clientId,
      clientSecret = Config().clientSecret;

  //validate the login details
  Future<Map?> login(String username, String password) async {
    String url = ApiEndPoints.loginUrl;

    Map body = {
      'grant_type': 'password',
      'client_id': clientId,
      'client_secret': clientSecret,
      'username': username,
      'password': password,
    };
    var response = await http.post(Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body);
    var jsonResponse = convert.jsonDecode(response.body);
    print(jsonResponse);
    if (response.statusCode == 200) {
      //logged in successfully
      return {'success': true, 'access_token': jsonResponse['access_token']};
    } else if (response.statusCode == 401) {
      //Invalid credentials
      return {'success': false, 'error': jsonResponse['error']};
    } else {
      return null;
    }
  }

  getHeader(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token'
    };
  }

  // Enhanced GET request with retry and error handling
  Future<Map<String, dynamic>> apiGet(String endpoint,
      {Map<String, String>? headers,
      Map<String, String>? queryParams,
      int maxRetries = 3}) async {
    return await _performRequest('GET', endpoint,
        headers: headers, queryParams: queryParams, maxRetries: maxRetries);
  }

  // Enhanced POST request with retry and error handling
  Future<Map<String, dynamic>> apiPost(String endpoint,
      {Map<String, String>? headers,
      dynamic body,
      Map<String, String>? queryParams,
      int maxRetries = 3}) async {
    return await _performRequest('POST', endpoint,
        headers: headers,
        body: body,
        queryParams: queryParams,
        maxRetries: maxRetries);
  }

  // Enhanced PUT request with retry and error handling
  Future<Map<String, dynamic>> apiPut(String endpoint,
      {Map<String, String>? headers,
      dynamic body,
      Map<String, String>? queryParams,
      int maxRetries = 3}) async {
    return await _performRequest('PUT', endpoint,
        headers: headers,
        body: body,
        queryParams: queryParams,
        maxRetries: maxRetries);
  }

  // Enhanced DELETE request with retry and error handling
  Future<Map<String, dynamic>> apiDelete(String endpoint,
      {Map<String, String>? headers,
      Map<String, String>? queryParams,
      int maxRetries = 3}) async {
    return await _performRequest('DELETE', endpoint,
        headers: headers, queryParams: queryParams, maxRetries: maxRetries);
  }

  // Core request performer with retry logic
  Future<Map<String, dynamic>> _performRequest(String method, String endpoint,
      {Map<String, String>? headers,
      dynamic body,
      Map<String, String>? queryParams,
      int maxRetries = 3}) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        // Build full URL
        String url =
            endpoint.startsWith('http') ? endpoint : '$baseUrl$endpoint';

        // Add query parameters if provided
        if (queryParams != null && queryParams.isNotEmpty) {
          String queryString =
              queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          url += url.contains('?') ? '&$queryString' : '?$queryString';
        }

        // Prepare request
        http.Request request = http.Request(method, Uri.parse(url));

        // Set headers
        if (headers != null) {
          request.headers.addAll(headers);
        }

        // Set body for non-GET requests
        if (body != null && method != 'GET') {
          if (body is String) {
            request.body = body;
          } else if (body is Map) {
            request.body = convert.jsonEncode(body);
            request.headers['Content-Type'] = 'application/json';
          }
        }

        log("API Request: $method $url");
        if (body != null) log("Request Body: $body");

        // Execute request
        http.StreamedResponse streamedResponse = await request.send();
        http.Response response =
            await http.Response.fromStream(streamedResponse);

        log("API Response: ${response.statusCode}");

        // Handle different status codes
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          try {
            var responseData = convert.jsonDecode(response.body);
            return {
              'success': true,
              'statusCode': response.statusCode,
              'data': responseData,
              'message': 'Request successful'
            };
          } catch (e) {
            // Response is not JSON
            return {
              'success': true,
              'statusCode': response.statusCode,
              'data': response.body,
              'message': 'Request successful'
            };
          }
        } else if (response.statusCode == 401) {
          // Unauthorized - token might be expired
          return {
            'success': false,
            'statusCode': response.statusCode,
            'error': 'Unauthorized - token may be expired',
            'data': null
          };
        } else if (response.statusCode == 403) {
          // Forbidden
          return {
            'success': false,
            'statusCode': response.statusCode,
            'error': 'Forbidden - insufficient permissions',
            'data': null
          };
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client error
          try {
            var errorData = convert.jsonDecode(response.body);
            return {
              'success': false,
              'statusCode': response.statusCode,
              'error': errorData['message'] ?? 'Client error',
              'data': errorData
            };
          } catch (e) {
            return {
              'success': false,
              'statusCode': response.statusCode,
              'error': 'Client error: ${response.body}',
              'data': null
            };
          }
        } else if (response.statusCode >= 500) {
          // Server error - retry if attempts remain
          if (attempt < maxRetries - 1) {
            attempt++;
            log("Server error, retrying... (attempt ${attempt + 1}/$maxRetries)");
            await Future.delayed(
                Duration(seconds: attempt)); // Exponential backoff
            continue;
          } else {
            return {
              'success': false,
              'statusCode': response.statusCode,
              'error': 'Server error after $maxRetries attempts',
              'data': null
            };
          }
        } else {
          // Other status codes
          return {
            'success': false,
            'statusCode': response.statusCode,
            'error': 'Unexpected status code: ${response.statusCode}',
            'data': response.body
          };
        }
      } catch (e) {
        lastException = e as Exception;
        attempt++;

        if (attempt >= maxRetries) {
          log("Request failed after $maxRetries attempts: ${e.toString()}");
          return {
            'success': false,
            'statusCode': 0,
            'error': 'Network error: ${e.toString()}',
            'data': null
          };
        } else {
          log("Request failed, retrying... (attempt ${attempt + 1}/$maxRetries): ${e.toString()}");
          await Future.delayed(
              Duration(seconds: attempt)); // Exponential backoff
        }
      }
    }

    // This should never be reached, but just in case
    return {
      'success': false,
      'statusCode': 0,
      'error': 'Unknown error occurred',
      'data': null
    };
  }

  // Utility method to check if response is successful
  bool isSuccessResponse(Map<String, dynamic> response) {
    return response['success'] == true;
  }

  // Utility method to get error message from response
  String getErrorMessage(Map<String, dynamic> response) {
    return response['error'] ?? 'Unknown error';
  }

  // Utility method to get data from response
  dynamic getResponseData(Map<String, dynamic> response) {
    return response['data'];
  }
}
