import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_models.dart';
import '../services/purchase_api_bridge.dart';
import '../services/purchase_api_service.dart';

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
      final result = await _purchaseApi.getPurchases(
        status: state.selectedStatus != 'all' ? state.selectedStatus : null,
        supplierId:
            state.selectedSupplier != 'all' ? state.selectedSupplier : null,
        perPage: 20,
      );

      final purchases = (result['data'] as List<dynamic>?)
              ?.map((item) => Purchase.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(purchases: purchases);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load purchases: $e');
    }
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
