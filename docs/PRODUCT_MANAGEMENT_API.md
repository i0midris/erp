# Product Management API Documentation

## Overview

The Product Management module provides comprehensive functionality for managing products, categories, inventory, and product analytics. This module offers both API endpoints and user interfaces for complete product lifecycle management.

## API Endpoints

### Products

#### GET /connector/api/products
Retrieve a list of products with advanced filtering and pagination.

**Parameters:**
- `category_id` (optional): Filter by category ID
- `search` (optional): Search term for product name/SKU
- `per_page` (optional): Items per page (default: 50)
- `page` (optional): Page number (default: 1)
- `order_by` (optional): Sort field (name, sku, created_at, updated_at)
- `order_direction` (optional): Sort direction (asc, desc)

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Wireless Bluetooth Headphones",
      "sku": "WBH-001",
      "category_id": 1,
      "category": {
        "name": "Electronics"
      },
      "selling_price": 99.99,
      "current_stock": 150,
      "min_stock": 10,
      "max_stock": 500,
      "status": "active",
      "created_at": "2024-01-15T10:00:00Z"
    }
  ],
  "current_page": 1,
  "last_page": 10,
  "per_page": 50,
  "total": 500
}
```

#### POST /connector/api/products
Create a new product.

**Request Body:**
```json
{
  "name": "Wireless Bluetooth Headphones",
  "sku": "WBH-001",
  "category_id": 1,
  "selling_price": 99.99,
  "current_stock": 150,
  "min_stock": 10,
  "max_stock": 500,
  "description": "High-quality wireless headphones",
  "status": "active",
  "variations": [
    {
      "name": "Black",
      "sku": "WBH-001-BLK",
      "selling_price": 99.99,
      "current_stock": 75
    },
    {
      "name": "White",
      "sku": "WBH-001-WHT",
      "selling_price": 99.99,
      "current_stock": 75
    }
  ]
}
```

#### GET /connector/api/products/{id}
Retrieve a specific product by ID.

#### PUT /connector/api/products/{id}
Update an existing product.

#### DELETE /connector/api/products/{id}
Delete a product (soft delete).

#### GET /connector/api/products/search
Advanced product search with multiple criteria.

**Parameters:**
- `query`: Search query
- `category_id` (optional): Filter by category
- `min_price` (optional): Minimum price filter
- `max_price` (optional): Maximum price filter
- `in_stock` (optional): Only show products in stock (true/false)

### Product Categories

#### GET /connector/api/product-categories
Retrieve all product categories.

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Electronics",
      "parent_id": null,
      "products_count": 150,
      "sub_categories": [
        {
          "id": 2,
          "name": "Audio Devices",
          "parent_id": 1,
          "products_count": 45
        }
      ]
    }
  ]
}
```

#### POST /connector/api/product-categories
Create a new product category.

#### PUT /connector/api/product-categories/{id}
Update a product category.

#### DELETE /connector/api/product-categories/{id}
Delete a product category.

### Product Variations

#### GET /connector/api/products/{productId}/variations
Retrieve variations for a specific product.

#### POST /connector/api/products/{productId}/variations
Create a new product variation.

#### PUT /connector/api/products/{productId}/variations/{variationId}
Update a product variation.

#### DELETE /connector/api/products/{productId}/variations/{variationId}
Delete a product variation.

### Inventory Management

#### GET /connector/api/inventory/stock-report
Retrieve comprehensive stock report.

**Response:**
```json
{
  "data": [
    {
      "product_id": 1,
      "product_name": "Wireless Headphones",
      "sku": "WBH-001",
      "current_stock": 150,
      "min_stock": 10,
      "max_stock": 500,
      "stock_status": "in_stock",
      "last_updated": "2024-01-15T10:00:00Z"
    }
  ],
  "summary": {
    "total_products": 500,
    "in_stock": 450,
    "low_stock": 25,
    "out_of_stock": 25,
    "total_value": 75000.00
  }
}
```

#### GET /connector/api/inventory/low-stock
Retrieve products with low stock levels.

**Parameters:**
- `threshold` (optional): Stock threshold (default: 10)

#### GET /connector/api/inventory/out-of-stock
Retrieve products that are out of stock.

