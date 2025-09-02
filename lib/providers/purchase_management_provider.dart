import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_models.dart';
import '../models/purchaseDatabase.dart';
import '../services/purchase_api_bridge.dart';
import '../services/purchase_api_service.dart';
import '../helpers/otherHelpers.dart';

/// State class for purchase management
class PurchaseManagementState {
  final bool isLoading;
  final bool isRefreshing;
  final List<Purchase> purchases;
  final List<Supplier> suppliers;
  final List<PurchaseProduct> products;
  final Map<String, dynamic> summary;
  final String selectedStatus;
  final String selectedSupplier;
  final String searchQuery;
  final String? errorMessage;

  const PurchaseManagementState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.purchases = const [],
    this.suppliers = const [],
    this.products = const [],
    this.summary = const {},
    this.selectedStatus = 'all',
    this.selectedSupplier = 'all',
    this.searchQuery = '',
    this.errorMessage,
  });

  PurchaseManagementState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    List<Purchase>? purchases,
    List<Supplier>? suppliers,
    List<PurchaseProduct>? products,
    Map<String, dynamic>? summary,
    String? selectedStatus,
    String? selectedSupplier,
    String? searchQuery,
    String? errorMessage,
  }) {
    return PurchaseManagementState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      purchases: purchases ?? this.purchases,
      suppliers: suppliers ?? this.suppliers,
      products: products ?? this.products,
      summary: summary ?? this.summary,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedSupplier: selectedSupplier ?? this.selectedSupplier,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  // Computed properties for filtered data
  List<Purchase> get filteredPurchases {
    List<Purchase> filtered = purchases;

    // Filter by status
    if (selectedStatus != 'all') {
      filtered = filtered
          .where((purchase) => purchase.status == selectedStatus)
          .toList();
    }

    // Filter by supplier
    if (selectedSupplier != 'all') {
      filtered = filtered
          .where(
              (purchase) => purchase.contactId.toString() == selectedSupplier)
          .toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((purchase) {
        final refNo = purchase.refNo?.toLowerCase() ?? '';
        final supplier = suppliers.firstWhere(
          (s) => s.id == purchase.contactId,
          orElse: () => const Supplier(id: 0, name: ''),
        );
        final supplierName = supplier.name.toLowerCase();
        return refNo.contains(query) || supplierName.contains(query);
      }).toList();
    }

    return filtered;
  }
}

