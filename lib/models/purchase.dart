import 'dart:convert';

import '../apis/purchase_api.dart';
import '../models/purchaseDatabase.dart';
import '../models/system.dart';

class Purchase {
  // Sync purchase
  Future<bool> createApiPurchase({purchaseId, bool? syncAll}) async {
    List purchases;
    (syncAll != null)
        ? purchases = await PurchaseDatabase().getNotSyncedPurchases()
        : purchases = await PurchaseDatabase().getPurchaseById(purchaseId);

    purchases.forEach((element) async {
      List products = await PurchaseDatabase().getPurchaseLines(element['id']);
      // Model map for creating new purchase
      List<Map<String, dynamic>> purchaseData = [
        {
          'location_id': element['location_id'],
          'contact_id': element['contact_id'],
          'transaction_date': element['transaction_date'],
          'ref_no': element['ref_no'],
          'status': element['status'],
          'tax_id': (element['tax_id'] == 0) ? null : element['tax_id'],
          'discount_amount': element['discount_amount'],
          'discount_type': element['discount_type'],
          'total_before_tax': element['total_before_tax'],
          'tax_amount': element['tax_amount'],
          'final_total': element['final_total'],
          'additional_notes': element['additional_notes'],
          'shipping_charges': element['shipping_charges'],
          'shipping_details': element['shipping_details'],
          'purchases': products,
          'payments':
              await PurchaseDatabase().getPurchasePayments(element['id']),
        }
      ];

      if (element['is_synced'] == 0) {
        if (element['transaction_id'] != null) {
          var purchaseJson = jsonEncode({'purchases': purchaseData});
          Map<String, dynamic>? updatedResult = await PurchaseApi()
              .update(element['transaction_id'], purchaseJson);
          if (updatedResult != null) {
            await PurchaseDatabase()
                .updatePurchase(element['id'], {'is_synced': 1});
            // Handle payment lines update if needed
            var result = updatedResult['payment_lines'];
            if (result != null) {
              // Delete existing payment lines
              await PurchaseDatabase()
                  .deletePurchasePaymentsByPurchaseId(element['id']);
              result.forEach((paymentLine) async {
                // Store payment lines from response
                await PurchaseDatabase().storePurchasePayment({
                  'purchase_id': element['id'],
                  'method': paymentLine['method'],
                  'amount': paymentLine['amount'],
                  'note': paymentLine['note'],
                  'payment_id': paymentLine['id'],
                  'paid_on': paymentLine['paid_on'],
                  'account_id': paymentLine['account_id']
                });
              });
            }
          }
        } else {
          var purchaseJson = jsonEncode({'purchases': purchaseData});
          var result = await PurchaseApi().create(purchaseJson);
          if (result != null) {
            await PurchaseDatabase().updatePurchase(element['id'],
                {'is_synced': 1, 'transaction_id': result['transaction_id']});
            if (result['payment_lines'] != null) {
              // Delete existing payment lines
              await PurchaseDatabase()
                  .deletePurchasePaymentsByPurchaseId(element['id']);
              // Update paymentId for each purchase payment
              result['payment_lines'].forEach((paymentLine) async {
                await PurchaseDatabase().storePurchasePayment({
                  'purchase_id': element['id'],
                  'method': paymentLine['method'],
                  'amount': paymentLine['amount'],
                  'note': paymentLine['note'],
                  'payment_id': paymentLine['id'],
                  'paid_on': paymentLine['paid_on'],
                  'account_id': paymentLine['account_id']
                });
              });
            }
          }
        }
      }
    });
    return true;
  }

  // Create purchase map
  Future<Map<String, dynamic>> createPurchase(
      {String? refNo,
      String? transactionDate,
      int? contactId,
      int? locId,
      int? taxId,
      String? discountType,
      double? discountAmount,
      double? totalBeforeTax,
      double? taxAmount,
      double? finalTotal,
      String? additionalNotes,
      double? shippingCharges,
      String? shippingDetails,
      String? status,
      int? purchaseId}) async {
    Map<String, dynamic> purchase;
    if (purchaseId == null) {
      purchase = {
        'transaction_date': transactionDate,
        'ref_no': refNo,
        'contact_id': contactId,
        'location_id': locId,
        'status': status,
        'tax_id': taxId,
        'discount_amount': discountAmount ?? 0.00,
        'discount_type': discountType,
        'total_before_tax': totalBeforeTax,
        'tax_amount': taxAmount ?? 0.00,
        'final_total': finalTotal,
        'additional_notes': additionalNotes,
        'shipping_charges': shippingCharges ?? 0.00,
        'shipping_details': shippingDetails,
        'is_synced': 0,
      };
      return purchase;
    } else {
      purchase = {
        'contact_id': contactId,
        'transaction_date': transactionDate,
        'location_id': locId,
        'status': status,
        'tax_id': taxId,
        'discount_amount': discountAmount ?? 0.00,
        'discount_type': discountType,
        'total_before_tax': totalBeforeTax,
        'tax_amount': taxAmount ?? 0.00,
        'final_total': finalTotal,
        'additional_notes': additionalNotes,
        'shipping_charges': shippingCharges ?? 0.00,
        'shipping_details': shippingDetails,
        'is_synced': 0,
      };
      return purchase;
    }
  }

  // Add to purchase lines
  addToPurchaseLines(product, purchaseId) async {
    var purchaseLine = {
      'purchase_id': purchaseId,
      'product_id': product['product_id'],
      'variation_id': product['variation_id'],
      'quantity': product['quantity'] ?? 1,
      'unit_price': product['unit_price'],
      'line_discount_amount': product['line_discount_amount'] ?? 0.00,
      'line_discount_type': product['line_discount_type'] ?? 'fixed',
      'item_tax_id': product['item_tax_id'],
      'item_tax': product['item_tax'] ?? 0.00,
      'sub_unit_id': product['sub_unit_id'],
      'lot_number': product['lot_number'],
      'mfg_date': product['mfg_date'],
      'exp_date': product['exp_date'],
      'purchase_order_line_id': product['purchase_order_line_id'],
      'purchase_requisition_line_id': product['purchase_requisition_line_id'],
    };

    await PurchaseDatabase().storePurchaseLine(purchaseLine);
  }

  // Reset purchase lines
  resetPurchaseLines() async {
    await PurchaseDatabase()
        .deletePurchaseLinesByPurchaseId(null); // Delete incomplete lines
  }

  Future<String> purchaseLinesCount({purchaseId}) async {
    return await PurchaseDatabase().countPurchaseLines(purchaseId: purchaseId);
  }

  // Create purchase map from API response
  Map<String, dynamic> createPurchaseMap(Map purchaseData) {
    Map<String, dynamic> purchase = {
      'transaction_date': purchaseData['transaction_date'],
      'ref_no': purchaseData['ref_no'],
      'contact_id': purchaseData['contact_id'],
      'location_id': purchaseData['location_id'],
      'status': purchaseData['status'],
      'tax_id': purchaseData['tax_id'],
      'discount_amount': purchaseData['discount_amount'] ?? 0.00,
      'discount_type': purchaseData['discount_type'],
      'total_before_tax': purchaseData['total_before_tax'],
      'tax_amount': purchaseData['tax_amount'] ?? 0.00,
      'final_total': purchaseData['final_total'],
      'additional_notes': purchaseData['additional_notes'],
      'shipping_charges': purchaseData['shipping_charges'] ?? 0.00,
      'shipping_details': purchaseData['shipping_details'],
      'is_synced': 1,
      'transaction_id': purchaseData['id'],
    };
    return purchase;
  }
}
