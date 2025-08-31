import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'api.dart';

class SellApi extends Api {
  //create a sell in api
  Future<Map<String, dynamic>> create(data) async {
    String url = this.baseUrl + this.apiUrl + "/sell";
    var token = await System().getToken();
    var response = await http.post(Uri.parse(url),
        headers: this.getHeader('$token'), body: data);
    var info = jsonDecode(response.body);
    var result;

    if (info[0]['payment_lines'] != null) {
      result = {
        'transaction_id': info[0]['id'],
        'payment_lines': info[0]['payment_lines'],
        'invoice_url': info[0]['invoice_url']
      };
    } else if (info[0]['is_quotation'] != null) {
      result = {
        'transaction_id': info[0]['id'],
        'invoice_url': info[0]['invoice_url']
      };
    } else {
      result = null;
    }
    return result;
  }

  //update a sell in api
  Future<Map<String, dynamic>> update(transactionId, data) async {
    String url = this.baseUrl + this.apiUrl + "/sell/$transactionId";
    var token = await System().getToken();
    var response = await http.put(Uri.parse(url),
        headers: this.getHeader('$token'), body: data);
    var sellResponse = jsonDecode(response.body);
    return {
      'payment_lines': sellResponse['payment_lines'],
      'invoice_url': sellResponse['invoice_url']
    };
  }

  //delete sell
  delete(transactionId) async {
    String url = this.baseUrl + this.apiUrl + "/sell/$transactionId";
    var token = await System().getToken();
    var response =
        await http.delete(Uri.parse(url), headers: this.getHeader('$token'));
    if (response.statusCode == 200) {
      var sellResponse = jsonDecode(response.body);
      return sellResponse;
    } else {
      return null;
    }
  }

  //get specified sell with deduplication
  Future<List<dynamic>> getSpecifiedSells(List transactionIds) async {
    try {
      String ids = transactionIds.join(",");
      String url = this.baseUrl + this.apiUrl + "/sell/$ids";
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        if (responseData != null && responseData['data'] != null) {
          List<dynamic> sales = responseData['data'];

          // Remove duplicates based on transaction ID
          Map<String, dynamic> uniqueSales = {};
          for (var sale in sales) {
            if (sale != null && sale['id'] != null) {
              String transactionId = sale['id'].toString();
              uniqueSales[transactionId] = sale;
            }
          }

          List<dynamic> deduplicatedSales = uniqueSales.values.toList();

          // Sync with local database - remove items not in API response
          var responseTransactionIds =
              deduplicatedSales.map((sale) => sale['id'].toString()).toList();

          for (String id in transactionIds) {
            if (!responseTransactionIds.contains(id)) {
              try {
                var localSell = await SellDatabase().getSellByTransactionId(id);
                if (localSell != null && localSell.isNotEmpty) {
                  await SellDatabase().deleteSell(localSell[0]['id']);
                }
              } catch (e) {
                log("Error syncing local database for transaction $id: ${e.toString()}");
              }
            }
          }

          log("Retrieved ${deduplicatedSales.length} unique sales from ${sales.length} total");
          return deduplicatedSales;
        } else {
          log("No sales data found in API response");
          return [];
        }
      } else {
        log("API Error fetching specified sales: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR in getSpecifiedSells: ${e.toString()}");
      return [];
    }
  }

  // Get all sales with comprehensive filtering and pagination
  Future<Map<String, dynamic>> getSales(
      {String? startDate,
      String? endDate,
      String? customerId,
      String? paymentStatus,
      String? shippingStatus,
      String? status,
      int? locationId,
      int? perPage = 50,
      int? page = 1,
      String? orderBy = 'transaction_date',
      String? orderDirection = 'desc'}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/sell';

      // Build query parameters
      Map<String, String> queryParams = {};
      if (startDate != null && startDate.isNotEmpty)
        queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty)
        queryParams['end_date'] = endDate;
      if (customerId != null && customerId.isNotEmpty)
        queryParams['contact_id'] = customerId;
      if (paymentStatus != null && paymentStatus.isNotEmpty)
        queryParams['payment_status'] = paymentStatus;
      if (shippingStatus != null && shippingStatus.isNotEmpty)
        queryParams['shipping_status'] = shippingStatus;
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
        var sales = jsonDecode(response.body);
        log("Sales API Response: ${response.body}");

