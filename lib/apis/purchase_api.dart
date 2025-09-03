import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../models/purchaseDatabase.dart';
import '../models/system.dart';
import 'api.dart';

class PurchaseApi extends Api {
  // Create a purchase in API
  Future<Map<String, dynamic>?> create(data) async {
    try {
      String url = this.baseUrl + this.apiUrl + "/purchase";
      var token = await System().getToken();

      log("Purchase API: Making request to $url");
      log("Purchase API: Request data: $data");

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: data);

      log("Purchase API: Response status: ${response.statusCode}");
      log("Purchase API: Response body: ${response.body}");

      // Handle both 200 (OK) and 201 (Created) status codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body == null || response.body.isEmpty) {
          log("Purchase API: Response body is empty");
          return null;
        }

        var info;
        try {
          info = jsonDecode(response.body);
          log("Purchase API: Parsed JSON: $info");
        } catch (jsonError) {
          log("Purchase API: JSON decode error: $jsonError");
          return null;
        }

        if (info != null) {
          // Handle Laravel API response format with nested data
          var transactionId;
          var paymentLines = [];

          // Check if data is nested in 'data' key (Laravel API format)
          if (info['data'] != null && info['data'] is Map) {
            var data = info['data'];
            transactionId = data['id'] ?? data['transaction_id'];
            paymentLines = data['payment_lines'] ?? data['payments'] ?? [];
            log("Purchase API: Found nested data format, transactionId: $transactionId");
          } else {
            // Direct access for other API formats
            transactionId = info['id'] ?? info['transaction_id'];
            paymentLines = info['payment_lines'] ?? info['payments'] ?? [];
            log("Purchase API: Found direct format, transactionId: $transactionId");
          }

          if (transactionId != null) {
            log("Purchase API: Returning success with transaction_id: $transactionId");
            return {
              'transaction_id': transactionId,
              'payment_lines': paymentLines,
            };
          } else {
            log("Purchase API: No transaction_id found in response");
          }
        } else {
          log("Purchase API: Parsed info is null");
        }
      } else {
        log("Purchase API: Unexpected status code: ${response.statusCode}");
      }

      // Log error details for debugging
      log("Purchase API Error - Status: ${response.statusCode}, Response: ${response.body}");
      return null;
    } catch (e) {
      log("Purchase API: Exception occurred: $e");
      return null;
    }
  }

  // Update a purchase in API
  Future<Map<String, dynamic>?> update(transactionId, data) async {
    String url = this.baseUrl + this.apiUrl + "/purchase/$transactionId";
    var token = await System().getToken();
    var response = await http.put(Uri.parse(url),
        headers: this.getHeader('$token'), body: data);
    var purchaseResponse = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'payment_lines': purchaseResponse['payment_lines'] ?? [],
      };
    } else {
      return null;
    }
  }

  // Delete purchase
  Future<Map<String, dynamic>?> delete(transactionId) async {
    String url = this.baseUrl + this.apiUrl + "/purchase/$transactionId";
    var token = await System().getToken();
    var response =
        await http.delete(Uri.parse(url), headers: this.getHeader('$token'));
    if (response.statusCode == 200) {
      var purchaseResponse = jsonDecode(response.body);
      return purchaseResponse;
    } else {
      return null;
    }
  }

  // Get specified purchases with deduplication
  Future<List<dynamic>> getSpecifiedPurchases(List transactionIds) async {
    try {
      String ids = transactionIds.join(",");
      String url = this.baseUrl + this.apiUrl + "/purchase/$ids";
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        if (responseData != null && responseData['data'] != null) {
          List<dynamic> purchases = responseData['data'];

          // Remove duplicates based on transaction ID
          Map<String, dynamic> uniquePurchases = {};
          for (var purchase in purchases) {
            if (purchase != null && purchase['id'] != null) {
              String transactionId = purchase['id'].toString();
              uniquePurchases[transactionId] = purchase;
            }
          }

          List<dynamic> deduplicatedPurchases = uniquePurchases.values.toList();

          // Sync with local database - remove items not in API response
          var responseTransactionIds = deduplicatedPurchases
              .map((purchase) => purchase['id'].toString())
              .toList();

          for (String id in transactionIds) {
            if (!responseTransactionIds.contains(id)) {
              try {
                var localPurchase =
                    await PurchaseDatabase().getPurchaseByTransactionId(id);
                if (localPurchase != null && localPurchase.isNotEmpty) {
                  await PurchaseDatabase()
                      .deletePurchase(localPurchase[0]['id']);
                }
              } catch (e) {
                log("Error syncing local database for transaction $id: ${e.toString()}");
              }
            }
          }

          log("Retrieved ${deduplicatedPurchases.length} unique purchases from ${purchases.length} total");
          return deduplicatedPurchases;
        } else {
          log("No purchases data found in API response");
          return [];
        }
      } else {
        log("API Error fetching specified purchases: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR in getSpecifiedPurchases: ${e.toString()}");
      return [];
    }
  }

  // Get all purchases with comprehensive filtering and pagination
  Future<Map<String, dynamic>> getPurchases(
      {String? startDate,
      String? endDate,
      String? supplierId,
      String? status,
      int? locationId,
      int? perPage = 50,
      int? page = 1,
      String? orderBy = 'transaction_date',
      String? orderDirection = 'desc'}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/purchase';

      // Build query parameters
      Map<String, String> queryParams = {};
      if (startDate != null && startDate.isNotEmpty)
        queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty)
        queryParams['end_date'] = endDate;
      if (supplierId != null && supplierId.isNotEmpty)
        queryParams['contact_id'] = supplierId;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (locationId != null)
        queryParams['location_id'] = locationId.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (page != null) queryParams['page'] = page.toString();
      if (orderBy != null) queryParams['order_by'] = orderBy;
      if (orderDirection != null)
        queryParams['order_direction'] = orderDirection;

      if (queryParams.isNotEmpty) {
        String queryString =
            queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url += '?$queryString';
      }

      var token = await System().getToken();
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var purchases = jsonDecode(response.body);
        log("Purchases API Response: ${response.body}");

        // Remove duplicates based on transaction ID
        List<dynamic> purchasesData = purchases['data'] ?? [];
        Map<String, dynamic> uniquePurchases = {};

        for (var purchase in purchasesData) {
          if (purchase != null && purchase['id'] != null) {
            String transactionId = purchase['id'].toString();
            uniquePurchases[transactionId] = purchase;
          }
        }

        List<dynamic> deduplicatedPurchases = uniquePurchases.values.toList();
        log("Deduplicated ${purchasesData.length} purchases to ${deduplicatedPurchases.length} unique items");

        return {
          'data': deduplicatedPurchases,
          'current_page': purchases['current_page'] ?? 1,
          'last_page': purchases['last_page'] ?? 1,
          'per_page': purchases['per_page'] ?? perPage,
          'total': purchases['total'] ?? 0,
          'links': purchases['links'] ?? {}
        };
      } else {
        log("Purchases API Error: ${response.statusCode} - ${response.body}");
        return {
          'data': [],
          'current_page': 1,
          'last_page': 1,
          'per_page': perPage ?? 50,
          'total': 0,
          'links': {}
        };
      }
    } catch (e) {
      log("ERROR fetching purchases: ${e.toString()}");
      return {
        'data': [],
        'current_page': 1,
        'last_page': 1,
        'per_page': 50,
        'total': 0,
        'links': {}
      };
    }
  }

  // Get purchases by date range
  Future<Map<String, dynamic>> getPurchasesByDateRange(
      String startDate, String endDate,
      {int? perPage = 50, int? page = 1}) async {
    return await getPurchases(
        startDate: startDate, endDate: endDate, perPage: perPage, page: page);
  }

  // Get purchases by supplier
  Future<Map<String, dynamic>> getPurchasesBySupplier(String supplierId,
      {int? perPage = 50, int? page = 1}) async {
    return await getPurchases(
        supplierId: supplierId, perPage: perPage, page: page);
  }

  // Get purchases by status
  Future<Map<String, dynamic>> getPurchasesByStatus(String status,
      {int? perPage = 50, int? page = 1}) async {
    return await getPurchases(status: status, perPage: perPage, page: page);
  }

  // Get recent purchases (last 30 days)
  Future<Map<String, dynamic>> getRecentPurchases(
      {int? perPage = 20, int? page = 1}) async {
    DateTime now = DateTime.now();
    DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));
    String startDate = thirtyDaysAgo.toIso8601String().split('T')[0];
    String endDate = now.toIso8601String().split('T')[0];

    return await getPurchases(
        startDate: startDate, endDate: endDate, perPage: perPage, page: page);
  }

  // Get today's purchases
  Future<Map<String, dynamic>> getTodayPurchases(
      {int? perPage = 50, int? page = 1}) async {
    DateTime now = DateTime.now();
    String today = now.toIso8601String().split('T')[0];

    return await getPurchases(
        startDate: today, endDate: today, perPage: perPage, page: page);
  }

  // Get purchases summary
  Future<Map<String, dynamic>?> getPurchasesSummary(
      {String? startDate, String? endDate, int? locationId}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/purchase-summary';

      Map<String, String> queryParams = {};
      if (startDate != null && startDate.isNotEmpty)
        queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty)
        queryParams['end_date'] = endDate;
      if (locationId != null)
        queryParams['location_id'] = locationId.toString();

      if (queryParams.isNotEmpty) {
        String queryString =
            queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url += '?$queryString';
      }

      var token = await System().getToken();
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var summary = jsonDecode(response.body);
        log("Purchases summary API Response: ${response.body}");
        return summary['data'] as Map<String, dynamic>?;
      } else {
        log("Purchases summary API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching purchases summary: ${e.toString()}");
      return null;
    }
  }
}
