import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_models.dart';
import '../models/purchase.dart' as purchase_db;
import '../models/purchaseDatabase.dart';
import '../services/purchase_api_service.dart';
import '../services/purchase_cache_service.dart';
import '../helpers/otherHelpers.dart';

/// State class for purchase creation
class PurchaseCreationState {
  final bool isLoading;
  final bool isSubmitting;
  final Purchase? purchase;
  final List<Supplier> suppliers;
  final List<PurchaseProduct> products;
  final List<Map<String, dynamic>> locations;
  final String? errorMessage;
  final bool isValid;

  const PurchaseCreationState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.purchase,
    this.suppliers = const [],
    this.products = const [],
    this.locations = const [],
    this.errorMessage,
    this.isValid = false,
  });

  PurchaseCreationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    Purchase? purchase,
    List<Supplier>? suppliers,
    List<PurchaseProduct>? products,
    List<Map<String, dynamic>>? locations,
    String? errorMessage,
    bool? isValid,
  }) {
    return PurchaseCreationState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      purchase: purchase ?? this.purchase,
      suppliers: suppliers ?? this.suppliers,
      products: products ?? this.products,
      locations: locations ?? this.locations,
      errorMessage: errorMessage,
      isValid: isValid ?? this.isValid,
    );
  }

  // Validation logic
  bool get hasValidSupplier => purchase?.contactId != null;
  bool get hasValidLocation => purchase?.locationId != null;
  bool get hasValidLines => purchase?.purchaseLines.isNotEmpty == true;
  bool get hasValidTotal =>
      purchase?.finalTotal != null && purchase!.finalTotal > 0;

  bool get isFormValid =>
      hasValidSupplier && hasValidLocation && hasValidLines && hasValidTotal;
}

/// Notifier for purchase creation
class PurchaseCreationNotifier extends StateNotifier<PurchaseCreationState> {
  final PurchaseApiService _apiService;
  final PurchaseCacheService _cacheService;

  PurchaseCreationNotifier(this._apiService, this._cacheService)
      : super(const PurchaseCreationState()) {
    _initializePurchase();
  }

  void _initializePurchase() {
    final now = DateTime.now();
    final purchase = Purchase(
      businessId: 1, // Should be from user context
      contactId: 0,
      locationId: 1, // Should be from user context
      status: 'ordered',
      transactionDate: now,
      totalBeforeTax: 0,
      finalTotal: 0,
      exchangeRate: 1,
      purchaseLines: [],
    );

    state = state.copyWith(purchase: purchase);
  }

