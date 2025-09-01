import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/purchase_models.dart';
import '../../providers/purchase_provider.dart';
import '../../locale/MyLocalizations.dart';

/// Main purchase creation screen
class PurchaseCreationScreen extends ConsumerStatefulWidget {
  static const String routeName = '/purchase-creation';

  const PurchaseCreationScreen({super.key});

  @override
  ConsumerState<PurchaseCreationScreen> createState() =>
      _PurchaseCreationScreenState();
}

class _PurchaseCreationScreenState
    extends ConsumerState<PurchaseCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refNoController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();
  final _shippingController = TextEditingController();
  final _notesController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _paymentNoteController = TextEditingController();

  // Search controllers
  final _supplierSearchController = TextEditingController();
  final _productSearchController = TextEditingController();

  // Filtered lists
  List<Supplier> _filteredSuppliers = [];
  List<PurchaseProduct> _filteredProducts = [];
  bool _isProductSearchFocused = false;

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseCreationProvider.notifier).loadSuppliers();
      ref.read(purchaseCreationProvider.notifier).loadProducts();
    });

    // Initialize filtered lists
    _supplierSearchController.addListener(_filterSuppliers);
    _productSearchController.addListener(_filterProducts);
  }

  void _filterSuppliers() {
    final state = ref.read(purchaseCreationProvider);
    final query = _supplierSearchController.text.toLowerCase();
    setState(() {
      _filteredSuppliers = state.suppliers.where((supplier) {
        return supplier.name.toLowerCase().contains(query) ||
            (supplier.businessName?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _filterProducts() {
    final state = ref.read(purchaseCreationProvider);
    final query = _productSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // When search is empty, show first 10 products if focused
        _filteredProducts =
            _isProductSearchFocused ? state.products.take(10).toList() : [];
      } else {
        _filteredProducts = state.products.where((product) {
          return product.productName.toLowerCase().contains(query) ||
              (product.subSku?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _refNoController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    _paymentAmountController.dispose();
    _paymentNoteController.dispose();
    _supplierSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseCreationProvider);
    final notifier = ref.read(purchaseCreationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            AppLocalizations.of(context).translate('create_purchase_order')),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (state.isFormValid)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton.icon(
                onPressed: state.isSubmitting ? null : _submitPurchase,
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(
                  state.isSubmitting
                      ? AppLocalizations.of(context).translate('loading')
                      : AppLocalizations.of(context).translate('save'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: state.isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error message
                      if (state.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.errorMessage!,
                                  style: TextStyle(color: Colors.red.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Basic Information Section
                      _buildSectionHeader(AppLocalizations.of(context)
                          .translate('basic_information')),
                      _buildBasicInfoSection(state, notifier),

                      const SizedBox(height: 24),

                      // Supplier and Location Section
                      _buildSectionHeader(AppLocalizations.of(context)
                          .translate('supplier_location')),
                      _buildSupplierLocationSection(state, notifier),

                      const SizedBox(height: 24),

                      // Products Section
                      _buildSectionHeader(
                          AppLocalizations.of(context).translate('products')),
                      _buildProductsSection(state, notifier),

                      const SizedBox(height: 24),

                      // Financial Information Section
                      _buildSectionHeader(AppLocalizations.of(context)
                          .translate('financial_information')),
                      _buildFinancialSection(state, notifier),

                      const SizedBox(height: 24),

                      // Payment Information Section
                      _buildSectionHeader(AppLocalizations.of(context)
                          .translate('payment_information')),
                      _buildPaymentSection(state, notifier),

                      const SizedBox(height: 24),

                      // Additional Information Section
                      _buildSectionHeader(AppLocalizations.of(context)
                          .translate('additional_information')),
                      _buildAdditionalInfoSection(state, notifier),

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: state.isFormValid && !state.isSubmitting
                              ? _submitPurchase
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                state.isFormValid ? Colors.green : Colors.grey,
                          ),
                          child: state.isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(AppLocalizations.of(context)
                                  .translate('create_purchase_order')),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(
      PurchaseCreationState state, PurchaseCreationNotifier notifier) {
    return Card(
        elevation: 4,
        shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)
                          .translate('basic_information'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Reference Number
                TextFormField(
                  controller: _refNoController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)
                        .translate('reference_number'),
                    hintText: AppLocalizations.of(context)
                        .translate('leave_empty_for_auto_generation'),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => notifier
                      .updateReferenceNumber(value.isEmpty ? null : value),
                ),

                const SizedBox(height: 16),

                // Transaction Date
                InkWell(
                  onTap: () => _selectDate(
                      context, state.purchase?.transactionDate, (date) {
                    notifier.updateTransactionDate(date);
                  }),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('transaction_date'),
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(
                          state.purchase?.transactionDate ?? DateTime.now()),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status
                DropdownButtonFormField<String>(
                  value: state.purchase?.status,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).translate('status'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'ordered',
                        child: Text(
                            AppLocalizations.of(context).translate('ordered'))),
                    DropdownMenuItem(
                        value: 'received',
                        child: Text(AppLocalizations.of(context)
                            .translate('received'))),
                    DropdownMenuItem(
                        value: 'pending',
                        child: Text(
                            AppLocalizations.of(context).translate('pending'))),
                    DropdownMenuItem(
                        value: 'partial',
                        child: Text(
                            AppLocalizations.of(context).translate('partial'))),
                  ],
                  onChanged: (value) {
                    if (value != null) notifier.updateStatus(value);
                  },
                  validator: (value) => value == null
                      ? AppLocalizations.of(context)
                          .translate('please_select_status')
                      : null,
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildSupplierLocationSection(
      PurchaseCreationState state, PurchaseCreationNotifier notifier) {
    return Card(
      elevation: 4,
      shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.business,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).translate('supplier_location'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Supplier Search and Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _supplierSearchController,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('supplier'),
                      hintText:
                          AppLocalizations.of(context).translate('search'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: state.purchase?.contactId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _supplierSearchController.clear();
                                notifier.updateSupplier(0);
                                setState(() {
                                  _filteredSuppliers = state.suppliers;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_supplierSearchController.text.isNotEmpty &&
                      _filteredSuppliers.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _filteredSuppliers[index];
                          return ListTile(
                            title: Text(supplier.name),
                            subtitle: supplier.businessName != null
                                ? Text(supplier.businessName!)
                                : null,
                            onTap: () {
                              notifier.updateSupplier(supplier.id);
                              _supplierSearchController.text = supplier.name;
                              setState(() {
                                _filteredSuppliers = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  if (state.purchase?.contactId != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.suppliers
                                  .firstWhere(
                                    (s) => s.id == state.purchase?.contactId,
                                    orElse: () =>
                                        const Supplier(id: 0, name: 'Unknown'),
                                  )
                                  .name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Location (hardcoded for demo - should come from user/business context)
              TextFormField(
                initialValue: 'Main Location',
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('location'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                enabled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsSection(
      PurchaseCreationState state, PurchaseCreationNotifier notifier) {
    return Card(
        elevation: 4,
        shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).translate('products'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Product search
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isProductSearchFocused = hasFocus;
                      if (hasFocus && _productSearchController.text.isEmpty) {
                        _filteredProducts = state.products
                            .take(10)
                            .toList(); // Show first 10 products
                      }
                    });
                  },
                  child: TextFormField(
                    controller: _productSearchController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('search_product'),
                      hintText:
                          AppLocalizations.of(context).translate('search'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _productSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _productSearchController.clear();
                                setState(() {
                                  _filteredProducts = [];
                                  _isProductSearchFocused = false;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filtered products list
                if (_productSearchController.text.isNotEmpty ||
                    _isProductSearchFocused)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: _filteredProducts.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return ListTile(
                                title: Text(product.productName),
                                subtitle: product.subSku != null
                                    ? Text(product.subSku!)
                                    : null,
                                onTap: () {
                                  _showAddProductDialog(
                                      context, product, notifier);
                                  _productSearchController.clear();
                                  setState(() {
                                    _filteredProducts = [];
                                  });
                                },
                              );
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                _productSearchController.text.isNotEmpty
                                    ? 'No products found matching "${_productSearchController.text}"'
                                    : 'Start typing to search products...',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ),

                const SizedBox(height: 16),

                // Add Product Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showAddProductDialog(context, null, notifier),
                    icon: const Icon(Icons.add),
                    label: Text(
                        AppLocalizations.of(context).translate('add_product')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Product lines list
                if (state.purchase?.purchaseLines.isNotEmpty == true)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.purchase!.purchaseLines.length,
                    itemBuilder: (context, index) {
                      final line = state.purchase!.purchaseLines[index];
                      return _buildProductLineItem(line, index, notifier);
                    },
                  )
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No products added yet'),
                    ),
                  ),
              ],
            ),
          ),
        ));
  }

  Widget _buildProductLineItem(
      PurchaseLineItem line, int index, PurchaseCreationNotifier notifier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () =>
                      _showEditProductDialog(context, line, index, notifier),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => notifier.removeLineItem(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quantity: ${line.quantity}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Unit Price: \$${line.unitPrice.toStringAsFixed(2)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total: \$${line.lineTotal.toStringAsFixed(2)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSection(
      PurchaseCreationState state, PurchaseCreationNotifier notifier) {
    return Card(
      elevation: 4,
      shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calculate,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)
                        .translate('financial_information'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Discount
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _discountController,
                      decoration: const InputDecoration(
                        labelText: 'Discount Amount',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final amount = double.tryParse(value) ?? 0;
                        notifier.updateDiscount(amount: amount);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140),
                      child: DropdownButtonFormField<String>(
                        value: state.purchase?.discountType ?? 'fixed',
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: const OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'fixed', child: Text('Fixed')),
                          DropdownMenuItem(
                              value: 'percentage', child: Text('Percentage')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            notifier.updateDiscount(type: value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tax
              TextFormField(
                controller: _taxController,
                decoration: const InputDecoration(
                  labelText: 'Tax Amount',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  notifier.updateTax(taxAmount: amount);
                },
              ),

              const SizedBox(height: 16),

              // Shipping
              TextFormField(
                controller: _shippingController,
                decoration: const InputDecoration(
                  labelText: 'Shipping Charges',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  notifier.updateShipping(charges: amount);
                },
              ),

              const SizedBox(height: 16),

              // Totals
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text(
                            '\$${(state.purchase?.totalBeforeTax ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax:'),
                        Text(
                            '\$${(state.purchase?.taxAmount ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:'),
                        Text(
                            '-\$${(state.purchase?.discountAmount ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shipping:'),
                        Text(
                            '\$${(state.purchase?.shippingCharges ?? 0).toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${(state.purchase?.finalTotal ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection(
      PurchaseCreationState state, PurchaseCreationNotifier notifier) {
    return Card(
        elevation: 4,
        shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)
                          .translate('payment_information'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Add Payment Button
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showAddPaymentDialog(context, notifier),
                        icon: const Icon(Icons.payment),
                        label: const Text('Add Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Payment List
                if (state.purchase?.payments != null &&
                    state.purchase!.payments!.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.purchase!.payments!.length,
                    itemBuilder: (context, index) {
                      final payment = state.purchase!.payments![index];
                      return _buildPaymentItem(payment, index, notifier);
                    },
                  )
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No payments added yet'),
                    ),
                  ),

                const SizedBox(height: 16),

                // Total Paid
                if (state.purchase?.payments != null &&
                    state.purchase!.payments!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Paid:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${state.purchase!.payments!.fold<double>(0, (sum, payment) => sum + payment.amount).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ));
  }

  Widget _buildAdditionalInfoSection(
      PurchaseCreationState state, PurchaseCreationNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          onChanged: (value) => notifier.updateShipping(details: value),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate,
      Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  void _showAddProductDialog(BuildContext context, PurchaseProduct? product,
      PurchaseCreationNotifier notifier) {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
        text: product?.defaultPurchasePrice?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            product != null ? 'Add ${product.productName}' : 'Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product != null) ...[
              Text('Product: ${product.productName}'),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Unit Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 1;
              final price = double.tryParse(priceController.text) ?? 0;

              if (product != null) {
                notifier.addProduct(product, quantity, price);
              }

              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, PurchaseLineItem line,
      int index, PurchaseCreationNotifier notifier) {
    final quantityController =
        TextEditingController(text: line.quantity.toString());
    final priceController =
        TextEditingController(text: line.unitPrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${line.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Unit Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity =
                  double.tryParse(quantityController.text) ?? line.quantity;
              final price =
                  double.tryParse(priceController.text) ?? line.unitPrice;

              final updatedLine =
                  line.copyWith(quantity: quantity, unitPrice: price);
              notifier.updateLineItem(index, updatedLine);

              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
      PurchasePayment payment, int index, PurchaseCreationNotifier notifier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => notifier.removePayment(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '\$${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.credit_card, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatPaymentMethod(payment.method),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (payment.note != null && payment.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Note: ${payment.note}'),
            ],
            if (payment.paidOn != null) ...[
              const SizedBox(height: 4),
              Text(
                  'Paid on: ${DateFormat('yyyy-MM-dd').format(payment.paidOn!)}'),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog(
      BuildContext context, PurchaseCreationNotifier notifier) {
    _paymentAmountController.clear();
    _paymentNoteController.clear();
    String selectedMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _paymentAmountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(
                      value: 'bank_transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedMethod = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentNoteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount =
                    double.tryParse(_paymentAmountController.text) ?? 0;
                if (amount > 0) {
                  final payment = PurchasePayment(
                    amount: amount,
                    method: selectedMethod,
                    // Omit paidOn to let backend set and avoid format mismatch
                    note: _paymentNoteController.text.isEmpty
                        ? null
                        : _paymentNoteController.text,
                  );

                  notifier.addPayment(payment);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add Payment'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return method;
    }
  }

  void _submitPurchase() async {
    if (!_formKey.currentState!.validate()) return;

    final success =
        await ref.read(purchaseCreationProvider.notifier).submitPurchase();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase order created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form and prepare for a new entry
      _refNoController.clear();
      _discountController.clear();
      _taxController.clear();
      _shippingController.clear();
      _notesController.clear();
      _paymentAmountController.clear();
      _paymentNoteController.clear();
      ref.read(purchaseCreationProvider.notifier).reset();
    }
  }
}
