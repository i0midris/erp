import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchaseDatabase.dart';
import '../models/system.dart';
import '../helpers/otherHelpers.dart';
import 'purchase_api_service.dart';

/// Service for caching suppliers, products, and locations for offline purchase functionality
class PurchaseCacheService {
  final PurchaseApiService _apiService;
  final PurchaseDatabase _db = PurchaseDatabase();

  PurchaseCacheService(this._apiService);

  /// Ensure cache tables exist
  Future<void> _ensureCacheTablesExist() async {
    try {
      final db = await _db.dbProvider.database;

      // Create tables if they don't exist
      await db.execute(_db.dbProvider.createCachedSuppliersTable);
      await db.execute(_db.dbProvider.createCachedProductsTable);
      await db.execute(_db.dbProvider.createCachedLocationsTable);

      print('✅ Cache tables ensured to exist');
    } catch (e) {
      print('❌ Failed to ensure cache tables exist: $e');
      rethrow;
    }
  }

  /// Cache suppliers for offline use
  Future<void> cacheSuppliers([List<dynamic>? suppliers]) async {
    try {
      List<dynamic> suppliersToCache = suppliers ?? [];

      if (suppliersToCache.isEmpty && await Helper().checkConnectivity()) {
        // Check if user is authenticated before making API call
        final system = System();
        final isAuthenticated = await system.isAuthenticated();

        if (!isAuthenticated) {
          print('⚠️ User not authenticated, skipping suppliers API call');
          return;
        }

        suppliersToCache = await _apiService.getSuppliers();
      }

      if (suppliersToCache.isNotEmpty) {
        await _db.cacheSuppliers(suppliersToCache);
        await System()
            .insert('suppliers_last_sync', DateTime.now().toIso8601String());
        print(
            '✅ Suppliers cached successfully: ${suppliersToCache.length} suppliers');
      }
    } catch (e) {
      print('❌ Failed to cache suppliers: $e');

      // Handle authentication errors
      if (e.toString().contains('Authentication failed') ||
          e.toString().contains('401')) {
        print('🔐 Authentication error - user needs to login again');
        // Don't try to recreate tables for auth errors
        return;
      }

      // Try to recreate table if it doesn't exist
      if (e.toString().contains('no such table')) {
        try {
          await _ensureCacheTablesExist();
          // Retry caching after table creation
          if (suppliers != null && suppliers.isNotEmpty) {
            await _db.cacheSuppliers(suppliers);
            print('✅ Suppliers cached after table recreation');
          }
        } catch (retryError) {
          print('❌ Failed to recreate cache table: $retryError');
        }
      }
    }
  }

  /// Cache products for offline use
  Future<void> cacheProducts([List<dynamic>? products]) async {
    try {
      List<dynamic> productsToCache = products ?? [];

      if (productsToCache.isEmpty && await Helper().checkConnectivity()) {
        // Check if user is authenticated before making API call
        final system = System();
        final isAuthenticated = await system.isAuthenticated();

        if (!isAuthenticated) {
          print('⚠️ User not authenticated, skipping products API call');
          return;
        }

        productsToCache = await _apiService.getProducts();
      }

      if (productsToCache.isNotEmpty) {
        await _db.cacheProducts(productsToCache);
        await System()
            .insert('products_last_sync', DateTime.now().toIso8601String());
        print(
            '✅ Products cached successfully: ${productsToCache.length} products');
      }
    } catch (e) {
      print('❌ Failed to cache products: $e');

      // Handle authentication errors
      if (e.toString().contains('Authentication failed') ||
          e.toString().contains('401')) {
        print('🔐 Authentication error - user needs to login again');
        return;
      }

      // Try to recreate table if it doesn't exist
      if (e.toString().contains('no such table')) {
        try {
          await _ensureCacheTablesExist();
          // Retry caching after table creation
          if (products != null && products.isNotEmpty) {
            await _db.cacheProducts(products);
            print('✅ Products cached after table recreation');
          }
        } catch (retryError) {
          print('❌ Failed to recreate cache table: $retryError');
        }
      }
    }
  }

