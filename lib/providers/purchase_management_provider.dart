import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_models.dart';
import '../models/purchaseDatabase.dart';
import '../models/system.dart';
import '../services/purchase_api_bridge.dart';
import '../services/purchase_api_service.dart';
import '../services/purchase_cache_service.dart';
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
  final PurchaseCacheService _cacheService;
  late final PurchaseApiBridge _purchaseApi;

  PurchaseManagementNotifier(this._apiService, this._cacheService)
      : super(const PurchaseManagementState()) {
    _purchaseApi = PurchaseApiBridge(_apiService);
    loadInitialData();
  }

  /// Load all initial data
  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Refresh cache if needed
      await refreshCacheIfNeeded();

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
      // Try to load from cache first
      final cachedSuppliers = await _cacheService.getCachedSuppliers();
      if (cachedSuppliers.isNotEmpty) {
        final suppliers = cachedSuppliers
            .map((supplier) => Supplier.fromJson(supplier))
            .toList();
        state = state.copyWith(suppliers: suppliers);

        // Try to refresh from API in background if online
        if (await Helper().checkConnectivity()) {
          try {
            final result = await _purchaseApi.getSuppliers();
            final freshSuppliers = (result['data'] as List<dynamic>?)
                    ?.map((item) =>
                        Supplier.fromJson(item as Map<String, dynamic>))
                    .toList() ??
                [];
            await _cacheService.cacheSuppliers(freshSuppliers);
            state = state.copyWith(suppliers: freshSuppliers);
          } catch (e) {
            // Keep cached data if API fails
            print('Failed to refresh suppliers from API: $e');
          }
        }
      } else {
        // No cached data, try to load from API
        final result = await _purchaseApi.getSuppliers();
        final suppliers = (result['data'] as List<dynamic>?)
                ?.map((item) => Supplier.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];
        await _cacheService.cacheSuppliers(suppliers);
        state = state.copyWith(suppliers: suppliers);
      }
    } catch (e) {
      // If both cache and API fail, try to load from cache as fallback
      try {
        final cachedSuppliers = await _cacheService.getCachedSuppliers();
        if (cachedSuppliers.isNotEmpty) {
          final suppliers = cachedSuppliers
              .map((supplier) => Supplier.fromJson(supplier))
              .toList();
          state = state.copyWith(
            suppliers: suppliers,
            errorMessage: 'Using cached data (offline mode)',
          );
        } else {
          print('Failed to load suppliers: $e');
        }
      } catch (cacheError) {
        print('Failed to load suppliers: $e');
      }
    }
  }

  /// Load products
  Future<void> loadProducts() async {
    try {
      // Try to load from cache first
      final cachedProducts = await _cacheService.getCachedProducts();
      if (cachedProducts.isNotEmpty) {
        final products = cachedProducts
            .map((product) => PurchaseProduct.fromJson(product))
            .toList();
        state = state.copyWith(products: products);

        // Try to refresh from API in background if online
        if (await Helper().checkConnectivity()) {
          try {
            final result = await _purchaseApi.getPurchaseProducts();
            final freshProducts = (result['data'] as List<dynamic>?)
                    ?.map((item) =>
                        PurchaseProduct.fromJson(item as Map<String, dynamic>))
                    .toList() ??
                [];
            await _cacheService.cacheProducts(freshProducts);
            state = state.copyWith(products: freshProducts);
          } catch (e) {
            // Keep cached data if API fails
            print('Failed to refresh products from API: $e');
          }
        }
      } else {
        // No cached data, try to load from API
        final result = await _purchaseApi.getPurchaseProducts();
        final products = (result['data'] as List<dynamic>?)
                ?.map((item) =>
                    PurchaseProduct.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];
        await _cacheService.cacheProducts(products);
        state = state.copyWith(products: products);
      }
    } catch (e) {
      // If both cache and API fail, try to load from cache as fallback
      try {
        final cachedProducts = await _cacheService.getCachedProducts();
        if (cachedProducts.isNotEmpty) {
          final products = cachedProducts
              .map((product) => PurchaseProduct.fromJson(product))
              .toList();
          state = state.copyWith(
            products: products,
            errorMessage: 'Using cached data (offline mode)',
          );
        } else {
          print('Failed to load products: $e');
        }
      } catch (cacheError) {
        print('Failed to load products: $e');
      }
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
    print('🔄 SYNC: Starting purchase synchronization process...');

    try {
      // Check internet connectivity
      final hasConnectivity = await Helper().checkConnectivity();
      print('📡 SYNC: Internet connectivity check: $hasConnectivity');

      if (!hasConnectivity) {
        print('📴 SYNC: No internet connection - cannot sync');
        state = state.copyWith(errorMessage: 'No internet connection for sync');
        return false;
      }

      // Check authentication before syncing
      print('🔐 SYNC: Checking authentication status...');
      final system = System();
      final isAuthenticated = await system.isAuthenticated();
      print('🔐 SYNC: Authentication status: $isAuthenticated');

      if (!isAuthenticated) {
        print('❌ SYNC: User not authenticated - cannot sync');
        state = state.copyWith(errorMessage: 'Please login to sync purchases');
        return false;
      }

      // Refresh cache before syncing
      print('🔄 SYNC: Refreshing cache before sync...');
      await _cacheService.refreshCacheIfNeeded();
      print('✅ SYNC: Cache refresh completed');

      // Get unsynced purchases from database
      print('📦 SYNC: Fetching unsynced purchases from database...');
      final unsyncedPurchases =
          await PurchaseDatabase().getNotSyncedPurchases();
      print('📦 SYNC: Found ${unsyncedPurchases.length} unsynced purchases');

      if (unsyncedPurchases.isEmpty) {
        print('ℹ️ SYNC: No unsynced purchases found - sync complete');
        return true;
      }

      int syncedCount = 0;
      int failedCount = 0;

      for (int i = 0; i < unsyncedPurchases.length; i++) {
        final dbPurchase = unsyncedPurchases[i];
        final purchaseId = dbPurchase['id'];
        final refNo = dbPurchase['ref_no'] ?? 'No Ref';

        print(
            '🔄 SYNC: Processing purchase ${i + 1}/${unsyncedPurchases.length} (ID: $purchaseId, Ref: $refNo)');

        try {
          // Load purchase lines for this purchase
          print('📋 SYNC: Loading purchase lines for purchase $purchaseId...');
          final purchaseLines =
              await PurchaseDatabase().getPurchaseLines(purchaseId);
          print(
              '📋 SYNC: Found ${purchaseLines.length} purchase lines for purchase $purchaseId');

          if (purchaseLines.isEmpty) {
            print(
                '⚠️ SYNC: No purchase lines found for purchase $purchaseId - skipping');
            failedCount++;
            continue;
          }

          // Create API request from database data
          print(
              '📝 SYNC: Preparing API request data for purchase $purchaseId...');
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
                      'purchase_order_line_id': line['purchase_order_line_id'],
                      'purchase_requisition_line_id':
                          line['purchase_requisition_line_id'],
                    })
                .toList(),
          };

          print('🌐 SYNC: Sending purchase $purchaseId to API...');
          print(
              '📊 SYNC: Purchase data summary - Contact: ${purchaseData['contact_id']}, Total: ${purchaseData['final_total']}, Lines: ${purchaseLines.length}');

          final result = await _purchaseApi.createPurchase(purchaseData);
          print('📡 SYNC: HTTP request completed for purchase $purchaseId');

          // Log the full API response for debugging
          print('📥 SYNC: API Response for purchase $purchaseId: $result');

          if (result != null) {
            print('🔍 SYNC: Checking API response structure...');
            print('   • Result type: ${result.runtimeType}');
            print(
                '   • Has transaction_id: ${result.containsKey('transaction_id')}');
            print('   • Has id: ${result.containsKey('id')}');
            print('   • Has success: ${result.containsKey('success')}');
            print('   • Has data: ${result.containsKey('data')}');

            // Log all keys in the response
            if (result is Map) {
              print('   • All keys: ${result.keys.toList()}');
              result.forEach((key, value) {
                print('   • $key: $value (${value.runtimeType})');
              });
            }

            // Check for transaction_id first (Laravel API standard)
            if (result['transaction_id'] != null) {
              print(
                  '✅ SYNC: Successfully synced purchase $purchaseId - Server ID: ${result['transaction_id']}');

              // Update database with sync status
              print(
                  '💾 SYNC: Updating local database for purchase $purchaseId...');
              await PurchaseDatabase().updatePurchase(purchaseId, {
                'is_synced': 1,
                'transaction_id': result['transaction_id'],
              });
              syncedCount++;
              print('✅ SYNC: Local database updated for purchase $purchaseId');
            }
            // Check for id field (alternative API response format)
            else if (result['id'] != null) {
              print(
                  '✅ SYNC: Successfully synced purchase $purchaseId - Server ID: ${result['id']}');

              // Update database with sync status
              print(
                  '💾 SYNC: Updating local database for purchase $purchaseId...');
              await PurchaseDatabase().updatePurchase(purchaseId, {
                'is_synced': 1,
                'transaction_id': result['id'],
              });
              syncedCount++;
              print('✅ SYNC: Local database updated for purchase $purchaseId');
            }
            // Check for nested data structure
            else if (result['data'] != null && result['data'] is Map) {
              final data = result['data'] as Map;
              if (data['id'] != null) {
                print(
                    '✅ SYNC: Successfully synced purchase $purchaseId - Server ID: ${data['id']}');

                // Update database with sync status
                print(
                    '💾 SYNC: Updating local database for purchase $purchaseId...');
                await PurchaseDatabase().updatePurchase(purchaseId, {
                  'is_synced': 1,
                  'transaction_id': data['id'],
                });
                syncedCount++;
                print(
                    '✅ SYNC: Local database updated for purchase $purchaseId');
              } else if (data['transaction_id'] != null) {
                print(
                    '✅ SYNC: Successfully synced purchase $purchaseId - Server ID: ${data['transaction_id']}');

                // Update database with sync status
                print(
                    '💾 SYNC: Updating local database for purchase $purchaseId...');
                await PurchaseDatabase().updatePurchase(purchaseId, {
                  'is_synced': 1,
                  'transaction_id': data['transaction_id'],
                });
                syncedCount++;
                print(
                    '✅ SYNC: Local database updated for purchase $purchaseId');
              } else {
                print(
                    '❌ SYNC: API response has data but no ID fields for purchase $purchaseId');
                failedCount++;
              }
            }
            // Check for success flag
            else if (result['success'] == true) {
              print(
                  '⚠️ SYNC: API reported success but no ID returned for purchase $purchaseId');
              print(
                  '🔍 SYNC: This might indicate the purchase was created but ID not returned');
              print(
                  '💡 SYNC: You may need to check the Laravel API response format');

              // Still mark as synced to avoid repeated attempts
              await PurchaseDatabase().updatePurchase(purchaseId, {
                'is_synced': 1,
                'transaction_id': null, // No server ID available
              });
              syncedCount++;
              print(
                  '✅ SYNC: Marked purchase $purchaseId as synced (no server ID)');
            }
            // Check for direct purchase data response (Laravel API returns purchase object directly)
            else if (result is Map &&
                result['contact_id'] != null &&
                result['location_id'] != null &&
                result['ref_no'] != null) {
              print(
                  '✅ SYNC: Successfully synced purchase $purchaseId - Direct purchase data received');
              print(
                  '📋 SYNC: Purchase details - Contact: ${result['contact_id']}, Ref: ${result['ref_no']}, Total: ${result['final_total']}');

              // Update database with sync status
              print(
                  '💾 SYNC: Updating local database for purchase $purchaseId...');
              await PurchaseDatabase().updatePurchase(purchaseId, {
                'is_synced': 1,
                'transaction_id':
                    null, // No explicit transaction ID in direct response
              });
              syncedCount++;
              print('✅ SYNC: Local database updated for purchase $purchaseId');
            } else {
              print(
                  '❌ SYNC: API response indicates failure for purchase $purchaseId');
              print('📋 SYNC: Response details: $result');
              failedCount++;
            }
          } else {
            print(
                '❌ SYNC: API returned null response for purchase $purchaseId');
            failedCount++;
          }
        } catch (syncError) {
          print('❌ SYNC: Failed to sync purchase $purchaseId: $syncError');
          failedCount++;

          // Log specific error types
          if (syncError.toString().contains('401')) {
            print('🔐 SYNC: Authentication error for purchase $purchaseId');
          } else if (syncError.toString().contains('422')) {
            print('📝 SYNC: Validation error for purchase $purchaseId');
          } else if (syncError.toString().contains('500')) {
            print('🖥️ SYNC: Server error for purchase $purchaseId');
          }

          // Continue with next purchase instead of failing completely
        }
      }

      // Reload purchases after sync
      print('🔄 SYNC: Reloading purchases after sync...');
      await loadPurchases();
      print('✅ SYNC: Purchase reload completed');

      // Final summary
      print('📊 SYNC SUMMARY:');
      print('   • Total purchases processed: ${unsyncedPurchases.length}');
      print('   • Successfully synced: $syncedCount');
      print('   • Failed to sync: $failedCount');
      print(
          '   • Success rate: ${unsyncedPurchases.length > 0 ? (syncedCount / unsyncedPurchases.length * 100).toStringAsFixed(1) : 0}%');

      if (syncedCount > 0) {
        print('🎉 SYNC: Synchronization completed successfully!');
      } else if (failedCount > 0) {
        print('⚠️ SYNC: Synchronization completed with failures');
      }

      return syncedCount > 0;
    } catch (e) {
      print('💥 SYNC: Critical error during synchronization: $e');

      // Handle authentication errors specifically
      if (e.toString().contains('Authentication failed') ||
          e.toString().contains('401')) {
        print('🔐 SYNC: Authentication failed - user needs to login again');
        state = state.copyWith(
            errorMessage: 'Authentication failed. Please login again.');
        return false;
      }

      print('❌ SYNC: Synchronization failed with error: $e');
      state = state.copyWith(errorMessage: 'Failed to sync purchases: $e');
      return false;
    }
  }

  /// Refresh cache if stale
  Future<void> refreshCacheIfNeeded() async {
    print('🔄 CACHE: Starting cache refresh...');
    try {
      final hasConnectivity = await Helper().checkConnectivity();
      print('📡 CACHE: Connectivity check: $hasConnectivity');

      if (hasConnectivity) {
        print(
            '📥 CACHE: Refreshing suppliers, products, and locations from server...');
        await _cacheService.refreshCacheIfNeeded();
        print('✅ CACHE: Cache refresh completed successfully');
      } else {
        print('📴 CACHE: No internet - using cached data only');
      }
    } catch (e) {
      print('❌ CACHE: Failed to refresh cache: $e');

      if (e.toString().contains('401')) {
        print('🔐 CACHE: Authentication error during cache refresh');
      } else if (e.toString().contains('no such table')) {
        print('💾 CACHE: Database table missing - may need app restart');
      }
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return await _cacheService.getCacheStats();
    } catch (e) {
      print('Failed to get cache stats: $e');
      return {};
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      await _cacheService.clearCache();
      print('Cache cleared successfully');
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Debug method to inspect current state
  void debugCurrentState() {
    print('🐛 DEBUG: Current Purchase Management State');
    print('   • Total purchases: ${state.purchases.length}');
    print('   • Suppliers cached: ${state.suppliers.length}');
    print('   • Products cached: ${state.products.length}');
    print('   • Is loading: ${state.isLoading}');
    print('   • Is refreshing: ${state.isRefreshing}');
    print('   • Error message: ${state.errorMessage ?? 'None'}');
    print('   • Selected status: ${state.selectedStatus}');
    print('   • Selected supplier: ${state.selectedSupplier}');
    print('   • Search query: "${state.searchQuery}"');
  }

  /// Debug method to check database state
  Future<void> debugDatabaseState() async {
    print('💾 DEBUG: Database State Inspection');

    try {
      // Check local purchases
      final localPurchases = await PurchaseDatabase().getPurchases();
      print('   • Local purchases: ${localPurchases.length}');

      // Check unsynced purchases
      final unsyncedPurchases =
          await PurchaseDatabase().getNotSyncedPurchases();
      print('   • Unsynced purchases: ${unsyncedPurchases.length}');

      // Check cached data
      final cachedSuppliers = await _cacheService.getCachedSuppliers();
      final cachedProducts = await _cacheService.getCachedProducts();
      final cachedLocations = await _cacheService.getCachedLocations();

      print('   • Cached suppliers: ${cachedSuppliers.length}');
      print('   • Cached products: ${cachedProducts.length}');
      print('   • Cached locations: ${cachedLocations.length}');

      // Check authentication
      final system = System();
      final isAuthenticated = await system.isAuthenticated();
      print('   • Is authenticated: $isAuthenticated');

      // Check connectivity
      final hasConnectivity = await Helper().checkConnectivity();
      print('   • Has connectivity: $hasConnectivity');
    } catch (e) {
      print('❌ DEBUG: Error inspecting database: $e');
    }
  }
}

/// Provider for purchase management
final purchaseManagementProvider =
    StateNotifierProvider<PurchaseManagementNotifier, PurchaseManagementState>(
  (ref) => PurchaseManagementNotifier(
    ref.watch(purchaseApiServiceProvider),
    ref.watch(purchaseCacheServiceProvider),
  ),
);

/// Provider for individual purchase details
final purchaseDetailsProvider = FutureProvider.family<Purchase?, int>(
  (ref, purchaseId) async {
    final notifier = ref.watch(purchaseManagementProvider.notifier);
    return await notifier.getPurchaseById(purchaseId);
  },
);