  /// Load suppliers
  Future<void> loadSuppliers({String? searchTerm}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Try to load from cache first
      final cachedSuppliers =
          await _cacheService.getCachedSuppliers(searchTerm: searchTerm);
      if (cachedSuppliers.isNotEmpty) {
        final suppliers = cachedSuppliers
            .map((supplier) => Supplier.fromJson(supplier))
            .toList();
        state = state.copyWith(
          suppliers: suppliers,
          isLoading: false,
        );

        // Try to refresh from API in background if online
        if (await Helper().checkConnectivity()) {
          try {
            final freshSuppliers =
                await _apiService.getSuppliers(searchTerm: searchTerm);
            await _cacheService.cacheSuppliers(freshSuppliers);
            state = state.copyWith(suppliers: freshSuppliers);
          } catch (e) {
            // Keep cached data if API fails
            print('Failed to refresh suppliers from API: $e');
          }
        }
      } else {
        // No cached data, try to load from API
        final suppliers =
            await _apiService.getSuppliers(searchTerm: searchTerm);
        await _cacheService.cacheSuppliers(suppliers);
        state = state.copyWith(
          suppliers: suppliers,
          isLoading: false,
        );
      }
    } catch (e) {
      // If both cache and API fail, try to load from cache as fallback
      try {
        final cachedSuppliers =
            await _cacheService.getCachedSuppliers(searchTerm: searchTerm);
        if (cachedSuppliers.isNotEmpty) {
          final suppliers = cachedSuppliers
              .map((supplier) => Supplier.fromJson(supplier))
              .toList();
          state = state.copyWith(
            suppliers: suppliers,
            isLoading: false,
            errorMessage: 'Using cached data (offline mode)',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load suppliers: $e',
          );
        }
      } catch (cacheError) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load suppliers: $e',
        );
      }
    }
  }

  /// Load products
  Future<void> loadProducts({String? searchTerm}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Try to load from cache first
      final cachedProducts =
          await _cacheService.getCachedProducts(searchTerm: searchTerm);
      if (cachedProducts.isNotEmpty) {
        final products = cachedProducts
            .map((product) => PurchaseProduct.fromJson(product))
            .toList();
        state = state.copyWith(
          products: products,
          isLoading: false,
        );

        // Try to refresh from API in background if online
        if (await Helper().checkConnectivity()) {
          try {
            final freshProducts =
                await _apiService.getProducts(searchTerm: searchTerm);
            await _cacheService.cacheProducts(freshProducts);
            state = state.copyWith(products: freshProducts);
          } catch (e) {
            // Keep cached data if API fails
            print('Failed to refresh products from API: $e');
          }
        }
      } else {
        // No cached data, try to load from API
        final products = await _apiService.getProducts(searchTerm: searchTerm);
        await _cacheService.cacheProducts(products);
        state = state.copyWith(
          products: products,
          isLoading: false,
        );
      }
    } catch (e) {
      // If both cache and API fail, try to load from cache as fallback
      try {
        final cachedProducts =
            await _cacheService.getCachedProducts(searchTerm: searchTerm);
        if (cachedProducts.isNotEmpty) {
          final products = cachedProducts
              .map((product) => PurchaseProduct.fromJson(product))
              .toList();
          state = state.copyWith(
            products: products,
            isLoading: false,
            errorMessage: 'Using cached data (offline mode)',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load products: $e',
          );
        }
      } catch (cacheError) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load products: $e',
        );
      }
    }
  }

  /// Load locations
  Future<void> loadLocations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Try to load from cache first
      final cachedLocations = await _cacheService.getCachedLocations();
      if (cachedLocations.isNotEmpty) {
        state = state.copyWith(
          locations: cachedLocations,
          isLoading: false,
        );

        // Try to refresh from API in background if online
        if (await Helper().checkConnectivity()) {
          try {
            final freshLocations = await _apiService.getLocations();
            await _cacheService.cacheLocations(freshLocations);
            state = state.copyWith(locations: freshLocations);
          } catch (e) {
            // Keep cached data if API fails
            print('Failed to refresh locations from API: $e');
          }
        }
      } else {
        // No cached data, try to load from API
        final locations = await _apiService.getLocations();
        await _cacheService.cacheLocations(locations);
        state = state.copyWith(
          locations: locations,
          isLoading: false,
        );
      }
    } catch (e) {
      // If both cache and API fail, try to load from cache as fallback
      try {
        final cachedLocations = await _cacheService.getCachedLocations();
        if (cachedLocations.isNotEmpty) {
          state = state.copyWith(
            locations: cachedLocations,
            isLoading: false,
            errorMessage: 'Using cached data (offline mode)',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load locations: $e',
          );
        }
      } catch (cacheError) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load locations: $e',
        );
      }
    }
  }

  /// Update supplier
  void updateSupplier(int supplierId) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(contactId: supplierId);
    state = state.copyWith(
      purchase: updatedPurchase,
      isValid: _validatePurchase(updatedPurchase),
    );
  }

  /// Update location
  void updateLocation(int locationId) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(locationId: locationId);
    state = state.copyWith(
      purchase: updatedPurchase,
      isValid: _validatePurchase(updatedPurchase),
    );
  }

  /// Update transaction date
  void updateTransactionDate(DateTime date) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(transactionDate: date);
    state = state.copyWith(purchase: updatedPurchase);
  }

  /// Update status
  void updateStatus(String status) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(status: status);
    state = state.copyWith(purchase: updatedPurchase);
  }

  /// Update reference number
  void updateReferenceNumber(String? refNo) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(refNo: refNo);
    state = state.copyWith(purchase: updatedPurchase);
  }

  /// Update discount
  void updateDiscount({String? type, double? amount}) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(
      discountType: type ?? state.purchase!.discountType,
      discountAmount: amount ?? state.purchase!.discountAmount,
    );

    final recalculatedPurchase = _recalculateTotals(updatedPurchase);
    state = state.copyWith(
      purchase: recalculatedPurchase,
      isValid: _validatePurchase(recalculatedPurchase),
    );
  }

  /// Update tax
  void updateTax({int? taxId, double? taxAmount}) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(
      taxId: taxId ?? state.purchase!.taxId,
      taxAmount: taxAmount ?? state.purchase!.taxAmount,
    );

    final recalculatedPurchase = _recalculateTotals(updatedPurchase);
    state = state.copyWith(
      purchase: recalculatedPurchase,
      isValid: _validatePurchase(recalculatedPurchase),
    );
  }

  /// Update shipping
  void updateShipping({double? charges, String? details}) {
    if (state.purchase == null) return;

    final updatedPurchase = state.purchase!.copyWith(
      shippingCharges: charges ?? state.purchase!.shippingCharges,
      shippingDetails: details ?? state.purchase!.shippingDetails,
    );

    final recalculatedPurchase = _recalculateTotals(updatedPurchase);
    state = state.copyWith(
      purchase: recalculatedPurchase,
      isValid: _validatePurchase(recalculatedPurchase),
    );
  }

  /// Add product to purchase
  void addProduct(PurchaseProduct product, double quantity, double unitPrice) {
    if (state.purchase == null) return;

    final lineItem = PurchaseLineItem(
      productId: product.productId,
      variationId: product.variationId,
      productName: product.productName,
      variationName: product.variationName,
      quantity: quantity,
      unitPrice: unitPrice,
    );

    final updatedLines = [...state.purchase!.purchaseLines, lineItem];
    final updatedPurchase =
        state.purchase!.copyWith(purchaseLines: updatedLines);

    final recalculatedPurchase = _recalculateTotals(updatedPurchase);
    state = state.copyWith(
      purchase: recalculatedPurchase,
      isValid: _validatePurchase(recalculatedPurchase),
    );
  }

  /// Update line item
  void updateLineItem(int index, PurchaseLineItem updatedLine) {
    if (state.purchase == null || index >= state.purchase!.purchaseLines.length)
      return;

    final updatedLines = [...state.purchase!.purchaseLines];
    updatedLines[index] = updatedLine;

    final updatedPurchase =
        state.purchase!.copyWith(purchaseLines: updatedLines);
    final recalculatedPurchase = _recalculateTotals(updatedPurchase);

    state = state.copyWith(
      purchase: recalculatedPurchase,
      isValid: _validatePurchase(recalculatedPurchase),
    );
  }

  /// Remove line item
  void removeLineItem(int index) {
    if (state.purchase == null || index >= state.purchase!.purchaseLines.length)
      return;

    final updatedLines = [...state.purchase!.purchaseLines]..removeAt(index);
    final updatedPurchase =
        state.purchase!.copyWith(purchaseLines: updatedLines);

    final recalculatedPurchase = _recalculateTotals(updatedPurchase);
    state = state.copyWith(
      purchase: recalculatedPurchase,
      isValid: _validatePurchase(recalculatedPurchase),
    );
  }

  /// Add payment
  void addPayment(PurchasePayment payment) {
    if (state.purchase == null) return;

    final updatedPayments = [...?state.purchase!.payments, payment];
    final updatedPurchase = state.purchase!.copyWith(payments: updatedPayments);

    state = state.copyWith(purchase: updatedPurchase);
  }

  /// Remove payment
  void removePayment(int index) {
    if (state.purchase == null ||
        state.purchase!.payments == null ||
        index >= state.purchase!.payments!.length) return;

    final updatedPayments = [...state.purchase!.payments!]..removeAt(index);
    final updatedPurchase = state.purchase!.copyWith(payments: updatedPayments);

    state = state.copyWith(purchase: updatedPurchase);
  }

  /// Submit purchase
  Future<bool> submitPurchase() async {
    print('🛒 PURCHASE CREATION: Starting purchase submission...');

    if (state.purchase == null || !state.isFormValid) {
      print('❌ PURCHASE CREATION: Form validation failed');
      state = state.copyWith(errorMessage: 'Please fill all required fields');
      return false;
    }

    print('📋 PURCHASE CREATION: Form validation passed');
    print(
        '📊 PURCHASE CREATION: Purchase details - Supplier: ${state.purchase!.contactId}, Location: ${state.purchase!.locationId}, Total: ${state.purchase!.finalTotal}, Lines: ${state.purchase!.purchaseLines.length}');

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      print('💾 PURCHASE CREATION: Saving to local database...');

      // Save to local database first
      final purchaseId = await PurchaseDatabase().storePurchase({
        'transaction_date': state.purchase!.transactionDate.toIso8601String(),
        'ref_no': state.purchase!.refNo,
        'contact_id': state.purchase!.contactId,
        'location_id': state.purchase!.locationId,
        'status': state.purchase!.status,
        'tax_id': state.purchase!.taxId,
        'discount_amount': state.purchase!.discountAmount ?? 0.00,
        'discount_type': state.purchase!.discountType ?? 'fixed',
        'total_before_tax': state.purchase!.totalBeforeTax,
        'tax_amount': state.purchase!.taxAmount ?? 0.00,
        'final_total': state.purchase!.finalTotal,
        'additional_notes': state.purchase!.additionalNotes,
        'shipping_charges': state.purchase!.shippingCharges ?? 0.00,
        'shipping_details': state.purchase!.shippingDetails,
        'is_synced': 0, // Mark as not synced initially
      });

      print(
          '✅ PURCHASE CREATION: Purchase saved to local DB with ID: $purchaseId');

      // Save purchase lines
      print(
          '📦 PURCHASE CREATION: Saving ${state.purchase!.purchaseLines.length} purchase lines...');
      for (int i = 0; i < state.purchase!.purchaseLines.length; i++) {
        final line = state.purchase!.purchaseLines[i];
        await PurchaseDatabase().storePurchaseLine({
          'purchase_id': purchaseId,
          'product_id': line.productId,
          'variation_id': line.variationId,
          'quantity': line.quantity,
          'unit_price': line.unitPrice,
          'line_discount_amount': line.lineDiscountAmount ?? 0.00,
          'line_discount_type': line.lineDiscountType ?? 'fixed',
          'item_tax_id': line.itemTaxId,
          'item_tax': line.itemTax ?? 0.00,
          'sub_unit_id': line.subUnitId,
          'lot_number': line.lotNumber,
          'mfg_date': line.mfgDate?.toIso8601String(),
          'exp_date': line.expDate?.toIso8601String(),
          'purchase_order_line_id': line.purchaseOrderLineId,
          'purchase_requisition_line_id': line.purchaseRequisitionLineId,
        });
        print(
            '   • Line ${i + 1}: Product ${line.productId}, Qty: ${line.quantity}, Price: ${line.unitPrice}');
      }
      print('✅ PURCHASE CREATION: All purchase lines saved');

      // Save payments if any
      if (state.purchase!.payments != null &&
          state.purchase!.payments!.isNotEmpty) {
        print(
            '💳 PURCHASE CREATION: Saving ${state.purchase!.payments!.length} payments...');
        for (int i = 0; i < state.purchase!.payments!.length; i++) {
          final payment = state.purchase!.payments![i];
          await PurchaseDatabase().storePurchasePayment({
            'purchase_id': purchaseId,
            'method': payment.method,
            'amount': payment.amount,
            'note': payment.note,
            'paid_on': payment.paidOn?.toIso8601String(),
          });
          print(
              '   • Payment ${i + 1}: ${payment.method}, Amount: ${payment.amount}');
        }
        print('✅ PURCHASE CREATION: All payments saved');
      } else {
        print('💳 PURCHASE CREATION: No payments to save');
      }

      // Check connectivity for API sync
      final hasConnectivity = await Helper().checkConnectivity();
      print('📡 PURCHASE CREATION: Internet connectivity: $hasConnectivity');

      // Try to sync with API if connected
      if (hasConnectivity) {
        print('🔄 PURCHASE CREATION: Attempting to sync with server...');
        try {
          final request = CreatePurchaseRequest(
            purchase: state.purchase!,
            payments: state.purchase!.payments,
          );

          final result = await _apiService.createPurchase(request);

          // Update database with sync status and transaction ID
          if (result != null && result.id != null) {
            print(
                '✅ PURCHASE CREATION: Successfully synced with server - Transaction ID: ${result.id}');
            await PurchaseDatabase().updatePurchase(purchaseId, {
              'is_synced': 1,
              'transaction_id': result.id,
            });
            print(
                '💾 PURCHASE CREATION: Local database updated with sync status');
          } else {
            print(
                '⚠️ PURCHASE CREATION: API returned success but no transaction ID');
          }
        } catch (apiError) {
          print('❌ PURCHASE CREATION: API sync failed: $apiError');
          print(
              'ℹ️ PURCHASE CREATION: Purchase saved locally, will sync later when online');

          // Check if it's an authentication error
          if (apiError.toString().contains('401') ||
              apiError.toString().contains('Authentication failed')) {
            print(
                '🔐 PURCHASE CREATION: Authentication error - user may need to login again');
          }
        }
      } else {
        print(
            '📴 PURCHASE CREATION: Offline mode - purchase saved locally, will sync when online');
        print(
            '💡 PURCHASE CREATION: To sync later, go online and use the sync button');
      }

      // Reset for a new entry
      print('🔄 PURCHASE CREATION: Resetting form for new purchase...');
      _initializePurchase();
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: null,
      );

      print('🎉 PURCHASE CREATION: Purchase creation completed successfully!');
      print(
          '📈 PURCHASE CREATION: Summary - ID: $purchaseId, Synced: ${hasConnectivity ? 'Yes' : 'No (will sync later)'}');

      return true;
    } catch (e) {
      print(
          '💥 PURCHASE CREATION: Critical error during purchase creation: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Reset form
  void reset() {
    _initializePurchase();
  }

  /// Recalculate totals
  Purchase _recalculateTotals(Purchase purchase) {
    double subtotal = 0;
    double totalTax = 0;

    for (final line in purchase.purchaseLines) {
      subtotal += line.lineTotal;
      totalTax += line.itemTax ?? 0;
    }

    final discount = purchase.discountAmount ?? 0;
    final shipping = purchase.shippingCharges ?? 0;

    final finalTotal = subtotal + totalTax - discount + shipping;

    return purchase.copyWith(
      totalBeforeTax: subtotal,
      taxAmount: totalTax,
      finalTotal: finalTotal,
    );
  }

  /// Validate purchase
  bool _validatePurchase(Purchase purchase) {
    return purchase.contactId > 0 &&
        purchase.locationId > 0 &&
        purchase.purchaseLines.isNotEmpty &&
        purchase.finalTotal > 0;
  }
}

/// Provider for purchase creation
final purchaseCreationProvider =
    StateNotifierProvider<PurchaseCreationNotifier, PurchaseCreationState>(
  (ref) {
    final apiService = ref.watch(purchaseApiServiceProvider);
    final cacheService = ref.watch(purchaseCacheServiceProvider);
    return PurchaseCreationNotifier(apiService, cacheService);
  },
);

/// Provider for purchase list
final purchaseListProvider = StateNotifierProvider<PurchaseListNotifier,
    AsyncValue<PurchaseListResponse>>(
  (ref) {
    final apiService = ref.watch(purchaseApiServiceProvider);
    return PurchaseListNotifier(apiService);
  },
);

/// Notifier for purchase list
class PurchaseListNotifier
    extends StateNotifier<AsyncValue<PurchaseListResponse>> {
  final PurchaseApiService _apiService;

  PurchaseListNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadPurchases();
  }

  Future<void> loadPurchases({
    int? supplierId,
    int? locationId,
    String? status,
    String? paymentStatus,
    DateTime? startDate,
    DateTime? endDate,
    String? refNo,
    int? page = 1,
  }) async {
    state = const AsyncValue.loading();

    try {
      final response = await _apiService.getPurchases(
        supplierId: supplierId,
        locationId: locationId,
        status: status,
        paymentStatus: paymentStatus,
        startDate: startDate,
        endDate: endDate,
        refNo: refNo,
        page: page,
      );

      state = AsyncValue.data(response);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await loadPurchases();
  }

  Future<void> loadNextPage() async {
    final currentData = state.value;
    if (currentData == null || !currentData.hasNextPage) return;

    await loadPurchases(page: currentData.currentPage + 1);
  }
}

/// Provider for individual purchase details
final purchaseDetailsProvider = FutureProvider.family<Purchase?, int>(
  (ref, purchaseId) async {
    final apiService = ref.watch(purchaseApiServiceProvider);
    return apiService.getPurchase(purchaseId);
  },
);
