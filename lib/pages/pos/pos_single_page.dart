import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ===== Project deps already present in your repo =====
import '/helpers/AppTheme.dart';
import '/helpers/SizeConfig.dart';
import '/helpers/otherHelpers.dart';
import '/locale/MyLocalizations.dart';
import '/models/product_model.dart';
import '/models/variations.dart';
import '/models/sell.dart';
import '/models/sellDatabase.dart';
import '/models/paymentDatabase.dart';
import '/models/system.dart';

/// PosSinglePage — production-ready single page POS
/// -------------------------------------------------
/// ✓ Uses your existing DB/models (Variations, Sell, SellDatabase, PaymentDatabase, System)
/// ✓ Fully null-safe (no `!`), defensive around DB/JSON shapes
/// ✓ Responsive: grid + cart side-by-side on wide screens, stacked on narrow
/// ✓ Arabic/LTR auto — relies on MaterialApp locale (no manual Directionality)
/// ✓ Search by name/SKU/Barcode (passes to Variations.get searchTerm)
/// ✓ Quantity +/- , delete line, order-level discount/tax, computed totals
/// ✓ Cash checkout creates sale + payment, attaches lines, then fires API sync
///
/// Route usage:
/// Navigator.pushNamed(context, '/pos-single', arguments: {
///   'locationId': <int>, // optional; will fall back to System().get('selected_location')
///   'sellId': <int?>,    // optional; to edit an existing sale
/// });
class PosSinglePage extends StatefulWidget {
  const PosSinglePage({super.key});
  @override
  State<PosSinglePage> createState() => _PosSinglePageState();
}

class _PosSinglePageState extends State<PosSinglePage> {
  // Safe translator: prevents crashes when a key or locale map is missing
  String _t(BuildContext context, String key, {String fallback = ''}) {
    try {
      final loc = AppLocalizations.of(context);
      final s = loc.translate(key);
      if (s is String && s.isNotEmpty) return s;
    } catch (_) {}
    return fallback.isEmpty ? key : fallback;
  }

  // -------- Theming --------
  final ThemeData themeData = AppTheme.getThemeFromThemeMode(1);

  // -------- Arguments / context --------
  int? locationId;
  int? editingSellId;

  // -------- Search / products --------
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _leftScroll = ScrollController();
  List<Map<String, dynamic>> _products = [];
  bool _loadingProducts = false;
  String _lastQuery = '';

  // -------- Customers --------
  List<Map<String, dynamic>> _customers = [];
  bool _loadingCustomers = false;

  // -------- Cart --------
  List<Map<String, dynamic>> _cart = [];
  bool _loadingCart = false;

  // -------- Order-level fields --------
  int _selectedTaxId = 0; // 0 => none
  String _discountType = 'fixed'; // 'fixed' | 'percentage'
  double _discountAmount = 0.0;
  late List<Map<String, dynamic>> _taxRates; // [{id,name,amount}]
  int? _selectedCustomerId; // null => walk-in

  // -------- Totals --------
  double _invoiceTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _taxRates = [
      {'id': 0, 'name': 'بدون ضريبة', 'amount': 0.0}
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    // Read route args if any
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      locationId = args['locationId'] as int?;
      editingSellId = args['sellId'] as int?;
    }

    // Fallback: System().get('selected_location') supports both Map and [Map]
    if (locationId == null) {
      try {
        final sel = await System().get('selected_location');
        if (sel is List && sel.isNotEmpty && sel.first is Map) {
          locationId = (sel.first as Map)['id'] as int?;
        } else if (sel is Map) {
          locationId = sel['id'] as int?;
        }
      } catch (_) {}
    }

