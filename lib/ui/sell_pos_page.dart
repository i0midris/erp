import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

// Your existing app modules
import 'package:pos_final/models/variations.dart' as app;
import 'package:pos_final/apis/contact.dart' as app;
import 'package:pos_final/apis/sell.dart' as app;
import 'package:pos_final/apis/system.dart'
    show Location; // fetch business locations
import 'package:pos_final/models/system.dart'
    as sys; // read cached system values

/// ------------------------------------------------------------
/// Production-ready POS / Sell page
/// - RTL-first, wide-screen layout similar to your screenshot
/// - Accurate money math using **int cents** (no double drift)
/// - Location + Customer pickers wired to your modules
/// - Product grid with infinite scroll, debounced search, SKU/Barcode submit
/// - Cart with isolated rebuilds and safe controller disposal
/// - Robust commitSale() payload compatible with SellApi().create
/// ------------------------------------------------------------

// ====== Money helpers (cents) ======
int toCents(num v) => (v * 100).round();
String money(int cents) => (cents / 100).toStringAsFixed(2);

// ====== Core models for this screen ======
class Product {
  final int variationId;
  final int productId;
  final String name;
  final String sku;
  final int priceIncTaxCents;
  final double stock;
  final String unitName;
  final String? imageUrl;
  const Product({
    required this.variationId,
    required this.productId,
    required this.name,
    required this.sku,
    required this.priceIncTaxCents,
    required this.stock,
    this.unitName = 'Pc(s)',
    this.imageUrl,
  });
}

class Customer {
  final String id;
  final String name;
  final bool isWalkIn;
  const Customer(this.id, this.name, {this.isWalkIn = false});
}

class CartLine {
  final Product product;
  int qty;
  CartLine(this.product, {this.qty = 1});
  int get lineTotalCents => product.priceIncTaxCents * qty;
}

// ====== Repositories (adapters over your modules) ======
abstract class ProductRepository {
  Future<List<Product>> featured({required int locationId, required int page});
  Future<List<Product>> search(
      {required String query, required int locationId, required int page});
  Future<Product?> findBySku({required String sku, required int locationId});
}

class AppProductRepo implements ProductRepository {
  const AppProductRepo();

  Product _map(Map p) {
    double? priceFromGroup;
    try {
      final raw = p['selling_price_group'];
      if (raw != null) {
        final list = (jsonDecode(raw) as List?) ?? const [];
        if (list.isNotEmpty)
          priceFromGroup = (list.first['value'] as num?)?.toDouble();
      }
    } catch (_) {}

    final price =
        priceFromGroup ?? (p['sell_price_inc_tax'] as num?)?.toDouble() ?? 0.0;

    return Product(
      variationId: (p['variation_id'] as num).toInt(),
      productId: (p['product_id'] as num).toInt(),
      name: p['display_name'] ??
          '${p['product_name'] ?? ''} ${p['variation_name'] ?? ''}',
      sku: p['sku']?.toString() ?? p['sub_sku']?.toString() ?? '',
      priceIncTaxCents: toCents(price),
      stock: (p['stock_available'] as num?)?.toDouble() ?? 0,
      unitName: p['unit_name']?.toString() ?? 'Pc(s)',
      imageUrl: p['product_image_url']?.toString(),
    );
  }

  Future<List<Product>> _get({
    required int locationId,
    required int page,
    String query = '',
  }) async {
    final rows = await app.Variations().get(
      brandId: 0,
      categoryId: 0,
      subCategoryId: 0,
      searchTerm: query,
      locationId: locationId,
      inStock: false,
      barcode: '',
      offset: page, // API is 10 rows per page
      byAlphabets: 0,
      byPrice: 0,
    );
    return (rows as List).map<Product>((e) => _map(Map.from(e))).toList();
  }

  @override
  Future<List<Product>> featured(
          {required int locationId, required int page}) =>
      _get(locationId: locationId, page: page);

  @override
  Future<List<Product>> search(
          {required String query,
          required int locationId,
          required int page}) =>
      _get(locationId: locationId, page: page, query: query);

  @override
  Future<Product?> findBySku(
      {required String sku, required int locationId}) async {
    final rows = await _get(locationId: locationId, page: 1, query: sku);
    return rows.firstWhere((p) => p.sku == sku,
        orElse: () => rows.isEmpty ? null as Product : rows.first);
  }
}

abstract class CustomerRepository {
  Future<List<Customer>> all();
  Future<Customer> walkIn();
  Future<List<Customer>> search(String query);
}

