import 'dart:developer';
import 'package:flutter/material.dart';
import '../../apis/product.dart';
import '../../helpers/AppTheme.dart';
import '../../locale/MyLocalizations.dart';

class ProductManagementScreen extends StatefulWidget {
  static const String routeName = '/ProductManagementScreen';

  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ProductApi _productApi;

  // Data variables
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _lowStockProducts = [];
  List<dynamic> _outOfStockProducts = [];
  Map<String, dynamic> _selectedProduct = {};

  // UI State
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  String _sortBy = 'name';
  String _sortOrder = 'asc';

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _productApi = ProductApi();

    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadProducts(),
        _loadCategories(),
        _loadLowStockProducts(),
        _loadOutOfStockProducts(),
      ]);
    } catch (e) {
      log('Error loading initial data: $e');
      _showErrorSnackBar('Failed to load data. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final result = await _productApi.getProducts(
        categoryId:
            _selectedCategory != 'all' ? int.tryParse(_selectedCategory) : null,
        searchTerm: _searchQuery.isNotEmpty ? _searchQuery : null,
        perPage: 50,
        orderBy: _sortBy,
        orderDirection: _sortOrder,
      );

      if (mounted) {
        setState(() => _products = result['data'] ?? []);
      }
    } catch (e) {
      log('Error loading products: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _productApi.getProductCategories();
      if (mounted) {
        setState(() => _categories = result);
      }
    } catch (e) {
      log('Error loading categories: $e');
    }
  }

  Future<void> _loadLowStockProducts() async {
    try {
      final result = await _productApi.getLowStockProducts(threshold: 10);
      if (mounted) {
        setState(() => _lowStockProducts = result);
      }
    } catch (e) {
      log('Error loading low stock products: $e');
    }
  }

  Future<void> _loadOutOfStockProducts() async {
    try {
      final result = await _productApi.getOutOfStockProducts();
      if (mounted) {
        setState(() => _outOfStockProducts = result);
      }
    } catch (e) {
      log('Error loading out of stock products: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadInitialData();
    setState(() => _isRefreshing = false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _refreshData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).translate('product_management'),
          style: AppTheme.getTextStyle(
            Theme.of(context).textTheme.titleLarge!,
            fontWeight: 600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: AppLocalizations.of(context).translate('products')),
            Tab(text: AppLocalizations.of(context).translate('categories')),
            Tab(text: AppLocalizations.of(context).translate('inventory')),
            Tab(text: AppLocalizations.of(context).translate('analytics')),
            Tab(text: AppLocalizations.of(context).translate('settings')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateProductDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildCategoriesTab(),
                _buildInventoryTab(),
                _buildAnalyticsTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        // Search and Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              // Search
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadProducts();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  // Debounce search
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_searchQuery == value) {
                      _loadProducts();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Filter Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('All Categories')),
                        ..._categories.map((category) => DropdownMenuItem(
                              value: category['id'].toString(),
                              child: Text(category['name'] ?? 'Unknown'),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value!);
                        _loadProducts();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                        DropdownMenuItem(value: 'sku', child: Text('SKU')),
                        DropdownMenuItem(
                            value: 'created_at', child: Text('Date Created')),
                        DropdownMenuItem(
                            value: 'updated_at', child: Text('Last Updated')),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value!);
                        _loadProducts();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProducts,
            child: _products.isEmpty
                ? const Center(child: Text('No products found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product Categories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateCategoryDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('No categories found'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _buildCategoryCard(category);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'All Items'),
              Tab(text: 'Low Stock'),
              Tab(text: 'Out of Stock'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildInventoryList(_products),
                _buildInventoryList(_lowStockProducts),
                _buildInventoryList(_outOfStockProducts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Analytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Analytics Cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Products',
                  value: _products.length.toString(),
                  icon: Icons.inventory,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Low Stock Items',
                  value: _lowStockProducts.length.toString(),
                  icon: Icons.warning,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Out of Stock',
                  value: _outOfStockProducts.length.toString(),
                  icon: Icons.error,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Categories',
                  value: _categories.length.toString(),
                  icon: Icons.category,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Top Products
          Text(
            'Top Performing Products',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildTopProductsList(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Settings Options
          _buildSettingCard(
            title: 'Bulk Import',
            description: 'Import products from CSV/Excel',
            icon: Icons.upload_file,
            onTap: () => _showBulkImportDialog(),
          ),

          _buildSettingCard(
            title: 'Bulk Export',
            description: 'Export products to CSV/Excel',
            icon: Icons.download,
            onTap: () => _showBulkExportDialog(),
          ),

          _buildSettingCard(
            title: 'Stock Alerts',
            description: 'Configure low stock notifications',
            icon: Icons.notifications,
            onTap: () => _showStockAlertsDialog(),
          ),

          _buildSettingCard(
            title: 'Barcode Settings',
            description: 'Configure barcode generation',
            icon: Icons.qr_code,
            onTap: () => _showBarcodeSettingsDialog(),
          ),

          _buildSettingCard(
            title: 'Pricing Rules',
            description: 'Set up automated pricing rules',
            icon: Icons.price_change,
            onTap: () => _showPricingRulesDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final stockStatus = _getStockStatus(product);
    final stockColor = _getStockStatusColor(stockStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: stockColor,
          child: Icon(
            _getStockStatusIcon(stockStatus),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          product['name'] ?? 'Unknown Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${product['sku'] ?? 'N/A'}'),
            Text('Stock: ${product['current_stock'] ?? 0}'),
            Text(
              'Price: \$${product['selling_price'] ?? '0.00'}',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleProductAction(value, product),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
            const PopupMenuItem(
                value: 'view_analytics', child: Text('View Analytics')),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Category: ${product['category']?['name'] ?? 'Uncategorized'}'),
                Text('Type: ${product['type'] ?? 'Unknown'}'),
                Text('Created: ${product['created_at'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _updateStock(product),
                      icon: const Icon(Icons.inventory),
                      label: const Text('Update Stock'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _viewProductAnalytics(product),
                      icon: const Icon(Icons.analytics),
                      label: const Text('Analytics'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Card(
      child: InkWell(
        onTap: () => _showCategoryDetails(category),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                category['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${category['products_count'] ?? 0} products',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryList(List<dynamic> products) {
    return products.isEmpty
        ? const Center(child: Text('No items found'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildInventoryCard(product);
            },
          );
  }

  Widget _buildInventoryCard(Map<String, dynamic> product) {
    final stockStatus = _getStockStatus(product);
    final stockColor = _getStockStatusColor(stockStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stockColor,
          child: Icon(
            _getStockStatusIcon(stockStatus),
            color: Colors.white,
          ),
        ),
        title: Text(product['name'] ?? 'Unknown Product'),
        subtitle: Text('SKU: ${product['sku'] ?? 'N/A'}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product['current_stock'] ?? 0}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: stockColor,
              ),
            ),
            Text(
              stockStatus,
              style: TextStyle(
                fontSize: 12,
                color: stockColor,
              ),
            ),
          ],
        ),
        onTap: () => _updateStock(product),
      ),
    );
  }

  Widget _buildAnalyticsCard({
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

  Widget _buildTopProductsList() {
    // Mock top products data - in real app, this would come from analytics API
    final topProducts = _products.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topProducts.length,
      itemBuilder: (context, index) {
        final product = topProducts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text('${index + 1}'),
          ),
          title: Text(product['name'] ?? 'Unknown'),
          subtitle: Text('SKU: ${product['sku'] ?? 'N/A'}'),
          trailing: Text(
            '\$${product['selling_price'] ?? '0.00'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingCard({
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

  String _getStockStatus(Map<String, dynamic> product) {
    final stock = product['current_stock'] ?? 0;
    if (stock <= 0) return 'Out of Stock';
    if (stock <= 10) return 'Low Stock';
    return 'In Stock';
  }

  Color _getStockStatusColor(String status) {
    switch (status) {
      case 'Out of Stock':
        return Colors.red;
      case 'Low Stock':
        return Colors.orange;
      case 'In Stock':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStockStatusIcon(String status) {
    switch (status) {
      case 'Out of Stock':
        return Icons.error;
      case 'Low Stock':
        return Icons.warning;
      case 'In Stock':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  void _handleProductAction(String action, Map<String, dynamic> product) {
    switch (action) {
      case 'edit':
        _showEditProductDialog(product);
        break;
      case 'duplicate':
        _duplicateProduct(product);
        break;
      case 'delete':
        _showDeleteProductDialog(product);
        break;
      case 'view_analytics':
        _viewProductAnalytics(product);
        break;
    }
  }

  void _showCreateProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Product'),
        content: const Text('Product creation form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement product creation
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Product - ${product['name']}'),
        content: const Text('Product editing form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement product editing
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteProduct(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Category'),
        content: const Text('Category creation form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement category creation
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCategoryDetails(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Category: ${category['name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Products: ${category['products_count'] ?? 0}'),
              Text('Created: ${category['created_at'] ?? 'N/A'}'),
              // Add more category details
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
              // Implement category editing
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateProduct(Map<String, dynamic> product) async {
    try {
      final result =
          await _productApi.duplicateProduct(product['id'].toString());
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product duplicated successfully')),
        );
        _loadProducts();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to duplicate product');
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    try {
      final success = await _productApi.deleteProduct(product['id'].toString());
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
        _loadProducts();
      } else {
        _showErrorSnackBar('Failed to delete product');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete product');
    }
  }

  void _updateStock(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${product['name']}'),
        content: const Text('Stock update form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement stock update
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _viewProductAnalytics(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Analytics - ${product['name']}'),
        content: const Text('Product analytics will be displayed here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk Import - Feature coming soon!')),
    );
  }

  void _showBulkExportDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk Export - Feature coming soon!')),
    );
  }

  void _showStockAlertsDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Stock Alerts Settings - Feature coming soon!')),
    );
  }

  void _showBarcodeSettingsDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barcode Settings - Feature coming soon!')),
    );
  }

  void _showPricingRulesDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pricing Rules - Feature coming soon!')),
    );
  }
}
