import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';

import '/config.dart';
import '/helpers/AppTheme.dart';

import '/models/contact_model.dart'; // exposes Contact().get()
import '/models/sell.dart';
import '/models/sellDatabase.dart';
import '/models/system.dart';
import '/models/variations.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '/models/invoice.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// =============================================================================
// Safe helpers
// =============================================================================

double _asDouble(Object? v, [double def = 0]) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? def;
  return def;
}

String _generateInvoiceNo({String prefix = 'INV'}) {
  final now = DateTime.now();
  final y = now.year;
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final tail =
      (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
  return '$prefix-$y$m$d-$tail';
}

int _asInt(Object? v, [int def = 0]) {
  if (v == null) return def;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

String _asString(Object? v, [String def = '']) => v?.toString() ?? def;

String _fmt(double v) => v.toStringAsFixed(2);

// =============================================================================
// Typed models (prefixed to avoid name clashes with your pages/routes)
// =============================================================================

class PosProductModel {
  final int productId;
  final int variationId;
  final String displayName;
  final String imageUrl;
  final double priceIncTax;
  final double sellPrice;
  final double unitPrice;
  final bool enableStock;
  final double stockAvailable;
  final int? taxRateId;

  PosProductModel({
    required this.productId,
    required this.variationId,
    required this.displayName,
    required this.imageUrl,
    required this.priceIncTax,
    required this.sellPrice,
    required this.unitPrice,
    required this.enableStock,
    required this.stockAvailable,
    required this.taxRateId,
  });

  factory PosProductModel.fromMap(Map m) => PosProductModel(
        productId: _asInt(m['product_id'] ?? m['id']),
        variationId: _asInt(m['variation_id'] ?? m['id']),
        displayName: _asString(m['display_name'] ?? m['name']),
        imageUrl: _asString(m['product_image_url']),
        priceIncTax: _asDouble(m['sell_price_inc_tax']),
        sellPrice: _asDouble(m['sell_price']),
        unitPrice: _asDouble(m['unit_price']),
        enableStock: m['enable_stock'] == 1 || m['enable_stock'] == true,
        stockAvailable: _asDouble(m['stock_available'], 0),
        taxRateId: (m['tax_rate_id'] == null || _asInt(m['tax_rate_id']) == 0)
            ? null
            : _asInt(m['tax_rate_id']),
      );

  double get chosenUnitPrice => (priceIncTax != 0)
      ? priceIncTax
      : ((sellPrice != 0) ? sellPrice : unitPrice);
}

class PosCartLine {
  final int id; // local DB id for sell_lines
  final int productId;
  final int variationId;
  final String name;
  final double unitPrice;
  final double quantity;
  final double discount;
  final double taxAmount;

  const PosCartLine({
    required this.id,
    required this.productId,
    required this.variationId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.discount,
    required this.taxAmount,
  });

  PosCartLine copyWith(
          {double? quantity,
          double? unitPrice,
          double? discount,
          double? taxAmount}) =>
      PosCartLine(
        id: id,
        productId: productId,
        variationId: variationId,
        name: name,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        discount: discount ?? this.discount,
        taxAmount: taxAmount ?? this.taxAmount,
      );

  factory PosCartLine.fromDb(Map row) => PosCartLine(
        id: _asInt(row['id']),
        productId: _asInt(row['product_id']),
        variationId: _asInt(row['variation_id']),
        name: _asString(row['name'] ?? row['display_name']),
        unitPrice: _asDouble(row['unit_price']),
        quantity: _asDouble(row['quantity'], 1),
        discount: _asDouble(row['discount'] ?? row['discount_amount'], 0),
        taxAmount: _asDouble(row['tax_amount'], 0),
      );
}

class PosCategoryModel {
  final int id;
  final String name;
  PosCategoryModel(this.id, this.name);
  factory PosCategoryModel.fromMap(Map m) =>
      PosCategoryModel(_asInt(m['id']), _asString(m['name']));
}

class PosBrandModel {
  final int id;
  final String name;
  PosBrandModel(this.id, this.name);
  factory PosBrandModel.fromMap(Map m) =>
      PosBrandModel(_asInt(m['id']), _asString(m['name']));
}

class PosCustomerModel {
  final int id;
  final String name;
  PosCustomerModel(this.id, this.name);
  factory PosCustomerModel.fromMap(Map m) => PosCustomerModel(
      _asInt(m['id']), _asString(m['name'] ?? m['first_name']));
}

// =============================================================================
// Repo adapters (wrap your existing API classes)
// =============================================================================

class VariationRepo {
  Future<List<PosProductModel>> fetch(
      {int? brandId,
      required int categoryId,
      required String searchTerm,
      required int locationId,
      required int page}) async {
    final res = await Variations().get(
      brandId: brandId ?? 0,
      categoryId: categoryId,
      searchTerm: searchTerm,
      locationId: locationId,
      offset: page,
    );
    return (res as List).map((e) => PosProductModel.fromMap(e as Map)).toList();
  }
}

class SystemRepo {
  Future<List<PosCategoryModel>> categories() async {
    final res = await System().getCategories();
    return (res as List)
        .map((e) => PosCategoryModel.fromMap(e as Map))
        .toList();
  }

  Future<List<PosBrandModel>> brands() async {
    final res = await System().getBrands();
    return (res as List).map((e) => PosBrandModel.fromMap(e as Map)).toList();
  }
}

class ContactRepo {
  Future<List<PosCustomerModel>> customers() async {
    final res = await Contact().get();
    return (res as List)
        .map((e) => PosCustomerModel.fromMap(e as Map))
        .toList();
  }
}

class CartRepo {
  Future<List<PosCartLine>> lines(int locationId) async {
    final rows = await SellDatabase().getInCompleteLines(locationId);
    return (rows as List)
        .map((r) => PosCartLine.fromDb(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> delete(int variationId, int productId) async {
    await SellDatabase().delete(variationId, productId);
  }

  Future<void> addLine(PosProductModel p) async {
    final payload = {
      'product_id': p.productId,
      'variation_id': p.variationId,
      'display_name': p.displayName,
      'sell_price_inc_tax': p.priceIncTax,
      'sell_price': p.sellPrice,
      'unit_price': p.chosenUnitPrice,
      'quantity': 1.0,
      'discount': 0.0,
      'discount_amount': 0.0,
      'discount_type': 'fixed',
      'tax_amount': 0.0,
      'tax_rate_id': p.taxRateId,
    };
    await Sell().addToCart(payload, null);
  }

  Future<void> reset() => Sell().resetCart();

  Future<bool> updateQty(PosCartLine line, double qty) async {
    try {
      await SellDatabase().update(line.id, {'quantity': qty});
      return true;
    } catch (_) {
      return false;
    }
  }
}

// =============================================================================
// Controller
// =============================================================================

class PosController extends ChangeNotifier {
  PosController({
    required this.variationRepo,
    required this.systemRepo,
    required this.contactRepo,
    required this.cartRepo,
    this.taxRate = 0.15,
  });

  final VariationRepo variationRepo;
  final SystemRepo systemRepo;
  final ContactRepo contactRepo;
  final CartRepo cartRepo;
  final double taxRate;

  bool isLoading = true;
  bool showCategories = false;
  int? selectedBrandId;
  int selectedCategoryId = 0;
  int currentPage = 1;
  String searchTerm = '';
  int locationId = 1;

  List<PosProductModel> products = [];
  List<PosCategoryModel> categories = [];
  List<PosBrandModel> brands = [];
  List<PosCustomerModel> customers = [];
  PosCustomerModel? selectedCustomer;
  List<PosCartLine> cart = [];

  double subtotal = 0, tax = 0, total = 0, discount = 0, shipping = 0;

  int _productsReqId = 0;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadProducts(),
        loadCategories(),
        loadBrands(),
        loadCustomers(),
        loadCart(),
      ]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts() async {
    final reqId = ++_productsReqId;
    final res = await variationRepo.fetch(
      brandId: selectedBrandId,
      categoryId: selectedCategoryId,
      searchTerm: searchTerm,
      locationId: locationId,
      page: currentPage,
    );
    if (reqId != _productsReqId) return;
    products = res;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    categories = await systemRepo.categories();
    notifyListeners();
  }

  Future<void> loadBrands() async {
    brands = await systemRepo.brands();
    notifyListeners();
  }

  Future<void> loadCustomers() async {
    customers = await contactRepo.customers();
    notifyListeners();
  }

  Future<void> loadCart() async {
    cart = await cartRepo.lines(locationId);
    _recalcTotals();
    notifyListeners();
  }

  void setSearchTerm(String v) {
    searchTerm = v;
    notifyListeners();
  }

  void setBrand(int? id) {
    selectedBrandId = id;
    notifyListeners();
  }

  void setCategory(int id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  void toggleCategories() {
    showCategories = !showCategories;
    notifyListeners();
  }

  Future<void> addOrIncrease(PosProductModel p) async {
    final idx = cart.indexWhere(
        (l) => l.productId == p.productId && l.variationId == p.variationId);
    if (idx >= 0) {
      final nextQty = cart[idx].quantity + 1;
      cart[idx] = cart[idx].copyWith(quantity: nextQty);
      await cartRepo.updateQty(cart[idx], nextQty);
      _recalcTotals();
      notifyListeners();
    } else {
      await cartRepo.addLine(p);
      await loadCart();
    }
  }

  Future<void> updateQuantity(int index, double q) async {
    if (index < 0 || index >= cart.length) return;
    if (q <= 0) return removeAt(index);
    final line = cart[index];
    cart[index] = line.copyWith(quantity: q);
    await cartRepo.updateQty(line, q);
    _recalcTotals();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= cart.length) return;
    final line = cart[index];
    await cartRepo.delete(line.variationId, line.productId);
    await loadCart();
  }

  Future<void> clearCart() async {
    await cartRepo.reset();
    await loadCart();
  }

  void _recalcTotals() {
    subtotal = 0;
    for (final l in cart) {
      subtotal += l.unitPrice * l.quantity;
    }
    tax = subtotal * taxRate;
    total = subtotal + tax + shipping - discount;
  }

  /// Creates a local sell, attaches current cart lines, saves payment and tries to sync.
  /// Returns the new sellId.
// In PosController
  Future<int> saveSale({
    required int customerId,
    required String discountType,
    List<Map<String, dynamic>> payments = const [],
    bool asDebit = false, // 👈 NEW
  }) async {
    // 1) Build sale map
    final saleMap = await Sell().createSell(
      invoiceNo: _generateInvoiceNo(),
      transactionDate: DateTime.now().toIso8601String(),
      contactId: customerId,
      locId: locationId,
      taxId: 0, // supply a real tax id if you use one
      discountType: discountType,
      discountAmount: discount,
      invoiceAmount: total,
      changeReturn: 0.0,
      pending:
          asDebit ? total : 0.0, // 👈 put the full amount as pending for debit
      saleNote: '',
      staffNote: '',
      shippingCharges: shipping,
      shippingDetails: '',
      saleStatus: 'final',
    );

    // 2) Insert sell -> get id
    final sellId = await SellDatabase().storeSell(saleMap);

    // 3) Attach current cart lines to sell & mark as completed
    await SellDatabase().updateSellLine({'sell_id': sellId, 'is_completed': 1});

    // 4) Only create payment rows if NOT debit
    if (!asDebit && payments.isNotEmpty) {
      await Sell().makePayment(payments, sellId);
    }

    // 5) Try to sync (no-throw if offline)
    try {
      await Sell().createApiSell(sellId: sellId);
    } catch (_) {}

    // 6) Refresh cart
    await loadCart();

    return sellId;
  }
}

// =============================================================================
// Page Widget
// =============================================================================

class PosSinglePage extends StatefulWidget {
  const PosSinglePage({Key? key}) : super(key: key);
  @override
  State<PosSinglePage> createState() => _PosSinglePageState();
}

class _PosSinglePageState extends State<PosSinglePage> {
  static int themeType = 1;
  final ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  final CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _saving = false;

  late final PosController controller;

  @override
  void initState() {
    super.initState();
    controller = PosController(
      variationRepo: VariationRepo(),
      systemRepo: SystemRepo(),
      contactRepo: ContactRepo(),
      cartRepo: CartRepo(),
      taxRate: 0, // TODO: load from System()
    );
    controller.init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: themeData.scaffoldBackgroundColor,
          body: Row(
            children: [
              Expanded(flex: 2, child: _buildLeft()),
              Container(
                width: 420,
                decoration: BoxDecoration(
                  color: themeData.cardColor,
                  boxShadow: [
                    BoxShadow(
                        color: themeData.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(-2, 0))
                  ],
                ),
                child: _buildRight(),
              ),
            ],
          ),
        );
      },
    );
  }

  // LEFT PANEL --------------------------------------------------------------
  Widget _buildLeft() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: themeData.cardColor, boxShadow: [
          BoxShadow(
              color: themeData.shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ]),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search products',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        controller.searchTerm = '';
                        controller.loadProducts();
                        setState(() {});
                      })
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) {
              controller.searchTerm = v;
              _debounce?.cancel();
              _debounce = Timer(
                  const Duration(milliseconds: 300), controller.loadProducts);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.toggleCategories(),
                icon: const Icon(Icons.category),
                label: const Text('Categories'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.showCategories
                      ? themeData.colorScheme.primary
                      : themeData.cardColor,
                  foregroundColor:
                      controller.showCategories ? Colors.white : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: controller.selectedBrandId,
                decoration: InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('All brands')),
                  ...controller.brands.map((b) =>
                      DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                ],
                onChanged: (v) {
                  controller.setBrand(v);
                  controller.loadProducts();
                },
              ),
            ),
          ]),
        ]),
      ),
      if (controller.showCategories)
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.horizontal,
            itemCount: controller.categories.length,
            itemBuilder: (context, i) {
              final c = controller.categories[i];
              final selected = controller.selectedCategoryId == c.id;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(c.name),
                  onSelected: (sel) {
                    controller.setCategory(sel ? c.id : 0);
                    controller.loadProducts();
                  },
                ),
              );
            },
          ),
        ),
      Expanded(
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildProductsGrid(),
      ),
    ]);
  }

  Widget _buildProductsGrid() {
    final items = controller.products;
    if (items.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No products found',
                  style: TextStyle(color: Colors.grey, fontSize: 18)),
            ]),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final cross = ((c.maxWidth / 220).floor()).clamp(1, 8).toInt();
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _productCard(items[i]),
      );
    });
  }

  Widget _productCard(PosProductModel p) {
    final isOut = p.enableStock && p.stockAvailable <= 0;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isOut
            ? null
            : () async {
                await controller.addOrIncrease(p);
              },
        borderRadius: BorderRadius.circular(8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
              clipBehavior: Clip.antiAlias,
              child: (p.imageUrl.isNotEmpty)
                  ? Image.network(p.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: themeData.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(p.chosenUnitPrice),
                              style: themeData.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: themeData.colorScheme.primary)),
                          if (p.enableStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: isOut ? Colors.red : Colors.green,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(p.stockAvailable.toStringAsFixed(0),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
      color: Colors.grey[200],
      child:
          Icon(Icons.image_not_supported, color: Colors.grey[400], size: 40));

  // RIGHT PANEL -------------------------------------------------------------
  Widget _buildRight() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: themeData.colorScheme.primary,
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12))),
        child: Row(children: [
          const Icon(Icons.shopping_cart, color: Colors.white),
          const SizedBox(width: 8),
          Text('Cart',
              style: themeData.textTheme.titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${controller.cart.length} items',
              style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<PosCustomerModel?>(
          value: controller.selectedCustomer,
          decoration: const InputDecoration(
              labelText: 'Customer',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person)),
          items: controller.customers
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: (c) {
            controller.selectedCustomer = c;
            controller.notifyListeners();
          },
        ),
      ),
      Expanded(
        child: controller.cart.isEmpty
            ? _emptyCart()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.cart.length,
                itemBuilder: (context, i) => _cartItem(i),
              ),
      ),
      _summary(),
    ]);
  }

  Widget _emptyCart() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('Your cart is empty',
            style: themeData.textTheme.titleMedium
                ?.copyWith(color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Add products to cart',
            style: themeData.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey[500])),
      ]));

  Widget _cartItem(int index) {
    final l = controller.cart[index];
    final total = l.unitPrice * l.quantity;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(l.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: themeData.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_fmt(l.unitPrice),
                    style: themeData.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600])),
              ])),
          const SizedBox(width: 8),
          Row(children: [
            IconButton(
                onPressed: () =>
                    controller.updateQuantity(index, l.quantity - 1),
                icon: const Icon(Icons.remove_circle_outline),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero),
            SizedBox(
                width: 50,
                child: Text(
                    l.quantity.toStringAsFixed(Config.quantityPrecision),
                    textAlign: TextAlign.center,
                    style: themeData.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(
                onPressed: () =>
                    controller.updateQuantity(index, l.quantity + 1),
                icon: const Icon(Icons.add_circle_outline),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero),
          ]),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt(total),
                style: themeData.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: () => controller.removeAt(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero),
          ]),
        ]),
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: themeData.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
                color: themeData.shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ]),
      child: Column(children: [
        _summaryRow('Subtotal', _fmt(controller.subtotal)),
        if (controller.discount > 0)
          _summaryRow('Discount', '-${_fmt(controller.discount)}',
              color: Colors.green),
        _summaryRow('Tax', _fmt(controller.tax)),
        if (controller.shipping > 0)
          _summaryRow('Shipping', _fmt(controller.shipping)),
        const Divider(thickness: 2),
        _summaryRow('Total', _fmt(controller.total), isTotal: true),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.cart.isEmpty || _saving
                  ? null
                  : () async {
                      await controller.clearCart();
                    },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 8),

          // New DEBIT button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: controller.cart.isEmpty || _saving ? null : _saveDebit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.credit_card),
              label: Text(_saving ? 'Saving…' : 'Debit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeData.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Existing cash/checkout
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed:
                  controller.cart.isEmpty || _saving ? null : _saveDirectly,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.payment),
              label: Text(_saving ? 'Saving…' : 'Checkout'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: themeData.colorScheme.primary,
                  foregroundColor: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? color, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: themeData.textTheme.bodyMedium?.copyWith(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14)),
        Text(value,
            style: themeData.textTheme.bodyMedium?.copyWith(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                fontSize: isTotal ? 16 : 14,
                color:
                    color ?? (isTotal ? themeData.colorScheme.primary : null))),
      ]),
    );
  }

  Future<void> _saveDirectly() async {
    if (controller.cart.isEmpty) return;

    setState(() => _saving = true);
    int? sellId;
    try {
      final customerId = controller.selectedCustomer?.id ?? 1;
      final payments = <Map<String, dynamic>>[
        {
          'method': 'cash',
          'amount': controller.total,
          'note': 'POS',
          'account_id': null
        },
      ];

      sellId = await controller.saveSale(
        customerId: customerId,
        discountType: 'fixed',
        payments: payments,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Sale saved (#$sellId)'),
            backgroundColor: Colors.green),
      );
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('SAVE FAILED: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save sale: $e'),
            backgroundColor: Colors.red),
      );
      return; // don't try to print
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    // Print in a separate try/catch so we can show a correct message
    try {
      await _printInvoice(sellId!);
    } catch (e, st) {
      debugPrint('PRINT FAILED: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to print invoice: $e'),
            backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _saveDebit() async {
    if (controller.cart.isEmpty) return;

    setState(() => _saving = true);
    try {
      final customerId =
          controller.selectedCustomer?.id ?? 1; // Walk-in default

      final sellId = await controller.saveSale(
        customerId: customerId,
        discountType: 'fixed',
        payments: const [], // 👈 NO payment lines
        asDebit: true, // 👈 mark as debit (pending)
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Sale saved (DEBIT) (#$sellId)'),
            backgroundColor: Colors.green),
      );
      await _printInvoice(sellId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save sale: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printInvoice(int sellId) async {
    const taxId = 0;
    final html =
        await InvoiceFormatter().generateInvoice(sellId, taxId, context);

    // Optional: save HTML for debugging (non-web only)
    if (!kIsWeb) {
      try {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/invoice-$sellId.html');
        await f.writeAsString(html);
        debugPrint('Invoice HTML saved to: ${f.path}');
      } catch (e) {
        debugPrint('Could not save invoice HTML: $e');
      }
    }

    await Printing.layoutPdf(
      onLayout: (format) => Printing.convertHtml(html: html, format: format),
    );
  }
}