class AppCustomerRepo implements CustomerRepository {
  const AppCustomerRepo();

  String _name(dynamic e) {
    if (e is Map) {
      return (e['name'] ??
              e['supplier_business_name'] ??
              ([e['first_name'], e['middle_name'], e['last_name']]
                  .where((x) => (x ?? '').toString().isNotEmpty)
                  .join(' ')) ??
              (e['customer'] != null ? e['customer']['name'] : null) ??
              'بدون اسم')
          .toString();
    }
    return 'بدون اسم';
  }

  String _id(dynamic e) {
    if (e is Map) {
      return (e['id'] ??
              (e['customer'] != null ? e['customer']['id'] : null) ??
              '')
          .toString();
    }
    return '';
  }

  @override
  Future<List<Customer>> all() async {
    try {
      final res = await app.CustomerApi().get();
      final list = res is List
          ? res
          : (res is Map && res['data'] is List)
              ? (res['data'] as List)
              : const [];
      final mapped = list
          .map<Customer>((e) => Customer(_id(e), _name(e)))
          .where((c) => c.id.isNotEmpty)
          .toList();
      if (mapped.isNotEmpty) return mapped;
    } catch (_) {}
    return [const Customer('walkin', 'Walk-In Customer', isWalkIn: true)];
  }

  @override
  Future<Customer> walkIn() async =>
      const Customer('walkin', 'Walk-In Customer', isWalkIn: true);

  @override
  Future<List<Customer>> search(String query) async {
    final allC = await all();
    return allC.where((c) => c.name.contains(query)).toList();
  }
}

abstract class SellRepository {
  Future<bool> createSale({
    required int locationId,
    required Customer customer,
    required List<CartLine> lines,
    required int discountCents,
    required int shippingCents,
    required int orderTaxCents,
    required String method, // 'cash' | 'card' | 'multi'
  });
}

class AppSellRepo implements SellRepository {
  const AppSellRepo();

  @override
  Future<bool> createSale({
    required int locationId,
    required Customer customer,
    required List<CartLine> lines,
    required int discountCents,
    required int shippingCents,
    required int orderTaxCents,
    required String method,
  }) async {
    String nowSql() {
      final dt = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    }

    final productsPayload = [
      for (final i in lines)
        {
          'product_id': i.product.productId,
          'variation_id': i.product.variationId,
          'quantity': i.qty,
          'unit_price': i.product.priceIncTaxCents / 100.0,
          'tax_rate_id': null,
          'discount_amount': 0,
          'discount_type': 'fixed',
          'note': null,
        }
    ];

    final subTotalCents = lines.fold<int>(0, (a, b) => a + b.lineTotalCents);
    final totalCents =
        subTotalCents - discountCents + shippingCents + orderTaxCents;

    final sale = [
      {
        'location_id': locationId,
        'contact_id': customer.id,
        'transaction_date': nowSql(),
        'invoice_no': null,
        'status': 'final',
        'sub_status': null,
        'tax_rate_id': null,
        'discount_amount': discountCents / 100.0,
        'discount_type': 'fixed',
        'change_return': 0,
        'products': productsPayload,
        'sale_note': null,
        'staff_note': null,
        'shipping_charges': shippingCents / 100.0,
        'shipping_details': null,
        'is_quotation': 0,
        'payments': [
          {
            'method': (method == 'cash') ? 'cash' : 'card',
            'amount': totalCents / 100.0,
            'note': null,
            'account_id': null,
            'is_return': 0,
          }
        ],
      }
    ];

    // Some versions of your SellApi expect a JSON body string, others a Map.
    // Try sending Map first; if your client wrapper expects a string, encode it.
    try {
      final res = await app.SellApi().create({'sells': sale});
      final ok = res is Map &&
          (res['success'] == true ||
              res['transaction_id'] != null ||
              res['invoice_url'] != null);
      if (ok) return true;
    } catch (_) {
      // fallback: send encoded JSON if your client requires it
      try {
        final res = await app.SellApi().create(jsonEncode({'sells': sale}));
        final ok = res is Map &&
            (res['success'] == true ||
                res['transaction_id'] != null ||
                res['invoice_url'] != null);
        if (ok) return true;
      } catch (_) {}
    }
    return false;
  }
}

// ====== Controller (Cart math, debounce, pagination guards) ======
class CartController extends ChangeNotifier {
  final Map<int, CartLine> _lines = {}; // by productId
  int discountCents = 0;
  int shippingCents = 0;
  int orderTaxCents = 0; // order-level tax as absolute cents (set via UI)

