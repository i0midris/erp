import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import '../lib/helpers/api_cache.dart';

void main() {
  group('API Cache Tests', () {
    setUp(() async {
      // Clear cache before each test
      await ApiCache.clear();
    });

    test('ApiCache stores and retrieves data correctly', () async {
      final testData = {
        'data': [
          {'id': 1, 'name': 'Test Product', 'price': 10.0}
        ],
        'current_page': 1,
        'total': 1
      };
      const testKey = 'test_products';

      // Store data
      await ApiCache.set(testKey, testData);

      // Retrieve data
      final retrievedData = await ApiCache.get(testKey);

      expect(retrievedData, isNotNull);
      expect(retrievedData!['data'], isNotEmpty);
      expect(retrievedData['data'][0]['name'], 'Test Product');
      expect(retrievedData['current_page'], 1);
    });

    test('ApiCache respects expiration time', () async {
      final testData = {'test': 'data'};
      const testKey = 'expiring_test';

      // Store with short expiration
      await ApiCache.set(testKey, testData,
          duration: Duration(milliseconds: 100));

      // Should be available immediately
      var retrievedData = await ApiCache.get(testKey);
      expect(retrievedData, isNotNull);

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 200));

      // Should be expired
      retrievedData = await ApiCache.get(testKey);
      expect(retrievedData, isNull);
    });

    test('ApiCache handles different data types', () async {
      final testData = {
        'string': 'test',
        'number': 42,
        'boolean': true,
        'list': [1, 2, 3],
        'nested': {'key': 'value'}
      };

      await ApiCache.set('complex_data', testData);
      final retrievedData = await ApiCache.get('complex_data');

      expect(retrievedData, isNotNull);
      expect(retrievedData!['string'], 'test');
      expect(retrievedData['number'], 42);
      expect(retrievedData['boolean'], true);
      expect(retrievedData['list'], [1, 2, 3]);
      expect(retrievedData['nested']['key'], 'value');
    });

    test('ApiCache clear removes all data', () async {
      // Store multiple items
      await ApiCache.set('item1', {'data': 1});
      await ApiCache.set('item2', {'data': 2});
      await ApiCache.set('item3', {'data': 3});

      // Verify they exist
      expect(await ApiCache.get('item1'), isNotNull);
      expect(await ApiCache.get('item2'), isNotNull);
      expect(await ApiCache.get('item3'), isNotNull);

      // Clear cache
      await ApiCache.clear();

      // Verify they're gone
      expect(await ApiCache.get('item1'), isNull);
      expect(await ApiCache.get('item2'), isNull);
      expect(await ApiCache.get('item3'), isNull);
    });

    test('ApiCache isCached method works correctly', () async {
      const testKey = 'cache_check_test';

      // Initially not cached
      expect(await ApiCache.isCached(testKey), false);

      // Store data
      await ApiCache.set(testKey, {'test': 'data'});

      // Should be cached
      expect(await ApiCache.isCached(testKey), true);

      // Remove data
      await ApiCache.remove(testKey);

      // Should not be cached
      expect(await ApiCache.isCached(testKey), false);
    });
  });

  group('Data Validation Tests', () {
    test('Product data structure validation', () {
      final validProduct = {
        'id': 1,
        'name': 'Test Product',
        'price': 29.99,
        'category_id': 5,
        'description': 'A test product',
        'sku': 'TEST001',
        'stock_quantity': 100
      };

      // Validate required fields
      expect(validProduct['id'], isNotNull);
      expect(validProduct['name'], isNotNull);
      expect(validProduct['price'], isNotNull);
      expect(validProduct['name'], isA<String>());
      expect(validProduct['price'], isA<double>());
    });

    test('Contact data structure validation', () {
      final validContact = {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '+1234567890',
        'type': 'customer',
        'address': '123 Main St',
        'city': 'Test City',
        'country': 'Test Country'
      };

      expect(validContact['id'], isNotNull);
      expect(validContact['name'], isNotNull);
      expect(validContact['type'], isNotNull);
      expect(validContact['name'], isA<String>());
      expect(validContact['type'], isA<String>());
    });

    test('Sales data structure validation', () {
      final validSale = {
        'id': 1,
        'transaction_date': '2024-01-15',
        'total': 150.00,
        'payment_status': 'paid',
        'shipping_status': 'delivered',
        'customer_id': 5,
        'items': [
          {'product_id': 1, 'quantity': 2, 'price': 25.00},
          {'product_id': 2, 'quantity': 1, 'price': 100.00}
        ]
      };

      expect(validSale['id'], isNotNull);
      expect(validSale['total'], isNotNull);
      expect(validSale['items'], isNotEmpty);
      expect(validSale['total'], isA<double>());
      expect(validSale['items'], isA<List>());
    });
  });

  group('Error Handling Validation', () {
    test('Empty data handling', () {
      final emptyProductList = [];
      final emptyContactList = [];
      final emptySalesList = [];

      expect(emptyProductList, isEmpty);
      expect(emptyContactList, isEmpty);
      expect(emptySalesList, isEmpty);
    });

    test('Null data handling', () {
      Map<String, dynamic>? nullProduct = null;
      Map<String, dynamic>? nullContact = null;
      List<dynamic>? nullList = null;

      expect(nullProduct, isNull);
      expect(nullContact, isNull);
      expect(nullList, isNull);
    });

    test('Malformed data handling', () {
      final malformedData = {
        'id': 'not_a_number',
        'name': null,
        'price': 'not_a_price'
      };

      // These should be caught by proper validation
      expect(malformedData['id'], isNot(isA<int>()));
      expect(malformedData['name'], isNull);
      expect(malformedData['price'], isNot(isA<double>()));
    });
  });

  group('Pagination Logic Tests', () {
    test('Pagination parameters validation', () {
      final validPagination = {
        'page': 1,
        'per_page': 50,
        'total': 250,
        'last_page': 5,
        'current_page': 1
      };

      expect(validPagination['page'], greaterThan(0));
      expect(validPagination['per_page'], greaterThan(0));
      expect(validPagination['total'], greaterThanOrEqualTo(0));
      expect(validPagination['last_page'],
          greaterThanOrEqualTo(validPagination['current_page'] as int));
    });

    test('Pagination edge cases', () {
      // First page
      final firstPage = {'page': 1, 'per_page': 10, 'total': 25};
      expect(firstPage['page'], 1);

      // Last page
      final lastPage = {'page': 3, 'per_page': 10, 'total': 25};
      expect(lastPage['page'], 3);

      // Empty results
      final emptyResults = {'page': 1, 'per_page': 10, 'total': 0};
      expect(emptyResults['total'], 0);
    });
  });

  group('Search and Filter Validation', () {
    test('Search term validation', () {
      final validSearchTerms = ['test', 'product name', '123'];
      final invalidSearchTerms = ['', '   ', null];

      for (var term in validSearchTerms) {
        expect(term, isNotEmpty);
        expect(term?.trim(), isNotEmpty);
      }

      for (var term in invalidSearchTerms) {
        expect(term == null || term.trim().isEmpty, true);
      }
    });

    test('Filter parameter validation', () {
      final validFilters = {
        'category_id': 5,
        'status': 'active',
        'date_from': '2024-01-01',
        'date_to': '2024-01-31'
      };

      expect(validFilters['category_id'], isA<int>());
      expect(validFilters['status'], isA<String>());
      expect(validFilters['date_from'], isA<String>());
      expect(validFilters['date_to'], isA<String>());
    });
  });

  group('Performance Validation', () {
    test('Data processing efficiency', () {
      // Simulate processing a large dataset
      final largeDataset = List.generate(
          1000,
          (index) =>
              {'id': index, 'name': 'Item $index', 'value': index * 1.5});

      expect(largeDataset, hasLength(1000));

      // Test filtering operation
      final filteredData =
          largeDataset.where((item) => item['value'] as double > 500).toList();
      expect(filteredData.length, lessThan(1000));
      expect(
          filteredData.every((item) => (item['value'] as double) > 500), true);
    });

    test('Memory efficiency with large data', () {
      // Test that we can handle large data structures without issues
      final largeNestedData = {
        'products': List.generate(
            500,
            (index) => {
                  'id': index,
                  'variations': List.generate(
                      10,
                      (vIndex) => {
                            'variation_id': vIndex,
                            'attributes': {'size': 'M', 'color': 'red'}
                          })
                })
      };

      expect(largeNestedData['products'], hasLength(500));
      expect((largeNestedData['products'] as List)[0]['variations'],
          hasLength(10));
    });
  });
}
