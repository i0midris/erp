// lib/models/invoice.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/paymentDatabase.dart';
import '../models/qr.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'contact_model.dart';

/// ---------- Safe helpers ----------
String _toAsciiDigits(String s) {
  // Arabic & Persian digits -> ASCII
  const map = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };
  for (final e in map.entries) {
    s = s.replaceAll(e.key, e.value);
  }
  return s;
}

double _toDouble(Object? v, [double def = 0]) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  var s = _toAsciiDigits(v.toString().trim());
  s = s.replaceAll('\u066B', '.'); // Arabic decimal sep
  s = s.replaceAll(RegExp(r'[,\u066C]'), ''); // thousands (comma, Arabic)
  return double.tryParse(s) ?? def;
}

DateTime _parseDateSafe(Object? v) {
  if (v is DateTime) return v;
  var s = _toAsciiDigits((v ?? '').toString().trim())
      .replaceAll('/', '-')
      .replaceAll('\u200f', '')
      .replaceAll('\u202A', '')
      .replaceAll('\u202C', '');
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  for (final p in const [
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd',
    'dd-MM-yyyy HH:mm:ss',
    'dd-MM-yyyy HH:mm',
    'dd-MM-yyyy',
  ]) {
    try {
      return DateFormat(p, 'en').parse(s);
    } catch (_) {}
  }
  return DateTime.now();
}

/// ===================================

class InvoiceFormatter {
  double subTotal = 0;
  String taxName = 'taxRates';
  double inlineDiscountAmount = 0.0, inlineTaxAmount = 0.0, tax = 0;

  Future<void> _loadTax(dynamic taxId) async {
    if (taxId == null) {
      taxName = 'taxRates';
      tax = 0;
      return;
    }
    final list = await System().get('tax');
    for (final element in list) {
      if (element['id'] == taxId) {
        taxName = element['name']?.toString() ?? 'tax';
        tax = _toDouble(element['amount']);
        break;
      }
    }
  }

  Future<String> generateProductDetails(sellId, context) async {
    // Reset numbers for this invoice
    subTotal = 0.0;
    inlineDiscountAmount = 0.0;
    inlineTaxAmount = 0.0;

    // Fetch lines
    final List products = await SellDatabase().get(sellId: sellId);

    String rows = '''
      <tr class="bb-lg">
         <th width="30%"><p>${AppLocalizations.of(context).translate('products')}</p></th>
         <th width="20%"><p>${AppLocalizations.of(context).translate('quantity')}</p></th>
         <th width="20%"><p>${AppLocalizations.of(context).translate('unit_price')}</p></th>
         <th width="20%"><p>${AppLocalizations.of(context).translate('sub_total')}</p></th>
      </tr>
    ''';

    for (int i = 0; i < products.length; i++) {
      final name = products[i]['name']?.toString() ?? '';
      final sku = products[i]['sub_sku']?.toString() ?? '';

      // quantity (string for formatter + numeric for math)
      final qtyStr = products[i]['quantity'].toString();
      final qtyNum = _toDouble(products[i]['quantity']);

      // per-line inline tax/discount calculation
      final inlineAmounts = await Helper().calculateTaxAndDiscount(
        discountAmount: products[i]['discount_amount'],
        discountType: products[i]['discount_type'],
        unitPrice: products[i]['unit_price'],
        taxId: products[i]['tax_rate_id'],
      );
      inlineDiscountAmount += _toDouble(inlineAmounts['discountAmount']);
      inlineTaxAmount += _toDouble(inlineAmounts['taxAmount']);

      // Unit price including its inline tax/discount (your helper returns a string)
      final unitPriceStr = await Helper().calculateTotal(
        taxId: products[i]['tax_rate_id'],
        discountAmount: products[i]['discount_amount'],
        discountType: products[i]['discount_type'],
        unitPrice: products[i]['unit_price'],
      );
      final unitPrice = _toDouble(unitPriceStr);

      final lineTotal = qtyNum * unitPrice;
      subTotal += lineTotal;

      rows += '''
        <tr class="bb-lg">
          <td width="30%"><p>$name, $sku</p></td>
          <td width="20%"><p>${Helper().formatQuantity(qtyStr)}</p></td>
          <td width="20%"><p>${Helper().formatCurrency(unitPrice)}</p></td>
          <td width="20%"><p>${Helper().formatCurrency(lineTotal)}</p></td>
        </tr>
      ''';
    }

    return rows;
  }

