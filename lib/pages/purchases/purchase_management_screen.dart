import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/purchase_api_bridge.dart';
import '../../services/purchase_api_service.dart';
import '../../providers/purchase_management_provider.dart';
import '../../models/purchase_models.dart';
import '../../apis/contact.dart' as contact_api;
import '../../apis/product.dart';
import '../../helpers/AppTheme.dart';
import '../../helpers/SizeConfig.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Initialize with bridge for backward compatibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = ref.read(purchaseApiServiceProvider);
      _purchaseApi = PurchaseApiBridge(apiService);
      _contactApi = contact_api.CustomerApi();
      _productApi = ProductApi();
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
                    title: 'Total Purchases',
                    value: state.summary['total_purchases']?.toString() ?? '0',
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context: context,
                    title: 'Pending Orders',
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
                    title: 'Total Amount',
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
                    title: 'Active Suppliers',
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
              'Recent Purchases',
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
                  hintText: 'Search purchases...',
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
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('All Status')),
                        const DropdownMenuItem(
                            value: 'ordered', child: Text('Ordered')),
                        const DropdownMenuItem(
                            value: 'received', child: Text('Received')),
                        const DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        const DropdownMenuItem(
                            value: 'partial', child: Text('Partial')),
                        const DropdownMenuItem(
                            value: 'cancelled', child: Text('Cancelled')),
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
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('All Suppliers')),
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
                ? const Center(child: Text('No purchases found'))
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
          ? const Center(child: Text('No suppliers found'))
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
            'Purchase Reports',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Report Options
          _buildReportCard(
            context: context,
            title: 'Purchase Summary',
            description: 'Overview of all purchases',
            icon: Icons.summarize,
            onTap: () => _generatePurchaseSummaryReport(),
          ),

          _buildReportCard(
            context: context,
            title: 'Supplier Performance',
            description: 'Analysis of supplier performance',
            icon: Icons.analytics,
            onTap: () => _generateSupplierPerformanceReport(),
          ),

          _buildReportCard(
            context: context,
            title: 'Low Stock Items',
            description: 'Items that need reordering',
            icon: Icons.warning,
            onTap: () => _generateLowStockReport(),
          ),

          _buildReportCard(
            context: context,
            title: 'Purchase Trends',
            description: 'Monthly purchase trends',
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

  Widget _buildPurchaseCard(BuildContext context, Purchase purchase,
      PurchaseManagementState state, PurchaseManagementNotifier notifier) {
    final supplier = state.suppliers.firstWhere(
      (s) => s.id == purchase.contactId,
      orElse: () => const Supplier(id: 0, name: 'Unknown'),
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
            Text('Supplier: ${supplier.name}'),
            Text('Date: ${purchase.transactionDate.toString().split(' ')[0]}'),
            Text('Amount: \$${purchase.finalTotal.toStringAsFixed(2)}'),
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

  Widget _buildSupplierCard(BuildContext context, Supplier supplier) {
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
            Text('Mobile: ${supplier.mobile ?? 'N/A'}'),
            Text('Balance: \$${supplier.balance ?? 0.00}'),
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
          orElse: () => const Supplier(id: 0, name: 'Unknown'),
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

  void _showPurchaseDetails(BuildContext context, Purchase purchase,
      PurchaseManagementNotifier notifier) {
    // Implementation for purchase details dialog/screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase Details - PO-${purchase.refNo ?? purchase.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Supplier: ${purchase.contactId}'), // Will be resolved to name later
              Text(
                  'Date: ${purchase.transactionDate.toString().split(' ')[0]}'),
              Text('Status: ${purchase.status}'),
              Text('Total: \$${purchase.finalTotal.toStringAsFixed(2)}'),
              // Add more details as needed
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement edit functionality
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showSupplierDetails(BuildContext context, Supplier supplier) {
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
              Text('Mobile: ${supplier.mobile ?? 'N/A'}'),
              Text('Address: ${supplier.address ?? 'N/A'}'),
              Text('Balance: \$${supplier.balance ?? 0.00}'),
              // Add more supplier details
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _generatePurchaseSummaryReport() {
    // Implementation for purchase summary report
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Purchase Summary Report - Feature coming soon!')),
    );
  }

  void _generateSupplierPerformanceReport() {
    // Implementation for supplier performance report
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Supplier Performance Report - Feature coming soon!')),
    );
  }

  void _generateLowStockReport() {
    // Implementation for low stock report
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Low Stock Report - Feature coming soon!')),
    );
  }

  void _generatePurchaseTrendsReport() {
    // Implementation for purchase trends report
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Purchase Trends Report - Feature coming soon!')),
    );
  }
}
