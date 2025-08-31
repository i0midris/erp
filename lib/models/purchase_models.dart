// Purchase Models for Flutter Integration
// Based on Modules/Connector Purchase System

import 'package:equatable/equatable.dart';

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
        'unit_price': unitPrice,
        'line_discount_amount': lineDiscountAmount,
        'line_discount_type': lineDiscountType,
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
        productId: json['product_id'],
        variationId: json['variation_id'],
        productName: json['product_name'] ?? '',
        variationName: json['variation_name'] ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        lineDiscountAmount: (json['line_discount_amount'] as num?)?.toDouble(),
        lineDiscountType: json['line_discount_type'],
        itemTaxId: json['item_tax_id'],
        itemTax: (json['item_tax'] as num?)?.toDouble(),
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

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'method': method,
        'paid_on': paidOn?.toIso8601String(),
        'account_id': accountId,
        'note': note,
      };

  factory PurchasePayment.fromJson(Map<String, dynamic> json) =>
      PurchasePayment(
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        method: json['method'] ?? '',
        paidOn:
            json['paid_on'] != null ? DateTime.parse(json['paid_on']) : null,
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

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'location_id': locationId,
        'ref_no': refNo,
        'status': status,
        'transaction_date': transactionDate.toIso8601String(),
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
        'pay_term_type': payTermType,
        'pay_term_number': payTermNumber,
        'purchase_order_ids': purchaseOrderIds,
        'purchases': purchaseLines.map((line) => line.toJson()).toList(),
        'payments': payments?.map((payment) => payment.toJson()).toList(),
      };

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'],
        businessId: json['business_id'],
        contactId: json['contact_id'],
        locationId: json['location_id'],
        refNo: json['ref_no'],
        status: json['status'],
        transactionDate: DateTime.parse(json['transaction_date']),
        totalBeforeTax: (json['total_before_tax'] as num?)?.toDouble() ?? 0,
        discountType: json['discount_type'],
        discountAmount: (json['discount_amount'] as num?)?.toDouble(),
        taxId: json['tax_id'],
        taxAmount: (json['tax_amount'] as num?)?.toDouble(),
        shippingCharges: (json['shipping_charges'] as num?)?.toDouble(),
        shippingDetails: json['shipping_details'],
        finalTotal: (json['final_total'] as num?)?.toDouble() ?? 0,
        additionalNotes: json['additional_notes'],
        exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
        payTermType: json['pay_term_type'],
        payTermNumber: json['pay_term_number'],
        purchaseOrderIds: json['purchase_order_ids'] != null
            ? List<int>.from(json['purchase_order_ids'])
            : null,
        purchaseLines: json['lines'] != null
            ? (json['lines'] as List)
                .map((line) => PurchaseLineItem.fromJson(line))
                .toList()
            : [],
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
        balance: (json['balance'] as num?)?.toDouble(),
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
        productId: json['product_id'],
        productName: json['product_name'],
        productType: json['product_type'],
        variationId: json['variation_id'],
        variationName: json['variation_name'],
        subSku: json['sub_sku'],
        defaultPurchasePrice:
            (json['default_purchase_price'] as num?)?.toDouble(),
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