  /// Returns numeric amounts; only format at render.
  Map<String, dynamic> getTotalAmount({
    required String discountType,
    required double discountAmount,
    required String symbol, // kept to preserve label text
  }) {
    final out = <String, dynamic>{};
    double tAmount;
    if (discountType == 'fixed') {
      tAmount = subTotal - discountAmount;
      out['discountAmount'] = discountAmount;
      out['discountType'] = "$symbol $discountAmount";
    } else if (discountType == 'percentage') {
      final disc = subTotal * (discountAmount / 100.0);
      tAmount = subTotal - disc;
      out['discountAmount'] = disc;
      out['discountType'] = "$discountAmount %";
    } else {
      tAmount = subTotal;
      out['discountAmount'] = 0.0;
      out['discountType'] = '';
    }

    final taxAmount = tAmount * (tax / 100.0);
    out['taxAmount'] = taxAmount;
    out['totalAmount'] = tAmount + taxAmount;
    return out;
  }

  Future<String> generateInvoice(sellId, taxId, context) async {
    await _loadTax(taxId);

    // Build product table & collect totals
    final productsHtml = await generateProductDetails(sellId, context);

    // Core data
    final List sells = await SellDatabase().getSellBySellId(sellId);
    final sell = sells.first;

    final customer = await Contact().getCustomerDetailById(sell['contact_id']);

    // Location details
    final List locations = await System().get('location');
    Map<String, dynamic>? location;
    for (final e in locations) {
      if (e['id'] == sell['location_id']) {
        location = Map<String, dynamic>.from(e);
        break;
      }
    }

    final landmark = (location?['landmark'] ?? '').toString().trim();
    final city = (location?['city'] ?? '').toString().trim();
    final state = (location?['state'] ?? '').toString().trim();
    final zipCode = (location?['zip_code'] ?? '').toString().trim();
    final country = (location?['country'] ?? '').toString().trim();
    final businessMobile = (location?['mobile'] ?? '').toString().trim();

    final invoiceNo = sell['invoice_no']?.toString() ?? '';
    final dateTime = _parseDateSafe(sell['transaction_date']);
    final dateStr = DateFormat("dd/MM/yyyy").format(dateTime);

    // Business details
    final biz = await Helper().getFormattedBusinessDetails();
    final symbol = (biz['symbol'] ?? '').toString();
    final business = (biz['name'] ?? '').toString();
    final taxLabel = (biz['taxLabel'] ?? '').toString();
    final taxNumber = (biz['taxNumber'] ?? '').toString();

    // Customer details
    final customerName = (customer['name'] ?? '').toString();
    final customerAddress1 =
        (customer['address_line_1'] ?? '').toString().trim();
    final customerAddress2 =
        (customer['address_line_2'] ?? '').toString().trim();
    final customerCity = (customer['city'] ?? '').toString().trim();
    final customerState = (customer['state'] ?? '').toString().trim();
    final customerCountry = (customer['country'] ?? '').toString().trim();
    final customerMobile = (customer['mobile'] ?? '').toString().trim();

    // Payments
    final List paymentList =
        await PaymentDatabase().get(sell['id'], allColumns: true);
    double totalPaidAmount = 0.0;
    String paymentsHtml = '';
    for (final element in paymentList) {
      final amt = _toDouble(element['amount']);
      if (amt <= 0) continue;
      final isReturn = element['is_return'] == 1;
      final sign = isReturn ? '-' : '+';
      totalPaidAmount += isReturn ? -amt : amt;
      final method = element['method']?.toString() ?? '';
      paymentsHtml += '''
        <div class="flex-box">
          <p class="width-50 text-left">$method ($sign) ($dateStr)</p>
          <p class="width-50 text-right">$symbol ${Helper().formatCurrency(amt)}</p>
        </div>
      ''';
    }

    // Totals (numeric)
    var discountType = (sell['discount_type'] ?? '').toString();
    var discountAmount = _toDouble(sell['discount_amount']);

    final amounts = getTotalAmount(
      discountType: discountType,
      discountAmount: discountAmount,
      symbol: symbol,
    );

    discountAmount = _toDouble(amounts['discountAmount']);
    discountType = amounts['discountType']?.toString() ?? '';
    final taxAmountNum = _toDouble(amounts['taxAmount']);
    final shipping = _toDouble(sell['shipping_charges']);
    final totalAmountNum = _toDouble(amounts['totalAmount']) + shipping;
    final sTotalNum = subTotal;

    // Due/Return logic
    double totalReceivedNum = totalPaidAmount;
    double returnAmountNum = 0.0;
    double dueAmountNum = 0.0;

    if (totalPaidAmount > totalAmountNum) {
      returnAmountNum = totalPaidAmount - totalAmountNum;
      totalReceivedNum = totalAmountNum;
    } else if (totalAmountNum > totalPaidAmount) {
      dueAmountNum = totalAmountNum - totalPaidAmount;
    }

    // Build optional rows
    String discountHtml = '';
    if (discountAmount > 0) {
      discountHtml = '''
        <div class="flex-box">
          <p class="width-50 text-left">
            ${AppLocalizations.of(context).translate('discount')} <small>($discountType)</small> :
          </p>
          <p class="width-50 text-right">(-) $symbol ${Helper().formatCurrency(discountAmount)}</p>
        </div>
      ''';
    }

    String inlineDiscountHtml = '';
    if (inlineDiscountAmount > 0) {
      inlineDiscountHtml = '''
        <div class="flex-box">
          <p class="width-50 text-left">${AppLocalizations.of(context).translate('discount')} :</p>
          <p class="width-50 text-right">(-) $symbol ${Helper().formatCurrency(inlineDiscountAmount)}</p>
        </div>
      ''';
    }

    String shippingHtml = '';
    if (shipping >= 0.01) {
      shippingHtml = '''
        <div class="flex-box">
          <p class="width-50 text-left">${AppLocalizations.of(context).translate('shipping_charges')}:</p>
          <p class="width-50 text-right">$symbol ${Helper().formatCurrency(shipping)}</p>
        </div>
      ''';
    }

    String taxHtml = '';
    if (taxName != 'taxRates') {
      taxHtml = '''
        <div class="flex-box">
          <p class="width-50 text-left">${AppLocalizations.of(context).translate('tax')} ($taxName):</p>
          <p class="width-50 text-right">(+) $symbol ${Helper().formatCurrency(taxAmountNum)}</p>
        </div>
      ''';
    }

    String inlineTaxesHtml = '';
    if (inlineTaxAmount > 0) {
      inlineTaxesHtml = '''
        <div class="flex-box">
          <p class="width-50 text-left">${AppLocalizations.of(context).translate('tax')} :</p>
          <p class="width-50 text-right">(+) $symbol ${Helper().formatCurrency(inlineTaxAmount)}</p>
        </div>
      ''';
    }

    String dueHtml = '';
    if (dueAmountNum > 0) {
      dueHtml = '''
        <div class="flex-box">
          <p class="width-50 text-left">
            ${AppLocalizations.of(context).translate('total')} ${AppLocalizations.of(context).translate('due')}
          </p>
          <p class="width-50 text-right">$symbol ${Helper().formatCurrency(dueAmountNum)}</p>
        </div>
      ''';
    }

    // Strings for QR (if you enable it)
    final addressStr = '${[
      customerAddress1,
      customerAddress2,
      customerCity,
      customerState,
      customerCountry
    ].where((s) => s.isNotEmpty).join(' ')}';
    final totalTaxStr = (inlineTaxAmount + taxAmountNum).toStringAsFixed(2);
    final totalDiscountStr =
        (inlineDiscountAmount + discountAmount).toStringAsFixed(2);

    // --- QR (optional) ---
    // Uint8List qr = await QR().getQrData(
    //   symbol: symbol,
    //   address: addressStr,
    //   businessName: business,
    //   context: context,
    //   customer: customerName,
    //   date: dateTime,
    //   discount: totalDiscountStr,
    //   invoiceNo: invoiceNo,
    //   subTotal: sTotalNum,
    //   tax: totalTaxStr,
    //   taxLabel: taxLabel,
    //   taxNumber: taxNumber,
    //   total: totalAmountNum,
    // );
    // String base64Image = base64Encode(qr);

    // HTML
    final invoice = '''
<section class="invoice print_section" id="receipt_section">
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Receipt-$invoiceNo</title>

<div class="ticket">
  <div class="text-box">
    <p class="centered">
      <span class="headings">$business</span><br>
      ${[
      landmark,
      city,
      state,
      zipCode,
      country,
      businessMobile
    ].where((s) => s.isNotEmpty).join(' ')}<br>
      <b>$taxLabel</b> $taxNumber
    </p>
  </div>

  <div class="border-top textbox-info">
    <p class="f-left"><strong>${AppLocalizations.of(context).translate('invoice_no')}</strong>&nbsp;&nbsp;$invoiceNo</p>
  </div>
  <div class="textbox-info">
    <p class="f-left"><strong>${AppLocalizations.of(context).translate('date')}</strong>&nbsp;&nbsp;$dateStr</p>
  </div>

  <div class="textbox-info">
    <p style="vertical-align: top;"><strong>${AppLocalizations.of(context).translate('customer')}</strong></p>
    <p>$customerName</p>
    <div class="bw">${[
      customerAddress1,
      customerAddress2,
      customerCity,
      customerState,
      customerCountry
    ].where((s) => s.isNotEmpty).join(' ')}<br>$customerMobile</div>
    <p></p>
  </div>

  <div class="bb-lg mb-10"></div>

  <table style="padding-top: 5px !important" class="border-bottom width-100 table-f-12 mb-10">
    <tbody>
      $productsHtml
    </tbody>
  </table>

  <div class="flex-box">
    <p class="left text-left"><strong>${AppLocalizations.of(context).translate('sub_total')}:</strong></p>
    <p class="width-50 text-right"><strong>$symbol ${Helper().formatCurrency(sTotalNum)}</strong></p>
  </div>

  $shippingHtml
  $discountHtml
  $inlineDiscountHtml
  $taxHtml
  $inlineTaxesHtml

  <div class="flex-box">
    <p class="width-50 text-left"><strong>${AppLocalizations.of(context).translate('total')}:</strong></p>
    <p class="width-50 text-right"><strong>$symbol ${Helper().formatCurrency(totalAmountNum)}</strong></p>
  </div>

  $paymentsHtml

  <div class="flex-box">
    <p class="width-50 text-left">${AppLocalizations.of(context).translate('total')} ${AppLocalizations.of(context).translate('paid')}</p>
    <p class="width-50 text-right">$symbol ${Helper().formatCurrency(totalReceivedNum)}</p>
  </div>

  $dueHtml

  <div class="border-bottom width-100">&nbsp;</div>
</div>

<style type="text/css">
  @media print {
    * { font-size: 12px; font-family: 'Times New Roman'; word-break: break-all; }
    .headings{ font-size: 16px; font-weight: 700; text-transform: uppercase; }
    .sub-headings{ font-size: 15px; font-weight: 700; }
    .border-top{ border-top: 1px solid #242424; }
    .border-bottom{ border-bottom: 1px solid #242424; }
    .border-bottom-dotted{ border-bottom: 1px dotted darkgray; }
    td.serial_number, th.serial_number{ width: 5%; max-width: 5%; }
    td.description, th.description { width: 35%; max-width: 35%; word-break: break-all; }
    td.quantity, th.quantity { width: 15%; max-width: 15%; word-break: break-all; }
    td.unit_price, th.unit_price{ width: 25%; max-width: 25%; word-break: break-all; }
    td.price, th.price { width: 20%; max-width: 20%; word-break: break-all; }
    .centered { text-align: center; align-content: center; }
    .ticket { width: 100%; max-width: 100%; }
    img { max-width: inherit; width: auto; }
    .hidden-print, .hidden-print * { display: none !important; }
  }
  .table-info { width: 100%; }
  .table-info tr:first-child td, .table-info tr:first-child th { padding-top: 8px; }
  .table-info th { text-align: left; }
  .table-info td { text-align: right; }
  .logo { float: left; width:35%; padding: 10px; }
  .text-with-image { float: left; width:65%; }
  .text-box { width: 100%; height: auto; }
  .m-0 { margin:0; }
  .textbox-info { clear: both; }
  .textbox-info p { margin-bottom: 0px }
  .flex-box { display: flex; width: 100%; }
  .flex-box p { width: 50%; margin-bottom: 0px; white-space: nowrap; }
  .table-f-12 th, .table-f-12 td { font-size: 12px; word-break: break-word; }
  .bw { word-break: break-word; }
  .bb-lg { border-bottom: 1px solid lightgray; }
</style>
</section>
    ''';

    return invoice;
  }
}