#### PUT /connector/api/inventory/{productId}/adjust-stock
Adjust stock levels for a product.

**Request Body:**
```json
{
  "adjustment_type": "add", // "add" or "subtract"
  "quantity": 50,
  "reason": "Stock replenishment",
  "reference": "PO-001"
}
```

### Product Analytics

#### GET /connector/api/products/{id}/analytics
Retrieve analytics for a specific product.

**Response:**
```json
{
  "product_id": 1,
  "product_name": "Wireless Headphones",
  "analytics": {
    "total_sold": 1250,
    "revenue": 123750.00,
    "average_price": 99.00,
    "best_selling_month": "December",
    "customer_rating": 4.5,
    "return_rate": 2.1,
    "stock_turnover": 8.5
  }
}
```

#### GET /connector/api/analytics/product-performance
Retrieve overall product performance analytics.

**Parameters:**
- `start_date` (optional): Start date for analytics
- `end_date` (optional): End date for analytics
- `category_id` (optional): Filter by category

### Bulk Operations

#### POST /connector/api/products/bulk-import
Import multiple products from CSV/Excel.

**Request Body:**
```json
{
  "file": "base64-encoded-file-content",
  "file_type": "csv", // "csv" or "excel"
  "update_existing": true,
  "skip_errors": false
}
```

#### GET /connector/api/products/bulk-export
Export products to CSV/Excel.

**Parameters:**
- `format`: Export format (csv, excel)
- `category_id` (optional): Filter by category
- `status` (optional): Filter by status

#### POST /connector/api/products/bulk-update
Update multiple products at once.

**Request Body:**
```json
{
  "product_ids": [1, 2, 3],
  "updates": {
    "status": "active",
    "category_id": 2
  }
}
```

## Error Handling

All API endpoints return standardized error responses:

**Error Response Format:**
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "name": ["Product name is required"],
    "sku": ["SKU must be unique"],
    "selling_price": ["Price must be greater than 0"]
  },
  "error_code": "VALIDATION_ERROR"
}
```

**Common Error Codes:**
- `VALIDATION_ERROR`: Input validation failed
- `PRODUCT_NOT_FOUND`: Product does not exist
- `DUPLICATE_SKU`: SKU already exists
- `INSUFFICIENT_STOCK`: Not enough stock for operation
- `CATEGORY_NOT_FOUND`: Category does not exist

## Authentication & Authorization

All endpoints require Bearer token authentication:

```
Authorization: Bearer your-jwt-token
```

**Required Permissions:**
- `products.read`: View products
- `products.create`: Create products
- `products.update`: Update products
- `products.delete`: Delete products
- `inventory.manage`: Manage inventory
- `analytics.view`: View analytics

## Rate Limiting

API endpoints have different rate limits based on operation type:

- Read operations: 200 requests per 15 minutes
- Write operations: 100 requests per 15 minutes
- Bulk operations: 20 requests per 15 minutes
- Analytics: 50 requests per 15 minutes

## Data Validation Rules

### Product Validation:
- `name`: Required, 2-255 characters
- `sku`: Required, unique, 1-100 characters
- `category_id`: Required, must exist
- `selling_price`: Required, must be >= 0
- `current_stock`: Must be >= 0
- `min_stock`: Must be >= 0
- `max_stock`: Must be > min_stock if provided

### Category Validation:
- `name`: Required, 2-100 characters, unique
- `parent_id`: Optional, must exist if provided

## Business Logic

### Stock Management:
- Automatic low stock alerts when current_stock <= min_stock
- Stock adjustments are logged with audit trail
- Stock levels affect product availability in sales

### Pricing Strategy:
- Support for multiple price tiers
- Automatic tax calculations
- Price history tracking
- Promotional pricing support

### Product Status:
- `active`: Product is available for sale
- `inactive`: Product is not available for sale
- `discontinued`: Product is no longer sold

## Integration Points

### Sales Module:
- Real-time stock updates during sales
- Product availability checks
- Price synchronization

### Purchase Module:
- Automatic stock updates on purchase receipt
- Supplier product information
- Cost tracking and analysis

### Inventory Module:
- Stock level monitoring
- Reorder point calculations
- Stock movement tracking

## Webhooks

### Available Events:
- `product.created`: New product created
- `product.updated`: Product updated
- `product.deleted`: Product deleted
- `stock.low`: Product reached low stock level
- `stock.out`: Product went out of stock
- `category.created`: New category created

### Webhook Payload:
```json
{
  "event": "product.created",
  "data": {
    "product_id": 123,
    "name": "Wireless Headphones",
    "sku": "WBH-001",
    "current_stock": 150,
    "created_at": "2024-01-15T10:00:00Z"
  }
}
```

## Usage Examples

### Creating a Product (JavaScript)
```javascript
const productData = {
  name: "Wireless Bluetooth Headphones",
  sku: "WBH-001",
  category_id: 1,
  selling_price: 99.99,
  current_stock: 150,
  min_stock: 10,
  description: "High-quality wireless headphones with noise cancellation"
};