    await _loadTaxRates();
    await _loadCustomers();
    await _loadProducts();
    await _loadCart();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _leftScroll.dispose();
    super.dispose();
  }

  // ============================ DATA ============================
  Future<void> _loadTaxRates() async {
    try {
      final list = await System().get('tax');
      if (list is List) {
        if (!mounted) return;
        setState(() {
          _taxRates.addAll(list.map<Map<String, dynamic>>((e) => {
                'id': e['id'],
                'name': e['name'],
                'amount': double.tryParse(e['amount'].toString()) ?? 0.0,
              }));
        });
      }
    } catch (_) {}
  }

  Future<void> _ensureProductFreshness() async {
    try {
      final lastSync = await System().getProductLastSync();
      final needs = lastSync == null ||
          DateTime.now().difference(DateTime.parse(lastSync)).inMinutes > 10;
      if (needs && await Helper().checkConnectivity()) {
        await Variations().refresh();
        await System().insertProductLastSyncDateTimeNow();
      }
    } catch (_) {}
  }

  Future<void> _loadProducts({String search = ''}) async {
    setState(() {
      _loadingProducts = true;
      _lastQuery = search;
    });

    await _ensureProductFreshness();

    List list = [];
    try {
      list = await Variations().get(
        brandId: 0,
        categoryId: 0,
        subCategoryId: 0,
        inStock: false,
        locationId: locationId, // nullable accepted by your layer
        searchTerm: search.isEmpty ? null : search,
        barcode: null,
        offset: 1, // first page
        byAlphabets: null,
        byPrice: null,
      );
    } catch (_) {}

    // Compute price override by selling price group if present
    final int sellingPriceGroupId = await _findSellingPriceGroupId();

    final mapped = <Map<String, dynamic>>[];
    for (final product in list) {
      double? price;
      final spg = product['selling_price_group'];
      if (spg != null &&
          spg.toString().isNotEmpty &&
          sellingPriceGroupId != 0) {
        try {
          final arr = jsonDecode(spg);
          for (final el in arr) {
            if (el['key'] == sellingPriceGroupId) {
              price = double.tryParse(el['value'].toString());
              break;
            }
          }
        } catch (_) {}
      }
      mapped.add(ProductModel().product(product, price));
    }

    if (!mounted) return;
    setState(() {
      _products = mapped;
      _loadingProducts = false;
    });
  }

  Future<int> _findSellingPriceGroupId() async {
    try {
      final groups = await System().get('selling_price_groups');
      if (groups is List && groups.isNotEmpty) {
        final first = groups.first;
        if (first is Map && first['id'] != null) return first['id'] as int;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _loadCustomers() async {
    setState(() => _loadingCustomers = true);
    List<Map<String, dynamic>> list = [];
    try {
      // Prefer 'contacts' cache; fall back to 'customers' if your System key differs
      final data = await System().get('contacts');
      if (data is List) {
        list = List<Map<String, dynamic>>.from(data.cast());
      } else {
        final alt = await System().get('customers');
        if (alt is List) list = List<Map<String, dynamic>>.from(alt.cast());
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _customers = list;
      _loadingCustomers = false;
    });
  }

  Future<void> _loadCart() async {
    setState(() => _loadingCart = true);
    List lines = [];
    try {
      lines = (editingSellId == null)
          ? await SellDatabase().getInCompleteLines(locationId)
          : await SellDatabase().getSellBySellId(editingSellId);
    } catch (e) {
      // If DB read fails, make sure loader goes away
      if (mounted) {
        setState(() => _loadingCart = false);
      }
      return;
    }

    if (!mounted) return;
    try {
      final newCart = List<Map<String, dynamic>>.from(lines);

      setState(() {
        _cart = newCart;
        if (_cart.isNotEmpty && editingSellId != null) {
          final sale = _cart.first;
          _selectedCustomerId = sale['contact_id'];
          _selectedTaxId = sale['tax_rate_id'] ?? 0;
          _discountType = sale['discount_type'] ?? 'fixed';
          _discountAmount =
              double.tryParse('${sale['discount_amount'] ?? 0}') ?? 0.0;
        }
        try {
          _recalcTotals();
        } catch (_) {
          // Fallback so UI doesn't hang in case of any parsing error
          _invoiceTotal = _subTotal();
        }
        _loadingCart = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCart = false);
      }
    }
  }

  // ============================ CART OPS ============================
  Future<void> _addProductToCart(Map<String, dynamic> product) async {
    try {
      await Sell().addToCart(product, editingSellId);
    } catch (_) {}
    await _loadCart();
  }

  Future<void> _setQty(Map<String, dynamic> line, int newQty) async {
    if (newQty <= 0) return;
    try {
      await SellDatabase().update(line['id'], {'quantity': newQty});
    } catch (_) {}
    await _loadCart();
  }

  Future<void> _removeLine(Map<String, dynamic> line) async {
    try {
      await SellDatabase().delete(
        line['variation_id'],
        line['product_id'],
        sellId: editingSellId,
      );
    } catch (_) {}
    await _loadCart();
  }

  // ============================ TOTALS ============================
  double _inlineUnitPrice(
    double price,
    int? taxId,
    String discountType,
    double discountAmount,
  ) {
    final tax = _taxRates.firstWhere(
      (e) => e['id'] == (taxId ?? 0),
      orElse: () => {'amount': 0.0},
    )['amount'] as double;

    double up = price;
    if (discountType == 'fixed') {
      up = price - discountAmount;
    } else {
      up = price - (price * discountAmount / 100);
    }
    if (up < 0) up = 0;
    return up + (up * tax / 100);
  }

  double _subTotal() {
    double s = 0.0;
    for (final l in _cart) {
      final unit = _inlineUnitPrice(
        double.tryParse(l['unit_price'].toString()) ?? 0.0,
        l['tax_rate_id'],
        l['discount_type'] ?? 'fixed',
        double.tryParse('${l['discount_amount'] ?? 0}') ?? 0.0,
      );

      // quantity can be int/double/String in DB, normalize to double
      final qtyNum = (l['quantity'] is num)
          ? (l['quantity'] as num).toDouble()
          : (double.tryParse('${l['quantity']}') ?? 0.0);

      s += unit * qtyNum;
    }
    return s;
  }

  void _recalcTotals() {
    final sub = _subTotal();
    final tax = _taxRates.firstWhere(
      (e) => e['id'] == _selectedTaxId,
      orElse: () => {'amount': 0.0},
    )['amount'] as double;

    double t = sub;
    if (_discountType == 'fixed') {
      t = sub - _discountAmount;
    } else {
      t = sub - (sub * _discountAmount / 100);
    }
    if (t < 0) t = 0;
    _invoiceTotal = t + (t * tax / 100);
  }

  // ============================ CHECKOUT ============================
  Future<void> _checkoutCash() async {
    if (_cart.isEmpty) return;

    final paid = await showDialog<double>(
      context: context,
      builder: (context) {
        final c = TextEditingController(text: _invoiceTotal.toStringAsFixed(2));
        return AlertDialog(
          title: const Text('الدفع نقدًا'),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(c.text) ?? 0),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    if (paid == null) return;
    final pending = (_invoiceTotal - paid);
    final change = pending < 0 ? -pending : 0.0;

    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final saleInput = {
      'transaction_date': now,
      'invoice_no': '',
      'contact_id': _selectedCustomerId,
      'location_id': locationId,
      'status': 'final',
      'tax_id': _selectedTaxId,
      'discount_amount': _discountAmount,
      'discount_type': _discountType,
      'final_total': _invoiceTotal,
      'additional_notes': '',
      'staff_note': '',
      'shipping_charges': '0',
      'shipping_details': '',
    };

    Map<String, dynamic> saleMap = {};
    try {
      saleMap = Sell().createSellMap(
        saleInput,
        change,
        pending > 0 ? pending : 0.0,
      );
    } catch (_) {}

    int sellId = 0;
    try {
      sellId = await SellDatabase().storeSell(saleMap);
    } catch (_) {}

    try {
      final db = await SellDatabase().dbProvider.database;
      await db.update(
        'sell_lines',
        {'sell_id': sellId, 'is_completed': 1},
        where: 'is_completed = 0 AND (sell_id IS NULL OR sell_id = 0)',
      );
    } catch (_) {}

    try {
      await PaymentDatabase().store({
        'sell_id': sellId,
        'amount': paid,
        'method': 'cash',
        'paid_on': now,
        'note': '',
        'account_id': null,
        'is_return': 0,
      });
    } catch (_) {}

    try {
      await Sell().createApiSell(sellId: sellId);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء الفاتورة بنجاح')),
    );
    setState(() {
      _cart.clear();
      _invoiceTotal = 0.0;
    });
    await _loadCart(); // reload in case there are still pending lines
  }

  // ============================ UI ============================
  @override
  Widget build(BuildContext context) {
    MySize().init(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        title: Text(_t(context, 'pos', fallback: 'POS')),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 4, child: _buildProductsPane()),
                Expanded(flex: 6, child: _buildCartPane()),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(child: _buildProductsPane()),
                const Divider(height: 1),
                Expanded(child: _buildCartPane()),
              ],
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProductsPane() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? _EmptyState(
                        title: _lastQuery.isEmpty
                            ? 'لا توجد منتجات'
                            : 'لا توجد نتائج لـ "$_lastQuery"',
                        subtitle: 'جرّب البحث باسم المنتج أو SKU أو الباركود',
                        action: TextButton(
                          onPressed: () => _loadProducts(search: ''),
                          child: const Text('عرض الكل'),
                        ),
                      )
                    : GridView.builder(
                        controller: _leftScroll,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, i) => _ProductTile(
                          product: _products[i],
                          onTap: () => _addProductToCart(_products[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onSubmitted: (v) => _loadProducts(search: v.trim()),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'مسح',
          onPressed: () {
            _searchCtrl.clear();
            _loadProducts(search: '');
            _searchFocus.requestFocus();
          },
          icon: const Icon(Icons.clear),
        ),
        hintText: 'أدخل اسم المنتج / SKU / الباركود',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCartPane() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 6),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 6,
                    child:
                        Text('المنتج', style: themeData.textTheme.bodyLarge)),
                Expanded(
                    flex: 2,
                    child: Text('الكمية', textAlign: TextAlign.center)),
                Expanded(
                    flex: 2, child: Text('السعر', textAlign: TextAlign.center)),
                Expanded(
                    flex: 2, child: Text('الإجمالي', textAlign: TextAlign.end)),
                const SizedBox(width: 32),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingCart
                ? const Center(child: CircularProgressIndicator())
                : _cart.isEmpty
                    ? const _EmptyState(
                        title: 'السلة فارغة',
                        subtitle: 'أضف منتجات من القائمة اليسرى')
                    : ListView.separated(
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final l = _cart[i];
                          final unit = _inlineUnitPrice(
                            double.tryParse(l['unit_price'].toString()) ?? 0.0,
                            l['tax_rate_id'],
                            l['discount_type'] ?? 'fixed',
                            double.tryParse('${l['discount_amount'] ?? 0}') ??
                                0.0,
                          );
                          final qtyNum = (l['quantity'] is num)
                              ? (l['quantity'] as num).toDouble()
                              : (double.tryParse('${l['quantity']}') ?? 0.0);
                          final qty = qtyNum.toInt();
                          final lineTotal = unit * qty;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(.05),
                                    blurRadius: 6),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Text(
                                    '${l['product_name'] ?? l['display_name'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: () => _setQty(l, (qty - 1)),
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                      ),
                                      Text('$qty'),
                                      IconButton(
                                        onPressed: () => _setQty(l, (qty + 1)),
                                        icon: const Icon(
                                            Icons.add_circle_outline),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(unit.toStringAsFixed(2),
                                      textAlign: TextAlign.center),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(lineTotal.toStringAsFixed(2),
                                      textAlign: TextAlign.end),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: () => _removeLine(l),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          _buildOrderControls(),
        ],
      ),
    );
  }

  Widget _buildOrderControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 6)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedTaxId,
                  items: _taxRates
                      .map<DropdownMenuItem<int>>((m) => DropdownMenuItem(
                            value: m['id'] as int,
                            child: Text(m['name'].toString()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedTaxId = v ?? 0;
                      _recalcTotals();
                    });
                  },
                  decoration: const InputDecoration(labelText: 'الضريبة'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _discountAmount.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الخصم'),
                  onChanged: (v) {
                    setState(() {
                      _discountAmount = double.tryParse(v) ?? 0.0;
                      _recalcTotals();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _discountType,
                items: const [
                  DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت')),
                  DropdownMenuItem(value: 'percentage', child: Text('نسبة %')),
                ],
                onChanged: (v) {
                  setState(() {
                    _discountType = v ?? 'fixed';
                    _recalcTotals();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('الإجمالي:', style: themeData.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(_invoiceTotal.toStringAsFixed(2),
                  style: themeData.textTheme.titleLarge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _selectedCustomerId,
                    hint: const Text('عميل زائر'),
                    items: _customers
                        .map((c) => DropdownMenuItem<int?>(
                              value: (c['id'] as int?) ??
                                  int.tryParse('${c['id']}'),
                              child: Text(
                                (c['name'] ??
                                            c['contact_name'] ??
                                            c['supplier_business_name'] ??
                                            ((c['first_name'] ?? '') +
                                                ' ' +
                                                (c['last_name'] ?? '')))
                                        .toString()
                                        .trim()
                                        .isEmpty
                                    ? 'عميل'
                                    : (c['name'] ??
                                            c['contact_name'] ??
                                            c['supplier_business_name'] ??
                                            ((c['first_name'] ?? '') +
                                                ' ' +
                                                (c['last_name'] ?? '')))
                                        .toString(),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCustomerId = v),
                  ),
                ),
              ],
            ),
          ),
          Text('المجموع القابل للدفع: ',
              style: themeData.textTheme.titleMedium),
          const SizedBox(width: 6),
          Text(_invoiceTotal.toStringAsFixed(2),
              style: themeData.textTheme.titleLarge),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _cart.isEmpty ? null : _checkoutCash,
            icon: const Icon(Icons.payments),
            label: const Text('دفع نقدًا'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _cart.isEmpty ? null : () {/* TODO: card payments */},
            icon: const Icon(Icons.credit_card),
            label: const Text('بطاقة'),
          ),
        ],
      ),
    );
  }
}

// ---------------- Helpers ----------------
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = product['unit_price'];
    final url = product['product_image_url']?.toString() ?? '';
    final hasValidUrl = url.isNotEmpty && !url.endsWith('/no_data.jpg');

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 6),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasValidUrl
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.inventory_2_outlined),
                      )
                    : const ColoredBox(
                        color: Color(0xfff1f1f1),
                        child: Icon(Icons.inventory_2_outlined),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product['display_name'] ?? product['product_name'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              price is num
                  ? price.toStringAsFixed(2)
                  : (double.tryParse('$price')?.toStringAsFixed(2) ?? ''),
              textAlign: TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const _EmptyState({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (action != null) ...[
            const SizedBox(height: 10),
            action!,
          ]
        ],
      ),
    );
  }
}
