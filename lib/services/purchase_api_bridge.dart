import '../models/purchase_models.dart';
import 'purchase_api_service.dart';

/// Temporary bridge to maintain compatibility during PurchaseApi migration
/// This allows gradual transition from legacy PurchaseApi to modern PurchaseApiService
class PurchaseApiBridge {
  final PurchaseApiService _modernApi;

  PurchaseApiBridge(this._modernApi);

  /// Get all purchases with legacy format compatibility
  Future<Map<String, dynamic>> getPurchases(
      {String? startDate,
      String? endDate,
      String? supplierId,
      String? status,
      String? paymentStatus,
      int? locationId,
      int? perPage = 50,
      int? page = 1,
      String? orderBy = 'transaction_date',
      String? orderDirection = 'desc'}) async {
    try {
      final response = await _modernApi.getPurchases(
        supplierId: supplierId != null && supplierId.isNotEmpty
            ? int.tryParse(supplierId)
            : null,
        locationId: locationId,
        status: status,
        paymentStatus: paymentStatus,
        startDate: startDate != null ? DateTime.parse(startDate) : null,
        endDate: endDate != null ? DateTime.parse(endDate) : null,
        perPage: perPage,
        page: page,
      );

      // Convert modern response to legacy format
      return {
        'data':
            response.purchases.map((purchase) => purchase.toJson()).toList(),
        'current_page': response.currentPage,
        'last_page': response.lastPage,
        'per_page': response.perPage,
        'total': response.total,
        'links': {}, // Legacy format compatibility
      };
    } catch (e) {
      // Return empty result in legacy format on error
      return {
        'data': [],
        'current_page': 1,
        'last_page': 1,
        'per_page': perPage ?? 50,
        'total': 0,
        'links': {},
      };
    }
  }

  /// Get specific purchase by ID
  Future<Map<String, dynamic>?> getPurchaseById(String purchaseId) async {
    try {
      final purchase = await _modernApi.getPurchase(int.parse(purchaseId));
      return purchase.toJson();
    } catch (e) {
      return null;
    }
  }

  /// Create new purchase order
  Future<Map<String, dynamic>?> createPurchase(
      Map<String, dynamic> purchaseData) async {
    try {
      print("PurchaseApiBridge: Starting createPurchase");
      print("PurchaseApiBridge: Purchase data: $purchaseData");

      // Convert legacy format to modern format
      final purchase = Purchase.fromJson(purchaseData);
      final request = CreatePurchaseRequest(purchase: purchase);

      print(
          "PurchaseApiBridge: Converted to Purchase model, calling modern API");

      final createdPurchase = await _modernApi.createPurchase(request);

      print(
          "PurchaseApiBridge: Modern API returned: ${createdPurchase.toJson()}");

      return createdPurchase.toJson();
    } catch (e) {
      print("PurchaseApiBridge: Exception occurred: $e");
      print("PurchaseApiBridge: Exception type: ${e.runtimeType}");
      return null;
    }
  }

  /// Update purchase order
  Future<Map<String, dynamic>?> updatePurchase(
      String purchaseId, Map<String, dynamic> purchaseData) async {
    try {
      final purchase = Purchase.fromJson(purchaseData);
      final request = UpdatePurchaseRequest(
        purchaseId: int.parse(purchaseId),
        purchase: purchase,
      );

      final updatedPurchase = await _modernApi.updatePurchase(request);
      return updatedPurchase.toJson();
    } catch (e) {
      return null;
    }
  }

  /// Delete purchase order
  Future<bool> deletePurchase(String purchaseId) async {
    try {
      await _modernApi.deletePurchase(int.parse(purchaseId));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update purchase status
  Future<Map<String, dynamic>?> updatePurchaseStatus(
      String purchaseId, String status) async {
    try {
      await _modernApi.updatePurchaseStatus(int.parse(purchaseId), status);
      return {'success': true, 'message': 'Status updated successfully'};
    } catch (e) {
      return null;
    }
  }

  /// Get suppliers for purchase orders
  Future<Map<String, dynamic>> getSuppliers({String? term}) async {
    try {
      final suppliers = await _modernApi.getSuppliers(searchTerm: term);
      return {
        'data': suppliers.map((supplier) => supplier.toJson()).toList(),
      };
    } catch (e) {
      return {'data': []};
    }
  }

  /// Get products available for purchase
  Future<Map<String, dynamic>> getPurchaseProducts({String? term}) async {
    try {
      final products = await _modernApi.getProducts(searchTerm: term);
      return {
        'data': products.map((product) => product.toJson()).toList(),
      };
    } catch (e) {
      return {'data': []};
    }
  }

  /// Get purchase summary
  Future<Map<String, dynamic>?> getPurchaseSummary(
      {String? startDate, String? endDate, int? locationId}) async {
    // This method doesn't exist in modern API, return empty for compatibility
    return {
      'total_purchases': 0,
      'pending_orders': 0,
      'total_amount': '0.00',
      'active_suppliers': 0,
    };
  }

  /// Get recent purchases (last 30 days)
  Future<Map<String, dynamic>> getRecentPurchases(
      {int? perPage = 20, int? page = 1}) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return await getPurchases(
      startDate: thirtyDaysAgo.toIso8601String().split('T')[0],
      endDate: DateTime.now().toIso8601String().split('T')[0],
      perPage: perPage,
      page: page,
    );
  }

  /// Get today's purchases
  Future<Map<String, dynamic>> getTodayPurchases(
      {int? perPage = 50, int? page = 1}) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await getPurchases(
      startDate: today,
      endDate: today,
      perPage: perPage,
      page: page,
    );
  }

  /// Get purchases by supplier
  Future<Map<String, dynamic>> getPurchasesBySupplier(String supplierId,
      {int? perPage = 50, int? page = 1}) async {
    return await getPurchases(
      supplierId: supplierId,
      perPage: perPage,
      page: page,
    );
  }

  /// Get purchases by status
  Future<Map<String, dynamic>> getPurchasesByStatus(String status,
      {int? perPage = 50, int? page = 1}) async {
    return await getPurchases(
      status: status,
      perPage: perPage,
      page: page,
    );
  }

  /// Get purchases by payment status
  Future<Map<String, dynamic>> getPurchasesByPaymentStatus(String paymentStatus,
      {int? perPage = 50, int? page = 1}) async {
    return await getPurchases(
      paymentStatus: paymentStatus,
      perPage: perPage,
      page: page,
    );
  }

  /// Validate reference number
  Future<Map<String, dynamic>?> validateReferenceNumber(
      String refNumber) async {
    // This method doesn't exist in modern API, return null for compatibility
    return null;
  }
}
