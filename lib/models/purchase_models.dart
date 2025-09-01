// Purchase Models for Flutter Integration
// Based on Modules/Connector Purchase System

import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

// Helpers to safely parse numeric values from dynamic (num or String)
double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
  return null;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }
  return 0;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }
  return null;
}

String _formatDateTime(DateTime dt) {
  // Force ASCII digits regardless of app locale to satisfy backend (Laravel) validator
  return DateFormat('yyyy-MM-dd HH:mm:ss', 'en_US').format(dt);
}

DateTime _parseDateTimeFlex(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return DateTime.now();
  // Try ISO first (with T)
  try {
    return DateTime.parse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
  } catch (_) {}
  // Try mysql-style format
  try {
    return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
  } catch (_) {}
  // Fallback
  return DateTime.now();
}

/// Purchase Line Item Model
class PurchaseLineItem extends Equatable {
  final int? id;
  final int productId;
  final int variationId;
  final String productName;
  final String variationName;
  final double quantity;
  final double unitPrice;
  final double? lineDiscountAmount;
  final String? lineDiscountType;
  final int? itemTaxId;
  final double? itemTax;
  final int? subUnitId;
  final String? lotNumber;
  final DateTime? mfgDate;
  final DateTime? expDate;
  final int? purchaseOrderLineId;
  final int? purchaseRequisitionLineId;

  const PurchaseLineItem({
    this.id,
    required this.productId,
    required this.variationId,
    required this.productName,
    required this.variationName,
    required this.quantity,
    required this.unitPrice,
    this.lineDiscountAmount,
    this.lineDiscountType,
    this.itemTaxId,
    this.itemTax,
    this.subUnitId,
    this.lotNumber,
    this.mfgDate,
    this.expDate,
    this.purchaseOrderLineId,
    this.purchaseRequisitionLineId,
  });

  double get lineTotal => (unitPrice * quantity) - (lineDiscountAmount ?? 0);
  double get lineTotalWithTax => lineTotal + (itemTax ?? 0);

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'variation_id': variationId,
        'quantity': quantity,
        // Base unit price
        'unit_price': unitPrice,
        // Backend expected keys
        'pp_without_discount': unitPrice,
        'purchase_price': (lineDiscountType == 'fixed' && (lineDiscountAmount ?? 0) > 0)
            ? (unitPrice - (lineDiscountAmount ?? 0))
            : unitPrice,
        'purchase_price_inc_tax': (lineDiscountType == 'fixed' && (lineDiscountAmount ?? 0) > 0)
            ? (unitPrice - (lineDiscountAmount ?? 0))
            : unitPrice,
        'discount_percent': (lineDiscountType == 'percentage')
            ? (lineDiscountAmount ?? 0)
            : 0,
        // Keep original keys for compatibility
        'line_discount_amount': lineDiscountAmount,
        'line_discount_type': lineDiscountType,
        // Tax mapping
        'purchase_line_tax_id': itemTaxId,
        'item_tax_id': itemTaxId,
        'item_tax': itemTax,
        'sub_unit_id': subUnitId,
        'lot_number': lotNumber,
        'mfg_date': mfgDate?.toIso8601String(),
        'exp_date': expDate?.toIso8601String(),
        'purchase_order_line_id': purchaseOrderLineId,
        'purchase_requisition_line_id': purchaseRequisitionLineId,
      };

  factory PurchaseLineItem.fromJson(Map<String, dynamic> json) =>
      PurchaseLineItem(
        id: json['id'],
        productId: _asInt(json['product_id']),
        variationId: _asInt(json['variation_id']),
        productName: json['product_name'] ?? '',
        variationName: json['variation_name'] ?? '',
        quantity: _asDouble(json['quantity']) ?? 0,
        // Accept both unit_price and purchase_price for compatibility
        unitPrice: _asDouble(json['unit_price']) ??
            _asDouble(json['purchase_price']) ?? 0,
        lineDiscountAmount: _asDouble(json['line_discount_amount']),
        lineDiscountType: json['line_discount_type'],
        itemTaxId: _asInt(json['item_tax_id']),
        itemTax: _asDouble(json['item_tax']),
        subUnitId: json['sub_unit_id'],
        lotNumber: json['lot_number'],
        mfgDate:
            json['mfg_date'] != null ? DateTime.parse(json['mfg_date']) : null,
        expDate:
            json['exp_date'] != null ? DateTime.parse(json['exp_date']) : null,
        purchaseOrderLineId: json['purchase_order_line_id'],
        purchaseRequisitionLineId: json['purchase_requisition_line_id'],
      );

  PurchaseLineItem copyWith({
    int? id,
    int? productId,
    int? variationId,
    String? productName,
    String? variationName,
    double? quantity,
    double? unitPrice,
    double? lineDiscountAmount,
    String? lineDiscountType,
    int? itemTaxId,
    double? itemTax,
    int? subUnitId,
    String? lotNumber,
    DateTime? mfgDate,
    DateTime? expDate,
    int? purchaseOrderLineId,
    int? purchaseRequisitionLineId,
  }) {
    return PurchaseLineItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variationId: variationId ?? this.variationId,
      productName: productName ?? this.productName,
      variationName: variationName ?? this.variationName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineDiscountAmount: lineDiscountAmount ?? this.lineDiscountAmount,
      lineDiscountType: lineDiscountType ?? this.lineDiscountType,
      itemTaxId: itemTaxId ?? this.itemTaxId,
      itemTax: itemTax ?? this.itemTax,
      subUnitId: subUnitId ?? this.subUnitId,
      lotNumber: lotNumber ?? this.lotNumber,
      mfgDate: mfgDate ?? this.mfgDate,
      expDate: expDate ?? this.expDate,
      purchaseOrderLineId: purchaseOrderLineId ?? this.purchaseOrderLineId,
      purchaseRequisitionLineId:
          purchaseRequisitionLineId ?? this.purchaseRequisitionLineId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        variationId,
        productName,
        variationName,
        quantity,
        unitPrice,
        lineDiscountAmount,
        lineDiscountType,
        itemTaxId,
        itemTax,
        subUnitId,
        lotNumber,
        mfgDate,
        expDate,
        purchaseOrderLineId,
        purchaseRequisitionLineId,
      ];
}

