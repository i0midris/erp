# Purchase Creation Flutter Integration

This document provides a comprehensive guide for integrating purchase creation functionality into a Flutter application, based on the Modules/Connector purchase system implementation.

## Overview

The purchase creation system allows users to create purchase orders with suppliers, add products, calculate totals, and manage financial information. This integration replicates the backend API functionality with a modern Flutter UI.

## Architecture

### Components

1. **Data Models** (`purchase_models.dart`)
   - `Purchase`: Main purchase entity
   - `PurchaseLineItem`: Individual product lines
   - `PurchasePayment`: Payment information
   - `Supplier`: Supplier information
   - `PurchaseProduct`: Product data for selection

2. **API Service** (`purchase_api_service.dart`)
   - Dio-based HTTP client
   - Comprehensive error handling
   - Authentication integration
   - CRUD operations for purchases

3. **State Management** (`purchase_provider.dart`)
   - Riverpod-based state management
   - Form validation
   - Business logic separation
   - Async operation handling

4. **UI Components** (`purchase_creation_screen.dart`)
   - Complete purchase creation form
   - Product selection and management
   - Financial calculations
   - Error handling and user feedback

## Setup

### Dependencies

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.0.0
  flutter_riverpod: ^2.4.9
  equatable: ^2.0.5
  intl: ^0.18.1
  shared_preferences: ^2.0.17

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.6
  json_serializable: ^6.7.1
```

### Configuration

1. **API Configuration**
   ```dart
   // In your main.dart or app initialization
   final container = ProviderContainer();
   // Configure your API base URL
   ```

2. **Provider Setup**
   ```dart
   void main() {
     runApp(
       ProviderScope(
         child: MyApp(),
       ),
     );
   }
   ```

## Usage

### Basic Purchase Creation

```dart
// Navigate to purchase creation screen
Navigator.pushNamed(context, PurchaseCreationScreen.routeName);

// Or use with Riverpod
final purchaseState = ref.watch(purchaseCreationProvider);
```

### API Integration

```dart
// Get API service instance
final apiService = ref.read(purchaseApiServiceProvider);

// Create a purchase
final request = CreatePurchaseRequest(
  purchase: Purchase(
    businessId: 1,
    contactId: supplierId,
    locationId: locationId,
    status: 'ordered',
    transactionDate: DateTime.now(),
    totalBeforeTax: 100.0,
    finalTotal: 110.0,
    purchaseLines: [/* line items */],
  ),
);

final createdPurchase = await apiService.createPurchase(request);
```

### State Management

```dart
// Watch purchase creation state
final state = ref.watch(purchaseCreationProvider);

// Update purchase data
final notifier = ref.read(purchaseCreationProvider.notifier);
notifier.updateSupplier(supplierId);
notifier.addProduct(product, quantity, price);

