# Purchase Management API Documentation

## Overview

The Purchase Management module provides comprehensive functionality for managing purchase orders, suppliers, and procurement workflows. This module integrates seamlessly with the existing ERP system and provides both API endpoints and user interfaces for complete purchase lifecycle management.

## API Endpoints

### Purchase Orders

#### GET /connector/api/purchases
Retrieve a list of purchase orders with filtering and pagination.

**Parameters:**
- `supplier_id` (optional): Filter by supplier ID
- `status` (optional): Filter by status (ordered, received, pending, partial, cancelled)
- `start_date` (optional): Filter by start date (YYYY-MM-DD)
- `end_date` (optional): Filter by end date (YYYY-MM-DD)
- `per_page` (optional): Items per page (default: 50)
- `page` (optional): Page number (default: 1)

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "ref_no": "PO-001",
      "contact_id": 1,
      "contact": {
        "name": "ABC Suppliers Ltd",
        "supplier_business_name": "ABC Corp"
      },
      "transaction_date": "2024-01-15",
      "status": "ordered",
      "final_total": 1500.00,
      "created_at": "2024-01-15T10:00:00Z"
    }
  ],
  "current_page": 1,
  "last_page": 5,
  "per_page": 50,
  "total": 250
}
```

#### POST /connector/api/purchases
Create a new purchase order.

**Request Body:**
```json
{
  "contact_id": 1,
  "transaction_date": "2024-01-15 10:00:00",
  "status": "ordered",
  "location_id": 1,
  "total_before_tax": 1250.00,
  "final_total": 1500.00,
  "purchases": [
    {
      "product_id": 1,
      "variation_id": 1,
      "quantity": 10,
      "purchase_price": 125.00,
      "purchase_price_inc_tax": 125.00
    }
  ]
}
```

#### GET /connector/api/purchases/{id}
Retrieve a specific purchase order by ID.

#### PUT /connector/api/purchases/{id}
Update an existing purchase order.

#### DELETE /connector/api/purchases/{id}
Delete a purchase order.

#### PUT /connector/api/purchases/{id}/status
Update the status of a purchase order.

**Request Body:**
```json
{
  "status": "received"
}
```

### Suppliers

#### GET /connector/api/purchases/suppliers
Retrieve a list of suppliers for purchase orders.

**Parameters:**
- `term` (optional): Search term for supplier name

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "text": "ABC Suppliers Ltd",
      "supplier_business_name": "ABC Corp",
      "mobile": "+1234567890",
      "balance": 2500.00
    }
  ]
}
```

### Products for Purchase

#### GET /connector/api/purchases/products
Retrieve products available for purchase.

**Parameters:**
- `term` (optional): Search term for product name

**Response:**
```json
{
  "data": [
    {
      "product_id": 1,
      "product_name": "Wireless Mouse",
      "variation_id": 1,
      "variation_name": "Black",
      "purchase_price": 25.00,
      "selling_price": 35.00,
      "current_stock": 50
    }
  ]
}
```

### Purchase Summary

#### GET /connector/api/purchases/summary
Retrieve purchase summary and analytics.

**Parameters:**
- `start_date` (optional): Start date for summary (YYYY-MM-DD)
- `end_date` (optional): End date for summary (YYYY-MM-DD)

**Response:**
```json
{
  "total_purchases": 150,
  "total_amount": 250000.00,
  "pending_orders": 12,
  "received_today": 5,
  "top_suppliers": [
    {
      "supplier_id": 1,
      "supplier_name": "ABC Corp",
      "total_purchases": 45000.00,
      "order_count": 25
    }
  ]
}
```

## Error Handling

All API endpoints return appropriate HTTP status codes and error messages:

- `200`: Success
- `201`: Created
- `400`: Bad Request (validation errors)
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `422`: Unprocessable Entity (business logic errors)
- `500`: Internal Server Error