/// Payment Model for Purchase
class PurchasePayment extends Equatable {
  final double amount;
  final String method;
  final DateTime? paidOn;
  final int? accountId;
  final String? note;

  const PurchasePayment({
    required this.amount,
    required this.method,
    this.paidOn,
    this.accountId,
    this.note,
  });

  Map<String, dynamic> toJson() {
    // Build map and avoid sending paid_on if not explicitly set
    // to let backend use its own default and parsing.
    final map = <String, dynamic>{
      'amount': amount,
      'method': method,
      'account_id': accountId,
      'note': note,
    };
    if (paidOn != null) {
      map['paid_on'] = _formatDateTime(paidOn!);
    }
    return map;
  }

  factory PurchasePayment.fromJson(Map<String, dynamic> json) =>
      PurchasePayment(
        amount: _asDouble(json['amount']) ?? 0,
        method: json['method'] ?? '',
        paidOn: json['paid_on'] != null ? _parseDateTimeFlex(json['paid_on']) : null,
        accountId: json['account_id'],
        note: json['note'],
      );

  @override
  List<Object?> get props => [amount, method, paidOn, accountId, note];
}

/// Purchase Model
class Purchase extends Equatable {
  final int? id;
  final int businessId;
  final int contactId;
  final int locationId;
  final String? refNo;
  final String status;
  final DateTime transactionDate;
  final double totalBeforeTax;
  final String? discountType;
  final double? discountAmount;
  final int? taxId;
  final double? taxAmount;
  final double? shippingCharges;
  final String? shippingDetails;
  final double finalTotal;
  final String? additionalNotes;
  final double? exchangeRate;
  final String? payTermType;
  final int? payTermNumber;
  final List<int>? purchaseOrderIds;
  final List<PurchaseLineItem> purchaseLines;
  final List<PurchasePayment>? payments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Purchase({
    this.id,
    required this.businessId,
    required this.contactId,
    required this.locationId,
    this.refNo,
    required this.status,
    required this.transactionDate,
    required this.totalBeforeTax,
    this.discountType,
    this.discountAmount,
    this.taxId,
    this.taxAmount,
    this.shippingCharges,
    this.shippingDetails,
    required this.finalTotal,
    this.additionalNotes,
    this.exchangeRate,
    this.payTermType,
    this.payTermNumber,
    this.purchaseOrderIds,
    required this.purchaseLines,
    this.payments,
    this.createdAt,
    this.updatedAt,
  });