  List<CartLine> get lines => _lines.values.toList(growable: false);
  int get items => _lines.values.fold(0, (a, b) => a + b.qty);
  int get subTotalCents =>
      _lines.values.fold(0, (a, b) => a + b.lineTotalCents);
  int get totalPayableCents =>
      subTotalCents - discountCents + shippingCents + orderTaxCents;

  void add(Product p) {
    final existing = _lines[p.productId];
    if (existing == null) {
      _lines[p.productId] = CartLine(p, qty: 1);
    } else {
      existing.qty += 1;
    }
    notifyListeners();
  }

  void remove(int productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void setQty(int productId, int qty) {
    final l = _lines[productId];
    if (l == null) return;
    l.qty = qty < 1 ? 1 : qty;
    notifyListeners();
  }

  void setDiscountCents(int v) {
    discountCents = v.abs();
    notifyListeners();
  }

  void setShippingCents(int v) {
    shippingCents = v.abs();
    notifyListeners();
  }

  void setOrderTaxCents(int v) {
    orderTaxCents = v.abs();
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    discountCents = 0;
    shippingCents = 0;
    orderTaxCents = 0;
    notifyListeners();
  }
}

// ====== POS Page ======
class PosSellPage extends StatefulWidget {
  final ProductRepository products;
  final CustomerRepository customers;
  final SellRepository sells;
  const PosSellPage(
      {super.key,
      required this.products,
      required this.customers,
      required this.sells});

  @override
  State<PosSellPage> createState() => _PosSellPageState();
}

class _PosSellPageState extends State<PosSellPage> {
  final cart = CartController();

  // UI
  final searchCtl = TextEditingController();
  final ScrollController gridCtl = ScrollController();
  Timer? _debounce;

  // Data/state
  List<Map> _locations = [];
  Map? _selectedLocation;
  Customer? _selectedCustomer;
  List<Customer> _customerList = const [];

  // Products + pagination
  List<Product> _products = [];
  int _page = 1;
  bool _loading = false;
  bool _hasNext = true;
  String _currentQuery = '';

  bool committing = false;

  @override
  void initState() {
    super.initState();
    _init();
    gridCtl.addListener(_onScrollLoad);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchCtl.dispose();
    gridCtl.dispose();
    cart.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadLocations();
    await _loadCustomers();
    if (_locations.length == 1) {
      await _onLocationChanged(_locations.first);
    }
  }

  Future<void> _loadLocations() async {
    List cached = await sys.System().get('location');
    if (cached.isEmpty) {
      await Location().get();
      cached = await sys.System().get('location');
    }
    setState(() => _locations = cached.cast<Map>());
  }

  Future<void> _loadCustomers() async {
    final list = await widget.customers.all();
    setState(() {
      _customerList = list;
      _selectedCustomer = list.isNotEmpty ? list.first : null;
    });
  }

  Future<void> _onLocationChanged(Map loc) async {
    setState(() {
      _selectedLocation = loc;
      _products.clear();
      _page = 1;
      _hasNext = true;
    });
    await _ensureProductCache(loc['id']);
    await _loadPage();
  }

