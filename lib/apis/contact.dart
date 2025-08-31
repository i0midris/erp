import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:pos_final/api_end_points.dart';

import '../models/contact_model.dart';
import '../models/system.dart';
import 'api.dart';

class CustomerApi extends Api {
  var customers;

  get() async {
    String? url = ApiEndPoints.getContact;
    var token = await System().getToken();
    do {
      try {
        var response =
            await http.get(Uri.parse(url!), headers: this.getHeader('$token'));
        url = jsonDecode(response.body)['links']['next'];
        jsonDecode(response.body)['data'].forEach((element) {
          Contact().insertContact(Contact().contactModel(element));
        });
      } catch (e) {
        return null;
      }
    } while (url != null);
  }

  Future<dynamic> add(Map customer) async {
    try {
      String url = ApiEndPoints.addContact;
      var body = json.encode(customer);
      var token = await System().getToken();
      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: body);
      var result = await jsonDecode(response.body);
      return result;
    } catch (e) {
      return null;
    }
  }

  // Get all contacts with filtering and pagination
  Future<Map<String, dynamic>> getContacts(
      {String? type = 'customer',
      String? searchTerm,
      int? perPage = 50,
      int? page = 1,
      String? orderBy = 'name',
      String? orderDirection = 'asc'}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/contact';

      // Build query parameters
      Map<String, String> queryParams = {};
      if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (searchTerm != null && searchTerm.isNotEmpty)
        queryParams['search'] = searchTerm;
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
        var contacts = jsonDecode(response.body);
        log("Contacts API Response: ${response.body}");

        return {
          'data': contacts['data'] ?? [],
          'current_page': contacts['current_page'] ?? 1,
          'last_page': contacts['last_page'] ?? 1,
          'per_page': contacts['per_page'] ?? perPage,
          'total': contacts['total'] ?? 0,
          'links': contacts['links'] ?? {}
        };
      } else {
        log("Contacts API Error: ${response.statusCode} - ${response.body}");
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
      log("ERROR fetching contacts: ${e.toString()}");
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

  // Get specific contact by ID
  Future<Map<String, dynamic>?> getContactById(String contactId) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/contact/$contactId';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var contact = jsonDecode(response.body);
        log("Contact details API Response: ${response.body}");

        if (contact != null && contact['data'] != null) {
          return contact['data'] as Map<String, dynamic>;
        } else {
          log("No contact data found for ID: $contactId");
          return null;
        }
      } else {
        log("Contact API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching contact by ID: ${e.toString()}");
      return null;
    }
  }

  // Update contact
  Future<Map<String, dynamic>?> updateContact(
      String contactId, Map<String, dynamic> contactData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/contact/$contactId';
      var token = await System().getToken();

      var response = await http.put(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(contactData));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Update contact API Response: ${response.body}");
        return result;
      } else {
        log("Update contact API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR updating contact: ${e.toString()}");
      return null;
    }
  }

  // Delete contact
  Future<bool> deleteContact(String contactId) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/contact/$contactId';
      var token = await System().getToken();

      var response =
          await http.delete(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("Contact deleted successfully: $contactId");
        return true;
      } else {
        log("Delete contact API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR deleting contact: ${e.toString()}");
      return false;
    }
  }

  // Get contact due information
  Future<Map<String, dynamic>?> getContactDue(String contactId) async {
    try {
      String url = '${ApiEndPoints.customerDue}$contactId';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var dueInfo = jsonDecode(response.body);
        log("Contact due API Response: ${response.body}");
        return dueInfo as Map<String, dynamic>?;
      } else {
        log("Contact due API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching contact due: ${e.toString()}");
      return null;
    }
  }

  // Process contact payment
  Future<Map<String, dynamic>?> processContactPayment(
      Map<String, dynamic> paymentData) async {
    try {
      String url = ApiEndPoints.addContactPayment;
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(paymentData));

      if (response.statusCode == 200 || response.statusCode == 201) {
        var result = jsonDecode(response.body);
        log("Contact payment API Response: ${response.body}");
        return result;
      } else {
        log("Contact payment API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR processing contact payment: ${e.toString()}");
      return null;
    }
  }

  // Search contacts
  Future<Map<String, dynamic>> searchContacts(String query,
      {String? type = 'customer', int? perPage = 20, int? page = 1}) async {
    return await getContacts(
        type: type, searchTerm: query, perPage: perPage, page: page);
  }

  // Get customers only
  Future<Map<String, dynamic>> getCustomers(
      {String? searchTerm, int? perPage = 50, int? page = 1}) async {
    return await getContacts(
        type: 'customer', searchTerm: searchTerm, perPage: perPage, page: page);
  }

  // Get suppliers only
  Future<Map<String, dynamic>> getSuppliers(
      {String? searchTerm, int? perPage = 50, int? page = 1}) async {
    return await getContacts(
        type: 'supplier', searchTerm: searchTerm, perPage: perPage, page: page);
  }

  // Get contact transaction history
  Future<List<dynamic>> getContactTransactions(String contactId,
      {String? startDate,
      String? endDate,
      int? perPage = 20,
      int? page = 1}) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/contact/$contactId/transactions';

      Map<String, String> queryParams = {};
      if (startDate != null && startDate.isNotEmpty)
        queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty)
        queryParams['end_date'] = endDate;
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (page != null) queryParams['page'] = page.toString();

      if (queryParams.isNotEmpty) {
        String queryString =
            queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url += '?$queryString';
      }

      var token = await System().getToken();
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var transactions = jsonDecode(response.body);
        log("Contact transactions API Response: ${response.body}");

        if (transactions != null && transactions['data'] != null) {
          return transactions['data'] as List<dynamic>;
        } else {
          return [];
        }
      } else {
        log("Contact transactions API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching contact transactions: ${e.toString()}");
      return [];
    }
  }
}
