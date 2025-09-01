import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_models.dart';
import '../services/purchase_api_service.dart';

/// State class for purchase creation
class PurchaseCreationState {
  final bool isLoading;
  final bool isSubmitting;
  final Purchase? purchase;
  final List<Supplier> suppliers;
  final List<PurchaseProduct> products;
  final String? errorMessage;
  final bool isValid;

  const PurchaseCreationState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.purchase,
    this.suppliers = const [],
    this.products = const [],
    this.errorMessage,
    this.isValid = false,
  });

  PurchaseCreationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    Purchase? purchase,
    List<Supplier>? suppliers,
    List<PurchaseProduct>? products,
    String? errorMessage,
    bool? isValid,
  }) {
    return PurchaseCreationState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      purchase: purchase ?? this.purchase,
      suppliers: suppliers ?? this.suppliers,
      products: products ?? this.products,
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

  PurchaseCreationNotifier(this._apiService)
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
      final suppliers = await _apiService.getSuppliers(searchTerm: searchTerm);
      state = state.copyWith(
        suppliers: suppliers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load suppliers: $e',
      );
    }
  }

  /// Load products
  Future<void> loadProducts({String? searchTerm}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final products = await _apiService.getProducts(searchTerm: searchTerm);
      state = state.copyWith(
        products: products,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load products: $e',
      );
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
    if (state.purchase == null || !state.isFormValid) {
      state = state.copyWith(errorMessage: 'Please fill all required fields');
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final request = CreatePurchaseRequest(
        purchase: state.purchase!,
        payments: state.purchase!.payments,
      );

      await _apiService.createPurchase(request);

      // Reset for a new entry
      _initializePurchase();
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: null,
      );

      return true;
    } catch (e) {
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
    return PurchaseCreationNotifier(apiService);
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