  Purchase copyWith({
    int? id,
    int? businessId,
    int? contactId,
    int? locationId,
    String? refNo,
    String? status,
    DateTime? transactionDate,
    double? totalBeforeTax,
    String? discountType,
    double? discountAmount,
    int? taxId,
    double? taxAmount,
    double? shippingCharges,
    String? shippingDetails,
    double? finalTotal,
    String? additionalNotes,
    double? exchangeRate,
    String? payTermType,
    int? payTermNumber,
    List<int>? purchaseOrderIds,
    List<PurchaseLineItem>? purchaseLines,
    List<PurchasePayment>? payments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      contactId: contactId ?? this.contactId,
      locationId: locationId ?? this.locationId,
      refNo: refNo ?? this.refNo,
      status: status ?? this.status,
      transactionDate: transactionDate ?? this.transactionDate,
      totalBeforeTax: totalBeforeTax ?? this.totalBeforeTax,
      discountType: discountType ?? this.discountType,
      discountAmount: discountAmount ?? this.discountAmount,
      taxId: taxId ?? this.taxId,
      taxAmount: taxAmount ?? this.taxAmount,
      shippingCharges: shippingCharges ?? this.shippingCharges,
      shippingDetails: shippingDetails ?? this.shippingDetails,
      finalTotal: finalTotal ?? this.finalTotal,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      payTermType: payTermType ?? this.payTermType,
      payTermNumber: payTermNumber ?? this.payTermNumber,
      purchaseOrderIds: purchaseOrderIds ?? this.purchaseOrderIds,
      purchaseLines: purchaseLines ?? this.purchaseLines,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get subtotal =>
      purchaseLines.fold(0, (sum, line) => sum + line.lineTotal);
  double get totalTax =>
      purchaseLines.fold(0, (sum, line) => sum + (line.itemTax ?? 0));
  double get totalDiscount => purchaseLines.fold(
      0, (sum, line) => sum + (line.lineDiscountAmount ?? 0));

  Map<String, dynamic> toJson() {
    // Build map without nulls that would violate Laravel's validation
    final map = <String, dynamic>{
      'contact_id': contactId,
      'location_id': locationId,
      'ref_no': refNo,
      'status': status,
      'transaction_date': _formatDateTime(transactionDate),
      'total_before_tax': totalBeforeTax,
      'discount_type': discountType,
      'discount_amount': discountAmount,
      'tax_id': taxId,
      'tax_amount': taxAmount,
      'shipping_charges': shippingCharges,
      'shipping_details': shippingDetails,
      'final_total': finalTotal,
      'additional_notes': additionalNotes,
      'exchange_rate': exchangeRate,
      'purchases': purchaseLines.map((line) => line.toJson()).toList(),
    };

    if (purchaseOrderIds != null && purchaseOrderIds!.isNotEmpty) {
      map['purchase_order_ids'] = purchaseOrderIds;
    }
    if (payTermType != null && (payTermNumber ?? 0) > 0) {
      map['pay_term_type'] = payTermType;
      map['pay_term_number'] = payTermNumber;
    }

    // Only include payments key if we actually have payments
    if (payments != null && payments!.isNotEmpty) {
      map['payments'] = payments!.map((p) => p.toJson()).toList();
    }

    return map;
  }

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'],
        businessId: _asInt(json['business_id']),
        contactId: json.containsKey('contact_id')
            ? _asInt(json['contact_id'])
            : _asInt((json['contact'] is Map ? json['contact']['id'] : null)),
        locationId: json.containsKey('location_id')
            ? _asInt(json['location_id'])
            : _asInt((json['location'] is Map ? json['location']['id'] : null)),
        refNo: json['ref_no'],
        status: json['status'],
        transactionDate: _parseDateTimeFlex(json['transaction_date']),
        totalBeforeTax: _asDouble(json['total_before_tax']) ?? 0,
        discountType: json['discount_type'],
        discountAmount: _asDouble(json['discount_amount']),
        taxId: json['tax_id'],
        taxAmount: _asDouble(json['tax_amount']),
        shippingCharges: _asDouble(json['shipping_charges']),
        shippingDetails: json['shipping_details'],
        finalTotal: _asDouble(json['final_total']) ?? 0,
        additionalNotes: json['additional_notes'],
        exchangeRate: _asDouble(json['exchange_rate']),
        payTermType: json['pay_term_type'],
        payTermNumber: json['pay_term_number'] != null
            ? _asInt(json['pay_term_number'])
            : null,
        purchaseOrderIds: json['purchase_order_ids'] != null
            ? List<int>.from(json['purchase_order_ids'])
            : null,
        // Accept both response-style 'lines' and request-style 'purchases'
        purchaseLines: json['lines'] != null
            ? (json['lines'] as List)
                .map((line) => PurchaseLineItem.fromJson(line))
                .toList()
            : (json['purchases'] != null
                ? (json['purchases'] as List)
                    .map((line) => PurchaseLineItem.fromJson(line))
                    .toList()
                : []),
        payments: json['payments'] != null
            ? (json['payments'] as List)
                .map((payment) => PurchasePayment.fromJson(payment))
                .toList()
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );

  @override
  List<Object?> get props => [
        id,
        businessId,
        contactId,
        locationId,
        refNo,
        status,
        transactionDate,
        totalBeforeTax,
        discountType,
        discountAmount,
        taxId,
        taxAmount,
        shippingCharges,
        shippingDetails,
        finalTotal,
        additionalNotes,
        exchangeRate,
        payTermType,
        payTermNumber,
        purchaseOrderIds,
        purchaseLines,
        payments,
        createdAt,
        updatedAt,
      ];
}

/// Supplier Model for Purchase
class Supplier extends Equatable {
  final int id;
  final String name;
  final String? businessName;
  final String? contactId;
  final String? mobile;
  final String? address;
  final double? balance;