/// Notifier class for purchase management
class PurchaseManagementNotifier
    extends StateNotifier<PurchaseManagementState> {
  final PurchaseApiService _apiService;
  late final PurchaseApiBridge _purchaseApi;

  PurchaseManagementNotifier(this._apiService)
      : super(const PurchaseManagementState()) {
    _purchaseApi = PurchaseApiBridge(_apiService);
    loadInitialData();
  }

  /// Load all initial data
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Future.wait([
        loadPurchases(),
        loadSuppliers(),
        loadProducts(),
        loadSummary(),
      ]);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load purchases with current filters
  Future<void> loadPurchases() async {
    try {
      // First, load from local database
      List<Purchase> localPurchases = [];
      try {
        final dbPurchases = await PurchaseDatabase().getPurchases();
        localPurchases = dbPurchases.map((dbPurchase) {
          // Convert database format to Purchase model
          return Purchase(
            id: dbPurchase['id'],
            businessId: 1, // Default business ID
            contactId: dbPurchase['contact_id'],
            locationId: dbPurchase['location_id'],
            refNo: dbPurchase['ref_no'],
            status: dbPurchase['status'],
            transactionDate: DateTime.parse(dbPurchase['transaction_date']),
            totalBeforeTax: dbPurchase['total_before_tax']?.toDouble() ?? 0.0,
            discountType: dbPurchase['discount_type'],
            discountAmount: dbPurchase['discount_amount']?.toDouble(),
            taxId: dbPurchase['tax_id'],
            taxAmount: dbPurchase['tax_amount']?.toDouble(),
            shippingCharges: dbPurchase['shipping_charges']?.toDouble(),
            shippingDetails: dbPurchase['shipping_details'],
            finalTotal: dbPurchase['final_total']?.toDouble() ?? 0.0,
            additionalNotes: dbPurchase['additional_notes'],
            purchaseLines: [], // Will be loaded separately if needed
          );
        }).toList();
      } catch (dbError) {
        print('Failed to load purchases from database: $dbError');
      }

      // Try to load from API if connected
      try {
        if (await Helper().checkConnectivity()) {
          final result = await _purchaseApi.getPurchases(
            status: state.selectedStatus != 'all' ? state.selectedStatus : null,
            supplierId:
                state.selectedSupplier != 'all' ? state.selectedSupplier : null,
            perPage: 20,
          );

          final apiPurchases = (result['data'] as List<dynamic>?)
                  ?.map(
                      (item) => Purchase.fromJson(item as Map<String, dynamic>))
                  .toList() ??
              [];

          // Merge local and API purchases, preferring API data for synced items
          final mergedPurchases = _mergePurchases(localPurchases, apiPurchases);
          state = state.copyWith(purchases: mergedPurchases);
        } else {
          // Offline mode - use only local data
          state = state.copyWith(purchases: localPurchases);
        }
      } catch (apiError) {
        print('Failed to load purchases from API: $apiError');
        // Use local data if API fails
        state = state.copyWith(purchases: localPurchases);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load purchases: $e');
    }
  }

  /// Merge local and API purchases
  List<Purchase> _mergePurchases(
      List<Purchase> localPurchases, List<Purchase> apiPurchases) {
    final merged = <Purchase>[];

    // Add all API purchases
    merged.addAll(apiPurchases);

    // Add local purchases that are not synced (don't exist in API)
    for (final localPurchase in localPurchases) {
      final existsInApi = apiPurchases.any((apiPurchase) =>
          apiPurchase.id == localPurchase.id ||
          (apiPurchase.refNo == localPurchase.refNo &&
              apiPurchase.refNo != null));

      if (!existsInApi) {
        merged.add(localPurchase);
      }
    }

    return merged;
  }

  /// Load suppliers
  Future<void> loadSuppliers() async {
    try {
      final result = await _purchaseApi.getSuppliers();
      final suppliers = (result['data'] as List<dynamic>?)
              ?.map((item) => Supplier.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(suppliers: suppliers);
    } catch (e) {
      // Don't set error for suppliers, just log it
      print('Failed to load suppliers: $e');
    }
  }

  /// Load products
  Future<void> loadProducts() async {
    try {
      final result = await _purchaseApi.getPurchaseProducts();
      final products = (result['data'] as List<dynamic>?)
              ?.map((item) =>
                  PurchaseProduct.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(products: products);
    } catch (e) {
      // Don't set error for products, just log it
      print('Failed to load products: $e');
    }
  }

  /// Load purchase summary
  Future<void> loadSummary() async {
    try {
      final summary = await _purchaseApi.getPurchaseSummary();
      if (summary != null) {
        state = state.copyWith(summary: summary);
      }
    } catch (e) {
      // Don't set error for summary, just log it
      print('Failed to load purchase summary: $e');
    }
  }

  /// Refresh all data
  Future<void> refreshData() async {
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    await loadInitialData();
    state = state.copyWith(isRefreshing: false);
  }

  /// Update filters and reload data
  void updateFilters({
    String? status,
    String? supplier,
    String? searchQuery,
  }) {
    state = state.copyWith(
      selectedStatus: status ?? state.selectedStatus,
      selectedSupplier: supplier ?? state.selectedSupplier,
      searchQuery: searchQuery ?? state.searchQuery,
    );
    loadPurchases();
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      selectedStatus: 'all',
      selectedSupplier: 'all',
      searchQuery: '',
    );
    loadPurchases();
  }

  /// Get purchase by ID
  Future<Purchase?> getPurchaseById(int purchaseId) async {
    try {
      final result = await _purchaseApi.getPurchaseById(purchaseId.toString());
      if (result != null) {
        return Purchase.fromJson(result);
      }
      return null;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load purchase: $e');
      return null;
    }
  }

  /// Delete purchase
  Future<bool> deletePurchase(int purchaseId) async {
    try {
      final success = await _purchaseApi.deletePurchase(purchaseId.toString());
      if (success) {
        // Remove from local state
        final updatedPurchases = state.purchases
            .where((purchase) => purchase.id != purchaseId)
            .toList();
        state = state.copyWith(purchases: updatedPurchases);
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete purchase: $e');
      return false;
    }
  }

  /// Update purchase status
  Future<bool> updatePurchaseStatus(int purchaseId, String status) async {
    try {
      final result = await _purchaseApi.updatePurchaseStatus(
          purchaseId.toString(), status);
      if (result != null && result['success'] == true) {
        // Update local state
        final updatedPurchases = state.purchases.map((purchase) {
          if (purchase.id == purchaseId) {
            return purchase.copyWith(status: status);
          }
          return purchase;
        }).toList();
        state = state.copyWith(purchases: updatedPurchases);
        return true;
      }
      return false;
    } catch (e) {
      state =
          state.copyWith(errorMessage: 'Failed to update purchase status: $e');
      return false;
    }
  }

  /// Sync purchases with server
  Future<bool> syncPurchases() async {
    try {
      if (await Helper().checkConnectivity()) {
        // Get unsynced purchases from database
        final unsyncedPurchases =
            await PurchaseDatabase().getNotSyncedPurchases();

        for (final dbPurchase in unsyncedPurchases) {
          try {
            // Load purchase lines for this purchase
            final purchaseLines =
                await PurchaseDatabase().getPurchaseLines(dbPurchase['id']);

            // Create API request from database data
            final purchaseData = {
              'business_id': 1, // Default business ID
              'contact_id': dbPurchase['contact_id'],
              'location_id': dbPurchase['location_id'],
              'ref_no': dbPurchase['ref_no'],
              'status': dbPurchase['status'],
              'transaction_date': dbPurchase['transaction_date'],
              'total_before_tax': dbPurchase['total_before_tax'],
              'discount_type': dbPurchase['discount_type'],
              'discount_amount': dbPurchase['discount_amount'],
              'tax_id': dbPurchase['tax_id'],
              'tax_amount': dbPurchase['tax_amount'],
              'shipping_charges': dbPurchase['shipping_charges'],
              'shipping_details': dbPurchase['shipping_details'],
              'final_total': dbPurchase['final_total'],
              'additional_notes': dbPurchase['additional_notes'],
              'purchases': purchaseLines
                  .map((line) => {
                        'product_id': line['product_id'],
                        'variation_id': line['variation_id'],
                        'quantity': line['quantity'],
                        'unit_price': line['unit_price'],
                        'line_discount_amount': line['line_discount_amount'],
                        'line_discount_type': line['line_discount_type'],
                        'item_tax_id': line['item_tax_id'],
                        'item_tax': line['item_tax'],
                        'sub_unit_id': line['sub_unit_id'],
                        'lot_number': line['lot_number'],
                        'mfg_date': line['mfg_date'],
                        'exp_date': line['exp_date'],
                        'purchase_order_line_id':
                            line['purchase_order_line_id'],
                        'purchase_requisition_line_id':
                            line['purchase_requisition_line_id'],
                      })
                  .toList(),
            };

            final result = await _purchaseApi.createPurchase(purchaseData);
            if (result != null && result['transaction_id'] != null) {
              // Update database with sync status
              await PurchaseDatabase().updatePurchase(dbPurchase['id'], {
                'is_synced': 1,
                'transaction_id': result['transaction_id'],
              });
            }
          } catch (syncError) {
            print('Failed to sync purchase ${dbPurchase['id']}: $syncError');
            // Continue with next purchase instead of failing completely
          }
        }

        // Reload purchases after sync
        await loadPurchases();
        return true;
      } else {
        state = state.copyWith(errorMessage: 'No internet connection for sync');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to sync purchases: $e');
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for purchase management
final purchaseManagementProvider =
    StateNotifierProvider<PurchaseManagementNotifier, PurchaseManagementState>(
  (ref) => PurchaseManagementNotifier(ref.watch(purchaseApiServiceProvider)),
);

/// Provider for individual purchase details
final purchaseDetailsProvider = FutureProvider.family<Purchase?, int>(
  (ref, purchaseId) async {
    final notifier = ref.watch(purchaseManagementProvider.notifier);
    return await notifier.getPurchaseById(purchaseId);
  },
);
