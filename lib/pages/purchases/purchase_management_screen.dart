import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../services/purchase_api_bridge.dart';
import '../../services/purchase_api_service.dart';
import '../../providers/purchase_management_provider.dart';
import '../../models/purchase_models.dart' as purchase_models;
import '../../models/purchase.dart' as purchase_db;
import '../../models/purchaseDatabase.dart';
import '../../apis/contact.dart' as contact_api;
import '../../apis/product.dart';
import '../../helpers/AppTheme.dart';
import '../../helpers/SizeConfig.dart';
import '../../helpers/otherHelpers.dart';
import '../../locale/MyLocalizations.dart';
import 'purchase_creation_screen.dart';

class PurchaseManagementScreen extends ConsumerStatefulWidget {
  static const String routeName = '/PurchaseManagementScreen';

  const PurchaseManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PurchaseManagementScreen> createState() =>
      _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState
    extends ConsumerState<PurchaseManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PurchaseApiBridge _purchaseApi;
  late contact_api.CustomerApi _contactApi;
  late ProductApi _productApi;

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  // Offline storage variables
  bool _isSynced = true;
  bool _isSyncing = false;

  // Theme variables
  static int themeType = 1;
  late ThemeData themeData;
  late CustomAppTheme customAppTheme;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    themeData = AppTheme.getThemeFromThemeMode(themeType);
    customAppTheme = AppTheme.getCustomAppTheme(themeType);
    // Initialize with bridge for backward compatibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = ref.read(purchaseApiServiceProvider);
      _purchaseApi = PurchaseApiBridge(apiService);
      _contactApi = contact_api.CustomerApi();
      _productApi = ProductApi();
      _loadPurchasesFromDatabase();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            ref.read(purchaseManagementProvider.notifier).refreshData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseManagementProvider);
    final notifier = ref.read(purchaseManagementProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).translate('purchase_management'),
          style: AppTheme.getTextStyle(
            Theme.of(context).textTheme.titleLarge!,
            fontWeight: 600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: AppLocalizations.of(context).translate('overview')),
            Tab(text: AppLocalizations.of(context).translate('purchases')),
            Tab(text: AppLocalizations.of(context).translate('suppliers')),
            Tab(text: AppLocalizations.of(context).translate('reports')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSyncing ? null : () => _syncPurchases(),
            child: Text(
              AppLocalizations.of(context).translate('sync'),
              style: AppTheme.getTextStyle(themeData.textTheme.subtitle1,
                  fontWeight: (_isSynced) ? 500 : 900, letterSpacing: -0.2),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isRefreshing ? null : () => notifier.refreshData(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePurchaseDialog(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context, state, notifier),
                _buildPurchasesTab(context, state, notifier),
                _buildSuppliersTab(context, state, notifier),
                _buildReportsTab(context),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, PurchaseManagementState state,
      PurchaseManagementNotifier notifier) {
    return RefreshIndicator(
      onRefresh: () => notifier.refreshData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context: context,
                    title: AppLocalizations.of(context)
                        .translate('total_purchases'),
                    value: state.summary['total_purchases']?.toString() ?? '0',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context: context,
                    title: AppLocalizations.of(context)
                        .translate('pending_orders'),
                    value: state.summary['pending_orders']?.toString() ?? '0',
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context: context,
                    title:
                        AppLocalizations.of(context).translate('total_amount'),
                    value:
                        '\$${state.summary['total_amount']?.toString() ?? '0.00'}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context: context,
                    title: AppLocalizations.of(context)
                        .translate('active_suppliers'),
                    value: state.suppliers.length.toString(),
                    icon: Icons.business,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Purchases
            Text(
              AppLocalizations.of(context).translate('recent_purchases'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildRecentPurchasesList(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasesTab(BuildContext context, PurchaseManagementState state,
      PurchaseManagementNotifier notifier) {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              // Search
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)
                      .translate('search_purchases'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  notifier.updateFilters(searchQuery: value);
                },
              ),
              const SizedBox(height: 16),

              // Filter Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: state.selectedStatus,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context).translate('status'),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text(AppLocalizations.of(context)
                                .translate('all_status'))),
                        DropdownMenuItem(
                            value: 'ordered',
                            child: Text(AppLocalizations.of(context)
                                .translate('ordered'))),
                        DropdownMenuItem(
                            value: 'received',
                            child: Text(AppLocalizations.of(context)
                                .translate('received'))),
                        DropdownMenuItem(
                            value: 'pending',
                            child: Text(AppLocalizations.of(context)
                                .translate('pending'))),
                        DropdownMenuItem(
                            value: 'partial',
                            child: Text(AppLocalizations.of(context)
                                .translate('partial'))),
                        DropdownMenuItem(
                            value: 'cancelled',
                            child: Text(AppLocalizations.of(context)
                                .translate('cancelled'))),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          notifier.updateFilters(status: value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: state.selectedSupplier,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context).translate('supplier'),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text(AppLocalizations.of(context)
                                .translate('all_suppliers'))),
                        ...state.suppliers.map((supplier) => DropdownMenuItem(
                              value: supplier.id.toString(),
                              child: Text(supplier.name),
                            )),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          notifier.updateFilters(supplier: value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Purchase List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => notifier.loadPurchases(),
            child: state.filteredPurchases.isEmpty
                ? Center(
                    child: Text(AppLocalizations.of(context)
                        .translate('no_purchases_found')))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.filteredPurchases.length,
                    itemBuilder: (context, index) {
                      final purchase = state.filteredPurchases[index];
                      return _buildPurchaseCard(
                          context, purchase, state, notifier);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab(BuildContext context, PurchaseManagementState state,
      PurchaseManagementNotifier notifier) {
    return RefreshIndicator(
      onRefresh: () => notifier.loadSuppliers(),
      child: state.suppliers.isEmpty
          ? Center(
              child: Text(
                  AppLocalizations.of(context).translate('no_suppliers_found')))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.suppliers.length,
              itemBuilder: (context, index) {
                final supplier = state.suppliers[index];
                return _buildSupplierCard(context, supplier);
              },
            ),
    );
  }

  Widget _buildReportsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).translate('purchase_trends'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Report Options
          _buildReportCard(
            context: context,
            title: AppLocalizations.of(context).translate('purchase_summary'),
            description: AppLocalizations.of(context)
                .translate('overview_of_all_purchases'),
            icon: Icons.summarize,
            onTap: () => _generatePurchaseSummaryReport(),
          ),

          _buildReportCard(
            context: context,
            title:
                AppLocalizations.of(context).translate('supplier_performance'),
            description: AppLocalizations.of(context)
                .translate('analysis_of_supplier_performance'),
            icon: Icons.analytics,
            onTap: () => _generateSupplierPerformanceReport(),
          ),

          _buildReportCard(
            context: context,
            title: AppLocalizations.of(context).translate('low_stock_items'),
            description: AppLocalizations.of(context)
                .translate('items_that_need_reordering'),
            icon: Icons.warning,
            onTap: () => _generateLowStockReport(),
          ),

          _buildReportCard(
            context: context,
            title: AppLocalizations.of(context).translate('purchase_trends'),
            description: AppLocalizations.of(context)
                .translate('monthly_purchase_trends'),
            icon: Icons.trending_up,
            onTap: () => _generatePurchaseTrendsReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(
      BuildContext context,
      purchase_models.Purchase purchase,
      PurchaseManagementState state,
      PurchaseManagementNotifier notifier) {
    final supplier = state.suppliers.firstWhere(
      (s) => s.id == purchase.contactId,
      orElse: () => const purchase_models.Supplier(id: 0, name: 'Unknown'),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(purchase.status),
          child: Icon(
            _getStatusIcon(purchase.status),
            color: Colors.white,
          ),
        ),
        title: Text(
          'PO-${purchase.refNo ?? purchase.id}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${AppLocalizations.of(context).translate('supplier')}: ${supplier.name}'),
            Text(
                '${AppLocalizations.of(context).translate('transaction_date')}: ${purchase.transactionDate.toString().split(' ')[0]}'),
            Text(
                '${AppLocalizations.of(context).translate('total')}: \$${purchase.finalTotal.toStringAsFixed(2)}'),
          ],
        ),
        trailing: Text(
          purchase.status.toUpperCase(),
          style: TextStyle(
            color: _getStatusColor(purchase.status),
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _showPurchaseDetails(context, purchase, notifier),
      ),
    );
  }

  Widget _buildSupplierCard(
      BuildContext context, purchase_models.Supplier supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.business, color: Colors.white),
        ),
        title: Text(
          supplier.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${AppLocalizations.of(context).translate('mobile')}: ${supplier.mobile ?? 'N/A'}'),
            Text(
                '${AppLocalizations.of(context).translate('balance')}: \$${supplier.balance ?? 0.00}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.call),
          onPressed: () {
            // Implement call functionality
          },
        ),
        onTap: () => _showSupplierDetails(context, supplier),
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentPurchasesList(
      BuildContext context, PurchaseManagementState state) {
    final recentPurchases = state.purchases.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentPurchases.length,
      itemBuilder: (context, index) {
        final purchase = recentPurchases[index];
        final supplier = state.suppliers.firstWhere(
          (s) => s.id == purchase.contactId,
          orElse: () => const purchase_models.Supplier(id: 0, name: 'Unknown'),
        );

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(purchase.status),
            child: Icon(_getStatusIcon(purchase.status),
                color: Colors.white, size: 20),
          ),
          title: Text('PO-${purchase.refNo ?? purchase.id}'),
          subtitle: Text(
              '${supplier.name} • \$${purchase.finalTotal.toStringAsFixed(2)}'),
          trailing: Text(
            purchase.status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(purchase.status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'received':
        return Colors.green;
      case 'ordered':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'partial':
        return Colors.amber;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'received':
        return Icons.check_circle;
      case 'ordered':
        return Icons.shopping_cart;
      case 'pending':
        return Icons.hourglass_empty;
      case 'partial':
        return Icons.inventory;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _showCreatePurchaseDialog() {
    // Navigate to the purchase creation screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PurchaseCreationScreen(),
      ),
    );
  }

  void _showPurchaseDetails(BuildContext context,
      purchase_models.Purchase purchase, PurchaseManagementNotifier notifier) {
    final state = ref.read(purchaseManagementProvider);
    final supplier = state.suppliers.firstWhere(
      (s) => s.id == purchase.contactId,
      orElse: () => const purchase_models.Supplier(id: 0, name: 'Unknown'),
    );

    // Implementation for purchase details dialog/screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            '${AppLocalizations.of(context).translate('purchase_details')} - PO-${purchase.refNo ?? purchase.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${AppLocalizations.of(context).translate('supplier')}: ${supplier.name}'),
              Text(
                  '${AppLocalizations.of(context).translate('transaction_date')}: ${purchase.transactionDate.toString().split(' ')[0]}'),
              Text(
                  '${AppLocalizations.of(context).translate('status')}: ${purchase.status}'),
              Text(
                  '${AppLocalizations.of(context).translate('total')}: \$${purchase.finalTotal.toStringAsFixed(2)}'),
              // Add more details as needed
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).translate('close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement edit functionality
            },
            child: Text(AppLocalizations.of(context).translate('edit')),
          ),
        ],
      ),
    );
  }

  void _showSupplierDetails(
      BuildContext context, purchase_models.Supplier supplier) {
    // Implementation for supplier details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${AppLocalizations.of(context).translate('mobile')}: ${supplier.mobile ?? 'N/A'}'),
              Text(
                  '${AppLocalizations.of(context).translate('address')}: ${supplier.address ?? 'N/A'}'),
              Text(
                  '${AppLocalizations.of(context).translate('balance')}: \$${supplier.balance ?? 0.00}'),
              // Add more supplier details
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).translate('close')),
          ),
        ],
      ),
    );
  }

  void _generatePurchaseSummaryReport() {
    // Implementation for purchase summary report
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${AppLocalizations.of(context).translate('purchase_summary')} - ${AppLocalizations.of(context).translate('feature_coming_soon')}')),
    );
  }

  void _generateSupplierPerformanceReport() {
    // Implementation for supplier performance report
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${AppLocalizations.of(context).translate('supplier_performance')} - ${AppLocalizations.of(context).translate('feature_coming_soon')}')),
    );
  }

  void _generateLowStockReport() {
    // Implementation for low stock report
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${AppLocalizations.of(context).translate('low_stock_items')} - ${AppLocalizations.of(context).translate('feature_coming_soon')}')),
    );
  }

  void _generatePurchaseTrendsReport() {
    // Implementation for purchase trends report
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${AppLocalizations.of(context).translate('purchase_trends')} - ${AppLocalizations.of(context).translate('feature_coming_soon')}')),
    );
  }

  // Load purchases from local database
  void _loadPurchasesFromDatabase() async {
    try {
      List purchases = await PurchaseDatabase().getPurchases();
      // Check if any purchases are not synced
      for (var purchase in purchases) {
        if (purchase['is_synced'] == 0) {
          setState(() {
            _isSynced = false;
          });
          break;
        }
      }
      // Update the provider with local data if needed
      // This would require modifying the provider to accept local data
    } catch (e) {
      log('Error loading purchases from database: $e');
    }
  }

  // Show toast message using snackbar (fluttertoast has initialization issues)
  void _showToast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Sync purchases with server
  void _syncPurchases() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      if (await Helper().checkConnectivity()) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  Container(
                      margin: EdgeInsets.only(left: 5),
                      child: Text(AppLocalizations.of(context)
                          .translate('sync_in_progress'))),
                ],
              ),
            );
          },
        );

        final notifier = ref.read(purchaseManagementProvider.notifier);
        final success = await notifier.syncPurchases();
        Navigator.pop(context);

        if (success) {
          setState(() {
            _isSynced = true;
            _isSyncing = false;
          });
          _showToast(AppLocalizations.of(context).translate('sync_completed'));
        } else {
          setState(() {
            _isSyncing = false;
          });
          _showToast(AppLocalizations.of(context).translate('sync_failed'));
        }
      } else {
        _showToast(
            AppLocalizations.of(context).translate('check_connectivity'));
        setState(() {
          _isSyncing = false;
        });
      }
    } catch (e) {
      log('Error syncing purchases: $e');
      setState(() {
        _isSyncing = false;
      });
      _showToast(AppLocalizations.of(context).translate('sync_failed'));
    }
  }
}