fetch('/connector/api/products', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer your-token'
  },
  body: JSON.stringify(productData)
})
.then(response => response.json())
.then(data => console.log('Product created:', data));
```

### Bulk Stock Update (Python)
```python
import requests

stock_updates = [
    {"product_id": 1, "adjustment_type": "add", "quantity": 50},
    {"product_id": 2, "adjustment_type": "subtract", "quantity": 10}
]

headers = {'Authorization': 'Bearer your-token'}

for update in stock_updates:
    response = requests.put(
        f'/connector/api/inventory/{update["product_id"]}/adjust-stock',
        headers=headers,
        json=update
    )
    print(f'Stock update result: {response.json()}')
```

### Advanced Search (cURL)
```bash
curl -X GET "/connector/api/products/search?query=headphones&category_id=1&min_price=50&max_price=200&in_stock=true" \
  -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json"
```

## Performance Optimization

### Caching Strategy:
- Product listings cached for 5 minutes
- Category data cached for 15 minutes
- Stock levels cached for 1 minute
- Analytics data cached for 30 minutes

### Database Optimization:
- Indexed on frequently queried fields (SKU, category_id, status)
- Partitioned tables for large datasets
- Query result caching
- Connection pooling

### API Optimization:
- Pagination for large result sets
- Selective field retrieval
- Batch operations for bulk updates
- Compressed responses for large payloads

## Monitoring & Analytics

### Key Metrics:
- Product creation/update rates
- Stock level trends
- Search query performance
- API response times
- Error rates by endpoint

### Dashboard Widgets:
- Top-selling products
- Low stock alerts
- Category performance
- Stock turnover rates
- Revenue by product

## Security Considerations

### Data Protection:
- Product images stored securely
- Sensitive data encrypted at rest
- Audit logging for all changes
- Role-based access control

### Input Security:
- SQL injection prevention
- XSS protection
- File upload validation
- Rate limiting on search endpoints

## Troubleshooting

### Common Issues:

1. **"SKU already exists" error**:
   - Check existing products for duplicate SKU
   - Use auto-generated SKUs if needed

2. **"Category not found" error**:
   - Verify category exists and is active
   - Check category hierarchy

3. **Slow search performance**:
   - Use more specific search terms
   - Consider full-text search indexes

4. **Stock discrepancy**:
   - Check audit logs for stock movements
   - Verify concurrent transaction handling

### Debug Mode:
Enable detailed logging:
```bash
export DEBUG_PRODUCTS=true
export DEBUG_INVENTORY=true
```

## Migration Guide

### From Legacy System:
1. Export existing product data
2. Map categories to new structure
3. Validate SKU uniqueness
4. Import products in batches
5. Verify stock levels
6. Update integrations

### Data Mapping:
```json
{
  "legacy_product": {
    "item_code": "sku",
    "item_name": "name",
    "item_group": "category",
    "standard_rate": "selling_price",
    "actual_qty": "current_stock"
  }
}
```

## Future Enhancements

### Planned Features:
- Advanced product bundling
- Multi-location inventory
- Product variants with attributes
- Advanced pricing rules
- Product lifecycle management
- Integration with external marketplaces

This documentation provides comprehensive guidance for implementing and using the Product Management API effectively.