  /// Cache locations for offline use
  Future<void> cacheLocations([List<dynamic>? locations]) async {
    try {
      List<dynamic> locationsToCache = locations ?? [];

      if (locationsToCache.isEmpty && await Helper().checkConnectivity()) {
        // Check if user is authenticated before making API call
        final system = System();
        final isAuthenticated = await system.isAuthenticated();

        if (!isAuthenticated) {
          print('⚠️ User not authenticated, skipping locations API call');
          return;
        }

        locationsToCache = await _apiService.getLocations();
      }

      if (locationsToCache.isNotEmpty) {
        await _db.cacheLocations(locationsToCache);
        await System()
            .insert('locations_last_sync', DateTime.now().toIso8601String());
        print(
            '✅ Locations cached successfully: ${locationsToCache.length} locations');
      }
    } catch (e) {
      print('❌ Failed to cache locations: $e');

      // Handle authentication errors
      if (e.toString().contains('Authentication failed') ||
          e.toString().contains('401')) {
        print('🔐 Authentication error - user needs to login again');
        return;
      }

      // Try to recreate table if it doesn't exist
      if (e.toString().contains('no such table')) {
        try {
          await _ensureCacheTablesExist();
          // Retry caching after table creation
          if (locations != null && locations.isNotEmpty) {
            await _db.cacheLocations(locations);
            print('✅ Locations cached after table recreation');
          }
        } catch (retryError) {
          print('❌ Failed to recreate cache table: $retryError');
        }
      }
    }
  }

  /// Cache all purchase-related data
  Future<void> cacheAllPurchaseData() async {
    print('🔄 Starting purchase data caching...');

    await Future.wait([
      cacheSuppliers(),
      cacheProducts(),
      cacheLocations(),
    ]);

    // Update cache timestamp
    await System()
        .insert('cache_last_refresh', DateTime.now().toIso8601String());

    print('✅ All purchase data cached successfully');
  }

  /// Get cached suppliers
  Future<List<Map<String, dynamic>>> getCachedSuppliers(
      {String? searchTerm}) async {
    return await _db.getCachedSuppliers(searchTerm: searchTerm);
  }

  /// Get cached products
  Future<List<Map<String, dynamic>>> getCachedProducts(
      {String? searchTerm}) async {
    return await _db.getCachedProducts(searchTerm: searchTerm);
  }

  /// Get cached locations
  Future<List<Map<String, dynamic>>> getCachedLocations() async {
    return await _db.getCachedLocations();
  }

  /// Check if cache is stale (older than specified hours)
  Future<bool> isCacheStale(String cacheType, {int maxAgeHours = 24}) async {
    try {
      final lastSyncStr = await System().get(cacheType);
      if (lastSyncStr == null) return true;

      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();
      final difference = now.difference(lastSync);

      return difference.inHours >= maxAgeHours;
    } catch (e) {
      return true; // If error, consider cache stale
    }
  }

  /// Refresh cache if stale
  Future<void> refreshCacheIfNeeded() async {
    final tasks = <Future>[];

    if (await isCacheStale('suppliers_last_sync')) {
      tasks.add(cacheSuppliers());
    }

    if (await isCacheStale('products_last_sync')) {
      tasks.add(cacheProducts());
    }

    if (await isCacheStale('locations_last_sync')) {
      tasks.add(cacheLocations());
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
      print('✅ Cache refreshed successfully');
    } else {
      print('✅ Cache is up to date');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _db.clearPurchaseCache();
    await System().delete('suppliers_last_sync');
    await System().delete('products_last_sync');
    await System().delete('locations_last_sync');
    print('🗑️ Purchase cache cleared');
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final suppliersCount = await _db.getCachedSuppliersCount();
    final productsCount = await _db.getCachedProductsCount();
    final locationsCount = await _db.getCachedLocationsCount();

    final suppliersLastSync = await System().get('suppliers_last_sync');
    final productsLastSync = await System().get('products_last_sync');
    final locationsLastSync = await System().get('locations_last_sync');

    return {
      'suppliers': {
        'count': suppliersCount,
        'last_sync': suppliersLastSync,
      },
      'products': {
        'count': productsCount,
        'last_sync': productsLastSync,
      },
      'locations': {
        'count': locationsCount,
        'last_sync': locationsLastSync,
      },
    };
  }
}

/// Provider for PurchaseCacheService
final purchaseCacheServiceProvider = Provider<PurchaseCacheService>((ref) {
  final apiService = ref.watch(purchaseApiServiceProvider);
  return PurchaseCacheService(apiService);
});