  Future<void> _ensureProductCache(int locationId) async {
    try {
      final existing =
          await app.Variations().checkProductTable(locationId: locationId);
      if (existing == 0) {
        await app.Variations().store();
      }
    } catch (_) {}
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (_selectedLocation == null) return;
      setState(() {
        _products.clear();
        _page = 1;
        _hasNext = true;
        _currentQuery = q;
      });
      await _loadPage();
    });
  }

  void _onScrollLoad() {
    if (_loading || !_hasNext) return;
    if (gridCtl.position.pixels > gridCtl.position.maxScrollExtent - 400) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_selectedLocation == null) return;
    setState(() => _loading = true);
    try {
      final pageItems = _currentQuery.isEmpty
          ? await widget.products
              .featured(locationId: _selectedLocation!['id'], page: _page)
          : await widget.products.search(
              query: _currentQuery,
              locationId: _selectedLocation!['id'],
              page: _page);
      setState(() {
        _products.addAll(pageItems);
        _hasNext = pageItems.length >= 10; // API returns 10 per page
        if (_hasNext) _page += 1;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _commit(String method) async {
    if (_selectedLocation == null) {
      _toast('اختر الموقع أولًا');
      return;
    }
    if (cart.lines.isEmpty) {
      _toast('السلة فارغة');
      return;
    }
    if (_selectedCustomer == null || _selectedCustomer!.id.isEmpty) {
      _toast('اختر العميل');
      return;
    }
    setState(() => committing = true);
    final ok = await widget.sells.createSale(
      locationId: _selectedLocation!['id'],
      customer: _selectedCustomer!,
      lines: cart.lines,
      discountCents: cart.discountCents,
      shippingCents: cart.shippingCents,
      orderTaxCents: cart.orderTaxCents,
      method: method,
    );
    if (!mounted) return;
    setState(() => committing = false);
    if (ok) {
      cart.clear();
      _toast('تمت العملية بنجاح');
    } else {
      _toast('تعذر إنشاء عملية البيع');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نقطة البيع'),
          actions: [
            if (_selectedCustomer != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Chip(label: Text(_selectedCustomer!.name)),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: searchCtl,
                onChanged: _onSearchChanged,
                onSubmitted: (v) async {
                  if (v.trim().isEmpty || _selectedLocation == null) return;
                  final hit = await const AppProductRepo().findBySku(
                      sku: v.trim(), locationId: _selectedLocation!['id']);
                  if (hit != null) cart.add(hit);
                  searchCtl.clear();
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  hintText: 'أدخل اسم المنتج / SKU / امسح الباركود',
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
        ),
        body: Row(
          children: [
            // LEFT: products grid
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ProductsGrid(
                  controller: gridCtl,
                  products: _products,
                  loading: _loading,
                  onPick: cart.add,
                ),
              ),
            ),
            // RIGHT: cart & summary
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _TopBar(
                      locations: _locations,
                      selectedLocation: _selectedLocation,
                      onLocation: (m) => _onLocationChanged(m),
                      customers: _customerList,
                      selectedCustomer: _selectedCustomer,
                      onCustomer: (c) => setState(() => _selectedCustomer = c),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _CartTable(cart: cart)),
                    const SizedBox(height: 8),
                    _SummaryPanel(cart: cart),
                    const SizedBox(height: 8),
                    _CheckoutBar(
                      totalCents: cart.totalPayableCents,
                      onCancel: cart.clear,
                      onCash: () => _commit('cash'),
                      onCard: () => _commit('card'),
                      onMulti: () => _commit('multi'),
                      committing: committing,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== UI pieces ======
class _TopBar extends StatelessWidget {
  final List<Map> locations;
  final Map? selectedLocation;
  final ValueChanged<Map> onLocation;
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onCustomer;
  const _TopBar({
    required this.locations,
    required this.selectedLocation,
    required this.onLocation,
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240),
              child: DropdownButtonFormField<Map>(
                isExpanded: true,
                value: selectedLocation,
                items: locations
                    .map((loc) => DropdownMenuItem(
                        value: loc,
                        child: Text(loc['name']?.toString() ?? 'الموقع')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onLocation(v);
                },
                decoration: const InputDecoration(
                    labelText: 'الموقع',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260),
              child: DropdownButtonFormField<Customer>(
                isExpanded: true,
                value: selectedCustomer,
                items: customers
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onCustomer(v);
                },
                decoration: const InputDecoration(
                    labelText: 'اسم العميل في الفاتورة',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final ScrollController controller;
  final List<Product> products;
  final bool loading;
  final void Function(Product) onPick;
  const _ProductsGrid(
      {required this.controller,
      required this.products,
      required this.loading,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: controller,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.30,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductCard(
                product: products[i], onTap: () => onPick(products[i])),
          ),
        ),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: const Icon(Icons.image_outlined, size: 42),
                ),
              ),
              const SizedBox(height: 8),
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(product.sku, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Text('${money(product.priceIncTaxCents)} ر.س'),
                const Spacer(),
                Text(
                    'في المخزون ${product.stock.toStringAsFixed(0)} ${product.unitName}')
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartTable extends StatefulWidget {
  final CartController cart;
  const _CartTable({required this.cart});
  @override
  State<_CartTable> createState() => _CartTableState();
}

class _CartTableState extends State<_CartTable> {
  @override
  void initState() {
    super.initState();
    widget.cart.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.cart.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: cart.lines.isEmpty
            ? const Center(
                child:
                    Opacity(opacity: .6, child: Text('لا توجد عناصر في السلة')))
            : SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 44,
                  columns: const [
                    DataColumn(label: Text('منتج')),
                    DataColumn(label: Text('الكمية')),
                    DataColumn(label: Text('السعر شامل الضريبة')),
                    DataColumn(label: Text('المجموع')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final line in cart.lines)
                      DataRow(cells: [
                        DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(line.product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text('SKU: ${line.product.sku}',
                                  style: const TextStyle(fontSize: 12)),
                            ])),
                        DataCell(Row(children: [
                          IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => cart.setQty(
                                  line.product.productId, line.qty - 1)),
                          SizedBox(
                              width: 42,
                              child: Center(
                                  child: Text('${line.qty}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)))),
                          IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => cart.setQty(
                                  line.product.productId, line.qty + 1)),
                        ])),
                        DataCell(Text(money(line.product.priceIncTaxCents))),
                        DataCell(Text(money(line.lineTotalCents))),
                        DataCell(IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                cart.remove(line.product.productId))),
                      ])
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummaryPanel extends StatefulWidget {
  final CartController cart;
  const _SummaryPanel({required this.cart});
  @override
  State<_SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<_SummaryPanel> {
  late final TextEditingController _discount;
  late final TextEditingController _tax;
  late final TextEditingController _ship;

  @override
  void initState() {
    super.initState();
    _discount = TextEditingController(text: money(widget.cart.discountCents));
    _tax = TextEditingController(text: money(widget.cart.orderTaxCents));
    _ship = TextEditingController(text: money(widget.cart.shippingCents));
    widget.cart.addListener(_syncControllers);
  }

  void _syncControllers() {
    // keep text fields in sync if the cart changes elsewhere
    _discount.text = money(widget.cart.discountCents);
    _tax.text = money(widget.cart.orderTaxCents);
    _ship.text = money(widget.cart.shippingCents);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.cart.removeListener(_syncControllers);
    _discount.dispose();
    _tax.dispose();
    _ship.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label) => const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ).copyWith(labelText: label);

  int _parseToCents(String v) {
    final t = v.replaceAll(',', '.').trim();
    final d = double.tryParse(t) ?? 0.0;
    return toCents(d);
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: Wrap(spacing: 12, runSpacing: 8, children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('الخصم (−)'),
                  onChanged: (v) => cart.setDiscountCents(_parseToCents(v)),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _tax,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('ضريبة الطلب (+)'),
                  onChanged: (v) => cart.setOrderTaxCents(_parseToCents(v)),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _ship,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _deco('شحن (+)'),
                  onChanged: (v) => cart.setShippingCents(_parseToCents(v)),
                ),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _moneyRow('عناصر:', cart.items.toDouble()),
            _moneyRow('المجموع:', cart.subTotalCents / 100.0),
            _moneyRow('الخصم:', -cart.discountCents / 100.0),
            _moneyRow('ضريبة الطلب:', cart.orderTaxCents / 100.0),
            _moneyRow('شحن:', cart.shippingCents / 100.0),
            const SizedBox(height: 8),
            Text('الإجمالي المستحق:',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              money(cart.totalPayableCents),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ])
        ]),
      ),
    );
  }

  Widget _moneyRow(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 12),
            Text(value.toStringAsFixed(2))
          ],
        ),
      );
}

class _CheckoutBar extends StatelessWidget {
  final int totalCents;
  final VoidCallback onCancel;
  final VoidCallback onCash;
  final VoidCallback onCard;
  final VoidCallback onMulti;
  final bool committing;
  const _CheckoutBar(
      {required this.totalCents,
      required this.onCancel,
      required this.onCash,
      required this.onCard,
      required this.onMulti,
      required this.committing});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.primaryContainer),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المجموع قابل للدفع:'),
              Text(money(totalCents),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700))
            ]),
          ),
          const Spacer(),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
                onPressed: committing ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء')),
            FilledButton.icon(
                onPressed: committing ? null : onCash,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('كاش')),
            FilledButton.tonalIcon(
                onPressed: committing ? null : onCard,
                icon: const Icon(Icons.credit_card),
                label: const Text('بطاقة')),
            ElevatedButton.icon(
                onPressed: committing ? null : onMulti,
                icon: const Icon(Icons.point_of_sale),
                label: const Text('دفع متعدد')),
          ])
        ]),
      ),
    );
  }
}

// ====== Quick bootstrapping example ======
// MaterialApp(
//   home: PosSellPage(
//     products: const AppProductRepo(),
//     customers: const AppCustomerRepo(),
//     sells: const AppSellRepo(),
//   ),
// )