  const Supplier({
    required this.id,
    required this.name,
    this.businessName,
    this.contactId,
    this.mobile,
    this.address,
    this.balance,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'],
        name: json['text'] ?? json['name'] ?? '',
        businessName: json['business_name'] ?? json['supplier_business_name'],
        contactId: json['contact_id'],
        mobile: json['mobile'],
        address: json['address_line_1'],
        balance: _asDouble(json['balance']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'business_name': businessName,
        'supplier_business_name': businessName,
        'contact_id': contactId,
        'mobile': mobile,
        'address_line_1': address,
        'balance': balance,
        'text': name, // Legacy compatibility
      };

  @override
  List<Object?> get props =>
      [id, name, businessName, contactId, mobile, address, balance];
}

/// Product Model for Purchase
class PurchaseProduct extends Equatable {
  final int productId;
  final String productName;
  final String productType;
  final int variationId;
  final String variationName;
  final String? subSku;
  final double? defaultPurchasePrice;

  const PurchaseProduct({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.variationId,
    required this.variationName,
    this.subSku,
    this.defaultPurchasePrice,
  });

  factory PurchaseProduct.fromJson(Map<String, dynamic> json) =>
      PurchaseProduct(
        productId: _asInt(json['product_id']),
        productName: json['product_name'],
        productType: json['product_type'],
        variationId: _asInt(json['variation_id']),
        variationName: json['variation_name'],
        subSku: json['sub_sku'],
        defaultPurchasePrice: _asDouble(json['default_purchase_price']),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'product_type': productType,
        'variation_id': variationId,
        'variation_name': variationName,
        'sub_sku': subSku,
        'default_purchase_price': defaultPurchasePrice,
      };

  @override
  List<Object?> get props => [
        productId,
        productName,
        productType,
        variationId,
        variationName,
        subSku,
        defaultPurchasePrice,
      ];
}

/// Purchase Creation Request Model
class CreatePurchaseRequest {
  final Purchase purchase;
  final List<PurchasePayment>? payments;

  const CreatePurchaseRequest({
    required this.purchase,
    this.payments,
  });

  Map<String, dynamic> toJson() {
    final data = purchase.toJson();
    if (payments != null && payments!.isNotEmpty) {
      data['payments'] = payments!.map((payment) => payment.toJson()).toList();
    }
    return data;
  }
}

/// Purchase Update Request Model
class UpdatePurchaseRequest {
  final int purchaseId;
  final Purchase purchase;
  final List<PurchasePayment>? payments;

  const UpdatePurchaseRequest({
    required this.purchaseId,
    required this.purchase,
    this.payments,
  });

  Map<String, dynamic> toJson() {
    final data = purchase.toJson();
    if (payments != null && payments!.isNotEmpty) {
      data['payments'] = payments!.map((payment) => payment.toJson()).toList();
    }
    return data;
  }
}
