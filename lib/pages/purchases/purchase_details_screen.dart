import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/purchase_models.dart';
import '../../providers/purchase_management_provider.dart';
import '../../helpers/AppTheme.dart';
import '../../helpers/SizeConfig.dart';

/// Purchase Details Screen
class PurchaseDetailsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/purchase-details';

  final int purchaseId;

  const PurchaseDetailsScreen({
    Key? key,
    required this.purchaseId,
  }) : super(key: key);

  @override
  ConsumerState<PurchaseDetailsScreen> createState() =>
      _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends ConsumerState<PurchaseDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final purchaseAsync = ref.watch(purchaseDetailsProvider(widget.purchaseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit screen
              _navigateToEdit();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ],
      ),
      body: purchaseAsync.when(
        data: (purchase) => purchase != null
            ? _buildPurchaseDetails(purchase)
            : const Center(child: Text('Purchase not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading purchase: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(purchaseDetailsProvider(widget.purchaseId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseDetails(Purchase purchase) {
    final state = ref.watch(purchaseManagementProvider);
    final supplier = state.suppliers.firstWhere(
      (s) => s.id == purchase.contactId,
      orElse: () => const Supplier(id: 0, name: 'Unknown Supplier'),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Purchase Header
          _buildHeaderSection(purchase, supplier),

          const SizedBox(height: 24),

          // Purchase Information
          _buildInfoSection(purchase),

          const SizedBox(height: 24),

          // Line Items
          _buildLineItemsSection(purchase),

          const SizedBox(height: 24),

          // Financial Summary
          _buildFinancialSection(purchase),

          const SizedBox(height: 24),

          // Additional Information
          _buildAdditionalInfoSection(purchase),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(Purchase purchase, Supplier supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PO-${purchase.refNo ?? purchase.id}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                _buildStatusChip(purchase.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Supplier: ${supplier.name}'),
            Text('Date: ${purchase.transactionDate.toString().split(' ')[0]}'),
            if (supplier.businessName != null)
              Text('Business: ${supplier.businessName}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Purchase purchase) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Reference Number', purchase.refNo ?? 'N/A'),
            _buildInfoRow('Transaction Date',
                purchase.transactionDate.toString().split(' ')[0]),
            _buildInfoRow('Status', purchase.status.toUpperCase()),
            if (purchase.payTermType != null)
              _buildInfoRow('Payment Terms',
                  '${purchase.payTermType} - ${purchase.payTermNumber ?? 0} days'),
            if (purchase.additionalNotes != null &&
                purchase.additionalNotes!.isNotEmpty)
              _buildInfoRow('Notes', purchase.additionalNotes!),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsSection(Purchase purchase) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line Items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: purchase.purchaseLines.length,
              itemBuilder: (context, index) {
                final line = purchase.purchaseLines[index];
                return _buildLineItem(line);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(PurchaseLineItem line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    line.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '\$${line.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Quantity: ${line.quantity}'),
                ),
                Expanded(
                  child: Text(
                      'Unit Price: \$${line.unitPrice.toStringAsFixed(2)}'),
                ),
              ],
            ),
            if (line.lineDiscountAmount != null && line.lineDiscountAmount! > 0)
              Text(
                  'Discount: \$${line.lineDiscountAmount!.toStringAsFixed(2)}'),
            if (line.itemTax != null && line.itemTax! > 0)
              Text('Tax: \$${line.itemTax!.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSection(Purchase purchase) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildFinancialRow('Subtotal', purchase.totalBeforeTax),
            if (purchase.discountAmount != null && purchase.discountAmount! > 0)
              _buildFinancialRow('Discount', -purchase.discountAmount!),
            if (purchase.taxAmount != null && purchase.taxAmount! > 0)
              _buildFinancialRow('Tax', purchase.taxAmount!),
            if (purchase.shippingCharges != null &&
                purchase.shippingCharges! > 0)
              _buildFinancialRow('Shipping', purchase.shippingCharges!),
            const Divider(),
            _buildFinancialRow('Total', purchase.finalTotal, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection(Purchase purchase) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Business ID', purchase.businessId.toString()),
            _buildInfoRow('Location ID', purchase.locationId.toString()),
            if (purchase.exchangeRate != null)
              _buildInfoRow('Exchange Rate', purchase.exchangeRate.toString()),
            if (purchase.createdAt != null)
              _buildInfoRow(
                  'Created', purchase.createdAt!.toString().split(' ')[0]),
            if (purchase.updatedAt != null)
              _buildInfoRow(
                  'Updated', purchase.updatedAt!.toString().split(' ')[0]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, double amount,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'received':
        color = Colors.green;
        break;
      case 'ordered':
        color = Colors.blue;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'partial':
        color = Colors.amber;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
    );
  }

  void _navigateToEdit() {
    // TODO: Navigate to edit screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon!')),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: const Text(
            'Are you sure you want to delete this purchase? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deletePurchase();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePurchase() async {
    final notifier = ref.read(purchaseManagementProvider.notifier);
    final success = await notifier.deletePurchase(widget.purchaseId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase deleted successfully')),
      );
      Navigator.of(context).pop(); // Go back to list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete purchase')),
      );
    }
  }
}