        // Remove duplicates based on transaction ID
        List<dynamic> salesData = sales['data'] ?? [];
        Map<String, dynamic> uniqueSales = {};

        for (var sale in salesData) {
          if (sale != null && sale['id'] != null) {
            String transactionId = sale['id'].toString();
            uniqueSales[transactionId] = sale;
          }
        }

        List<dynamic> deduplicatedSales = uniqueSales.values.toList();
        log("Deduplicated ${salesData.length} sales to ${deduplicatedSales.length} unique items");

        return {
          'data': deduplicatedSales,
          'current_page': sales['current_page'] ?? 1,
          'last_page': sales['last_page'] ?? 1,
          'per_page': sales['per_page'] ?? perPage,
          'total': sales['total'] ?? 0,
          'links': sales['links'] ?? {}
        };
      } else {
        log("Sales API Error: ${response.statusCode} - ${response.body}");
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
      log("ERROR fetching sales: ${e.toString()}");
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

  // Get sales by date range
  Future<Map<String, dynamic>> getSalesByDateRange(
      String startDate, String endDate,
      {int? perPage = 50, int? page = 1}) async {
    return await getSales(
        startDate: startDate, endDate: endDate, perPage: perPage, page: page);
  }

  // Get sales by customer
  Future<Map<String, dynamic>> getSalesByCustomer(String customerId,
      {int? perPage = 50, int? page = 1}) async {
    return await getSales(customerId: customerId, perPage: perPage, page: page);
  }

  // Get sales by payment status
  Future<Map<String, dynamic>> getSalesByPaymentStatus(String paymentStatus,
      {int? perPage = 50, int? page = 1}) async {
    return await getSales(
        paymentStatus: paymentStatus, perPage: perPage, page: page);
  }

  // Get sales by shipping status
  Future<Map<String, dynamic>> getSalesByShippingStatus(String shippingStatus,
      {int? perPage = 50, int? page = 1}) async {
    return await getSales(
        shippingStatus: shippingStatus, perPage: perPage, page: page);
  }

  // Get recent sales (last 30 days)
  Future<Map<String, dynamic>> getRecentSales(
      {int? perPage = 20, int? page = 1}) async {
    DateTime now = DateTime.now();
    DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));
    String startDate = thirtyDaysAgo.toIso8601String().split('T')[0];
    String endDate = now.toIso8601String().split('T')[0];

    return await getSales(
        startDate: startDate, endDate: endDate, perPage: perPage, page: page);
  }

  // Get today's sales
  Future<Map<String, dynamic>> getTodaySales(
      {int? perPage = 50, int? page = 1}) async {
    DateTime now = DateTime.now();
    String today = now.toIso8601String().split('T')[0];

    return await getSales(
        startDate: today, endDate: today, perPage: perPage, page: page);
  }

  // Get sales summary
  Future<Map<String, dynamic>?> getSalesSummary(
      {String? startDate, String? endDate, int? locationId}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/sell-summary';

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
        log("Sales summary API Response: ${response.body}");
        return summary['data'] as Map<String, dynamic>?;
      } else {
        log("Sales summary API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching sales summary: ${e.toString()}");
      return null;
    }
  }

  // Update sell shipping status
  Future<Map<String, dynamic>?> updateShippingStatus(
      String transactionId, String status) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/update-shipping-status';
      var token = await System().getToken();

      Map<String, dynamic> data = {
        'transaction_id': transactionId,
        'shipping_status': status
      };

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(data));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Update shipping status API Response: ${response.body}");
        return result;
      } else {
        log("Update shipping status API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR updating shipping status: ${e.toString()}");
      return null;
    }
  }
}