// Submit purchase
final success = await notifier.submitPurchase();
```

## API Endpoints

Based on the Modules/Connector implementation:

### Purchase Management
- `GET /connector/api/purchase` - List purchases
- `POST /connector/api/purchase` - Create purchase
- `GET /connector/api/purchase/{id}` - Get purchase details
- `PUT /connector/api/purchase/{id}` - Update purchase
- `DELETE /connector/api/purchase/{id}` - Delete purchase
- `POST /connector/api/purchase/{id}/status` - Update status

### Suppliers & Products
- `GET /connector/api/purchase/suppliers` - Get suppliers
- `GET /connector/api/purchase/products` - Get products
- `GET /connector/api/purchase/check-ref` - Check reference number

## Data Structures

### Purchase Request Format

```json
{
  "contact_id": 2,
  "location_id": 1,
  "ref_no": "PO2024/0001",
  "status": "ordered",
  "transaction_date": "2024-01-01 10:00:00",
  "total_before_tax": 100.00,
  "discount_type": "fixed",
  "discount_amount": 10.00,
  "tax_id": 1,
  "tax_amount": 9.00,
  "shipping_charges": 5.00,
  "final_total": 104.00,
  "additional_notes": "Urgent delivery required",
  "purchases": [
    {
      "product_id": 1,
      "variation_id": 1,
      "quantity": 10,
      "unit_price": 10.00,
      "line_discount_amount": 0,
      "line_discount_type": "fixed",
      "item_tax_id": 1,
      "item_tax": 0.90
    }
  ],
  "payments": [
    {
      "amount": 104.00,
      "method": "cash",
      "paid_on": "2024-01-01",
      "account_id": 1
    }
  ]
}
```

### Purchase Response Format

```json
{
  "success": true,
  "msg": "Purchase added successfully",
  "data": {
    "id": 1,
    "business_id": 1,
    "contact_id": 2,
    "ref_no": "PO2024/0001",
    "status": "ordered",
    "final_total": "104.00",
    "transaction_date": "2024-01-01 10:00:00",
    "contact": {
      "id": 2,
      "name": "Supplier Name"
    },
    "lines": [
      {
        "product_id": 1,
        "variation_id": 1,
        "product_name": "Product Name",
        "quantity": 10,
        "unit_price": "10.00"
      }
    ],
    "payments": [
      {
        "amount": "104.00",
        "method": "cash",
        "paid_on": "2024-01-01"
      }
    ]
  }
}
```

## Error Handling

### API Error Types

1. **Authentication Errors** (401)
   - Token expired or invalid
   - Redirect to login

2. **Validation Errors** (422)
   - Form validation failures
   - Display field-specific errors

3. **Permission Errors** (403)
   - User lacks required permissions
   - Show permission denied message

4. **Server Errors** (500)
   - Internal server errors
   - Show generic error message

5. **Network Errors**
   - Connection timeouts
   - No internet connectivity
   - Retry mechanisms

### Error Handling Implementation

```dart
try {
  final result = await apiService.createPurchase(request);
  // Handle success
} on ApiException catch (e) {
  switch (e.statusCode) {
    case 401:
      // Handle authentication error
      break;
    case 422:
      // Handle validation error
      break;
    default:
      // Handle other errors
      break;
  }
} catch (e) {
  // Handle unexpected errors
}
```

## Validation Rules

### Required Fields
- `contact_id`: Supplier selection
- `location_id`: Business location
- `status`: Purchase status
- `transaction_date`: Purchase date
- `total_before_tax`: Subtotal amount
- `final_total`: Total amount
- `purchases[]`: At least one product line

### Business Rules
- Reference numbers must be unique per supplier
- Product quantities must be positive
- Unit prices must be non-negative
- Discount amounts cannot exceed subtotal
- Tax amounts are calculated automatically

## Best Practices

### 1. State Management
- Use Riverpod for complex state management
- Separate business logic from UI
- Handle loading states properly
- Implement proper error states

### 2. API Integration
- Implement retry mechanisms for network failures
- Cache frequently used data (suppliers, products)
- Handle authentication token refresh
- Validate API responses

### 3. UI/UX
- Provide clear form validation feedback
- Show loading indicators during API calls
- Implement proper error messaging
- Use consistent design patterns

### 4. Performance
- Implement pagination for large lists
- Cache API responses when appropriate
- Optimize rebuilds with proper key usage
- Use efficient list rendering

### 5. Security
- Never store sensitive data in logs
- Validate all user inputs
- Implement proper authentication flows
- Use HTTPS for all API calls

## Testing

### Unit Tests
```dart
void main() {
  test('Purchase creation validation', () {
    final purchase = Purchase(
      businessId: 1,
      contactId: 1,
      locationId: 1,
      status: 'ordered',
      transactionDate: DateTime.now(),
      totalBeforeTax: 100,
      finalTotal: 100,
      purchaseLines: [],
    );

    expect(purchase.isValid, false); // No products
  });
}
```

### Widget Tests
```dart
void main() {
  testWidgets('Purchase creation form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PurchaseCreationScreen(),
        ),
      ),
    );

    // Test form interactions
    await tester.enterText(find.byType(TextFormField).first, 'Test Ref');
    await tester.tap(find.text('Save'));
    await tester.pump();

    // Verify behavior
  });
}
```

## Troubleshooting

### Common Issues

1. **API Connection Failed**
   - Check network connectivity
   - Verify API base URL configuration
   - Check authentication token validity

2. **Form Validation Errors**
   - Ensure all required fields are filled
   - Check data types and formats
   - Verify business rules compliance

3. **State Management Issues**
   - Check Riverpod provider setup
   - Verify state updates are triggering rebuilds
   - Debug async operations

4. **Performance Issues**
   - Implement proper list virtualization
   - Cache expensive computations
   - Optimize image loading

## Migration Guide

### From Existing Implementation

1. **Replace HTTP calls** with Dio-based API service
2. **Update state management** to use Riverpod
3. **Migrate data models** to use Equatable
4. **Update UI components** to use new providers
5. **Add error handling** throughout the app

### Backward Compatibility

- Keep existing API endpoints functional
- Maintain data structure compatibility
- Provide migration path for existing data
- Support both old and new authentication methods

## Future Enhancements

### Planned Features
- Offline purchase creation with sync
- Bulk purchase operations
- Advanced reporting and analytics
- Integration with inventory management
- Multi-currency support
- Approval workflows

### API Improvements
- GraphQL API support
- Real-time updates with WebSocket
- Advanced filtering and search
- Bulk operations support
- API versioning

This integration provides a solid foundation for purchase management functionality with room for future enhancements and scalability.