**Error Response Format:**
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "contact_id": ["Supplier is required"],
    "purchases": ["At least one product is required"]
  }
}
```

## Authentication

All endpoints require Bearer token authentication:

```
Authorization: Bearer your-jwt-token
```

## Rate Limiting

API endpoints are rate-limited to prevent abuse:
- 100 requests per 15 minutes for read operations
- 50 requests per 15 minutes for write operations

## Data Validation

### Purchase Order Validation Rules:
- `contact_id`: Required, must be a valid supplier
- `transaction_date`: Required, must be a valid date
- `status`: Must be one of: ordered, received, pending, partial, cancelled
- `location_id`: Required, must be a valid business location
- `purchases`: Must contain at least one item
- `purchases[].product_id`: Required, must be a valid product
- `purchases[].quantity`: Required, must be greater than 0
- `purchases[].purchase_price`: Required, must be greater than 0

## Business Logic

### Purchase Order Status Flow:
1. **Ordered**: Initial status when purchase order is created
2. **Pending**: Awaiting supplier confirmation
3. **Partial**: Partially received
4. **Received**: Fully received and processed
5. **Cancelled**: Order cancelled

### Automatic Calculations:
- Total amount is automatically calculated from line items
- Tax calculations are applied based on product tax settings
- Supplier balance is updated when payments are made

## Integration Points

### Inventory Management:
- Stock levels are automatically updated when purchases are received
- Low stock alerts are triggered based on received quantities

### Financial Management:
- Purchase invoices are automatically generated
- Payment tracking is integrated with the accounting module

### Supplier Management:
- Supplier performance metrics are updated based on purchase history
- Payment terms and credit limits are enforced

## Webhooks

The system supports webhooks for real-time notifications:

### Available Events:
- `purchase.created`: Triggered when a new purchase order is created
- `purchase.updated`: Triggered when a purchase order is updated
- `purchase.received`: Triggered when a purchase order is marked as received
- `purchase.cancelled`: Triggered when a purchase order is cancelled

### Webhook Payload:
```json
{
  "event": "purchase.created",
  "data": {
    "purchase_id": 123,
    "supplier_name": "ABC Corp",
    "total_amount": 1500.00,
    "status": "ordered",
    "created_at": "2024-01-15T10:00:00Z"
  }
}
```

## Usage Examples

### Creating a Purchase Order (JavaScript)
```javascript
const purchaseData = {
  contact_id: 1,
  transaction_date: "2024-01-15 10:00:00",
  status: "ordered",
  location_id: 1,
  purchases: [
    {
      product_id: 1,
      variation_id: 1,
      quantity: 10,
      purchase_price: 125.00
    }
  ]
};

fetch('/connector/api/purchases', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer your-token'
  },
  body: JSON.stringify(purchaseData)
})
.then(response => response.json())
.then(data => console.log(data));
```

### Retrieving Purchase Orders with Filtering (Python)
```python
import requests

headers = {
    'Authorization': 'Bearer your-token'
}

params = {
    'status': 'ordered',
    'supplier_id': 1,
    'per_page': 20
}

response = requests.get('/connector/api/purchases', headers=headers, params=params)
purchases = response.json()
```

## Performance Considerations

- Use pagination for large datasets
- Implement caching for frequently accessed data
- Use appropriate indexes on database tables
- Monitor query performance and optimize slow queries

## Security Best Practices

- All data transmission uses HTTPS
- Input validation on all endpoints
- SQL injection prevention through parameterized queries
- XSS protection through input sanitization
- Audit logging for all purchase operations

## Monitoring and Analytics

The system provides comprehensive monitoring:

- Purchase order creation/update metrics
- Supplier performance analytics
- Inventory turnover calculations
- Cost analysis and reporting
- Real-time dashboard updates

## Troubleshooting

### Common Issues:

1. **"Supplier not found" error**: Ensure the supplier exists and is active
2. **"Product not available" error**: Check product availability and status
3. **"Location not found" error**: Verify business location configuration
4. **"Insufficient permissions" error**: Check user role and permissions

### Debug Mode:
Enable debug logging by setting the environment variable:
```
DEBUG_PURCHASES=true
```

This will provide detailed logs for troubleshooting purchase operations.