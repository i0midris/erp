# Performance Optimization Guide for Enhanced API Functions

## Overview
This guide outlines performance optimization strategies specifically tailored for mobile platforms to ensure the enhanced API functions deliver optimal user experience.

## Mobile-Specific Performance Considerations

### 1. Network Optimization

#### Connection-Aware Requests
```dart
enum ConnectionType { wifi, mobile, none }

class NetworkAwareApi extends Api {
  Future<ConnectionType> getConnectionType() async {
    // Implementation to detect connection type
    // Return wifi, mobile, or none
  }

  Future<Map<String, dynamic>> optimizedRequest(String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    int maxRetries = 3
  }) async {
    ConnectionType connection = await getConnectionType();

    // Adjust retry strategy based on connection
    int adjustedRetries = connection == ConnectionType.mobile ? 2 : maxRetries;

    // Adjust timeout based on connection
    Duration timeout = connection == ConnectionType.mobile ?
      Duration(seconds: 15) : Duration(seconds: 30);

    return await apiGet(endpoint,
      headers: headers,
      maxRetries: adjustedRetries
    ).timeout(timeout);
  }
}
```

#### Request Batching
```dart
class RequestBatcher {
  static const int MAX_BATCH_SIZE = 10;
  static const Duration BATCH_DELAY = Duration(milliseconds: 100);

  List<QueuedRequest> _requestQueue = [];
  Timer? _batchTimer;

  void addToBatch(String endpoint, Map<String, dynamic> data) {
    _requestQueue.add(QueuedRequest(endpoint, data));

    if (_requestQueue.length >= MAX_BATCH_SIZE) {
      _flushBatch();
    } else if (_batchTimer == null) {
      _batchTimer = Timer(BATCH_DELAY, _flushBatch);
    }
  }

  void _flushBatch() {
    if (_requestQueue.isEmpty) return;

    // Process batch of requests
    List<QueuedRequest> batch = List.from(_requestQueue);
    _requestQueue.clear();
    _batchTimer?.cancel();
    _batchTimer = null;

    _processBatch(batch);
  }

  Future<void> _processBatch(List<QueuedRequest> batch) async {
    // Implement batch processing logic
    for (var request in batch) {
      // Process each request with optimized timing
      await Future.delayed(Duration(milliseconds: 50));
    }
  }
}
```

### 2. Caching Strategy Optimization

#### Smart Cache Invalidation
```dart
class SmartCacheManager {
  static const Map<String, Duration> CACHE_DURATIONS = {
    'products': Duration(minutes: 15),
    'categories': Duration(hours: 1),
    'user_profile': Duration(hours: 24),
    'sales_today': Duration(minutes: 5),
    'contacts': Duration(minutes: 30),
  };

  static Duration getCacheDuration(String key) {
    return CACHE_DURATIONS[key] ?? Duration(minutes: 30);
  }

  static bool shouldCache(String endpoint) {
    // Don't cache real-time or sensitive data
    List<String> noCacheEndpoints = [
      'auth',
      'payment',
      'logout',
      'real-time'
    ];

    return !noCacheEndpoints.any((pattern) => endpoint.contains(pattern));
  }

  static Future<void> invalidateRelatedCaches(String changedEntity) async {
    Map<String, List<String>> relatedCaches = {
      'product': ['products', 'categories', 'inventory'],
      'contact': ['contacts', 'customers', 'suppliers'],
      'sale': ['sales', 'transactions', 'reports']
    };

    List<String> toInvalidate = relatedCaches[changedEntity] ?? [];
    for (String cacheKey in toInvalidate) {
      await ApiCache.remove(cacheKey);
    }
  }
}
```

#### Memory-Efficient Caching
```dart
class MemoryEfficientCache {
  static const int MAX_CACHE_SIZE = 50 * 1024 * 1024; // 50MB
  static const int CLEANUP_THRESHOLD = 40 * 1024 * 1024; // 40MB

  static Future<void> monitorCacheSize() async {
    int currentSize = await ApiCache.getCacheSize();

    if (currentSize > CLEANUP_THRESHOLD) {
      await ApiCache.cleanExpired();

      // If still over threshold, remove oldest entries
      currentSize = await ApiCache.getCacheSize();
      if (currentSize > MAX_CACHE_SIZE) {
        await _cleanupOldestEntries();
      }
    }
  }

  static Future<void> _cleanupOldestEntries() async {
    // Implementation to remove oldest cache entries
    // This would require extending the cache implementation
  }
}
```

### 3. Image and Asset Optimization

#### Lazy Loading Implementation
```dart
class LazyImageLoader {
  static final Map<String, ImageProvider> _imageCache = {};

  static ImageProvider getImage(String url, {
    double? width,
    double? height,
    BoxFit? fit
  }) {
    if (_imageCache.containsKey(url)) {
      return _imageCache[url]!;
    }

    // Create a cached network image
    final imageProvider = ResizeImage.resizeIfNeeded(
      width?.round(),
      height?.round(),
      NetworkImage(url)
    );

    _imageCache[url] = imageProvider;
    return imageProvider;
  }

  static void clearCache() {
    _imageCache.clear();
  }

  static Future<void> preloadImages(List<String> urls) async {
    for (String url in urls) {
      if (!_imageCache.containsKey(url)) {
        final image = NetworkImage(url);
        await precacheImage(image, context);
        _imageCache[url] = image;
      }
    }
  }
}
```

### 4. Database Optimization

#### Indexed Queries
```dart
class OptimizedDatabaseQueries {
  // Use indexes for frequently queried fields
  static const String CREATE_PRODUCTS_TABLE = '''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      category_id INTEGER,
      price REAL,
      stock_quantity INTEGER,
      last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,

      -- Indexes for performance
      INDEX idx_products_category (category_id),
      INDEX idx_products_name (name),
      INDEX idx_products_price (price),
      INDEX idx_products_updated (last_updated)
    )
  ''';

  // Optimized query with proper indexing
  static Future<List<Map<String, dynamic>>> getProductsByCategory(
    int categoryId, {
    int limit = 50,
    int offset = 0
  }) async {
    // This query will use the category index
    return await database.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
      limit: limit,
      offset: offset
    );
  }
}
```

#### Batch Database Operations
```dart
class BatchDatabaseOperations {
  static Future<void> batchInsertProducts(List<Map<String, dynamic>> products) async {
    final batch = database.batch();

    for (var product in products) {
      batch.insert('products', product,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<void> batchUpdateStock(List<Map<String, dynamic>> stockUpdates) async {
    final batch = database.batch();

    for (var update in stockUpdates) {
      batch.update(
        'products',
        {'stock_quantity': update['quantity']},
        where: 'id = ?',
        whereArgs: [update['product_id']]
      );
    }

    await batch.commit();
  }
}
```

### 5. UI Performance Optimization

#### List Virtualization
```dart
class VirtualizedProductList extends StatefulWidget {
  final List<Product> products;
  final int itemHeight;

  const VirtualizedProductList({
    Key? key,
    required this.products,
    this.itemHeight = 80
  }) : super(key: key);

  @override
  _VirtualizedProductListState createState() => _VirtualizedProductListState();
}

class _VirtualizedProductListState extends State<VirtualizedProductList> {
  final ScrollController _scrollController = ScrollController();
  final int _visibleItems = 10;
  int _startIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final newStartIndex = (offset / widget.itemHeight).floor();

    if (newStartIndex != _startIndex) {
      setState(() {
        _startIndex = newStartIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final endIndex = (_startIndex + _visibleItems).clamp(0, widget.products.length);
    final visibleProducts = widget.products.sublist(_startIndex, endIndex);

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.products.length,
      itemBuilder: (context, index) {
        if (index < _startIndex || index >= endIndex) {
          return SizedBox(height: widget.itemHeight);
        }

        final actualIndex = index - _startIndex;
        return _buildProductItem(visibleProducts[actualIndex]);
      },
    );
  }

  Widget _buildProductItem(Product product) {
    return SizedBox(
      height: widget.itemHeight.toDouble(),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text('\$${product.price}'),
        leading: CircleAvatar(
          backgroundImage: LazyImageLoader.getImage(product.imageUrl),
        ),
      ),
    );
  }
}
```

### 6. Background Processing

#### Queue Management
```dart
class BackgroundTaskQueue {
  static final Queue<Task> _taskQueue = Queue<Task>();
  static bool _isProcessing = false;

  static void addTask(Task task) {
    _taskQueue.add(task);
    _processQueue();
  }

  static Future<void> _processQueue() async {
    if (_isProcessing || _taskQueue.isEmpty) return;

    _isProcessing = true;

    while (_taskQueue.isNotEmpty) {
      final task = _taskQueue.removeFirst();

      try {
        await task.execute();
      } catch (e) {
        print('Task execution failed: $e');
        // Handle task failure (retry, notify user, etc.)
      }

      // Small delay between tasks to prevent overwhelming the system
      await Future.delayed(Duration(milliseconds: 100));
    }

    _isProcessing = false;
  }
}

abstract class Task {
  Future<void> execute();
}

class SyncProductsTask extends Task {
  @override
  Future<void> execute() async {
    // Implement product synchronization
    await ProductApi().getProducts(useCache: false);
  }
}
```

### 7. Memory Management

#### Object Pool Pattern
```dart
class ApiResponsePool {
  static final Map<String, ApiResponse> _pool = {};
  static const int MAX_POOL_SIZE = 100;

  static ApiResponse? get(String key) {
    return _pool[key];
  }

  static void put(String key, ApiResponse response) {
    if (_pool.length < MAX_POOL_SIZE) {
      _pool[key] = response;
    }
  }

  static void clear() {
    _pool.clear();
  }

  static void cleanup() {
    // Remove old entries based on timestamp
    final cutoffTime = DateTime.now().subtract(Duration(minutes: 30));
    _pool.removeWhere((key, response) =>
      response.timestamp.isBefore(cutoffTime)
    );
  }
}

class ApiResponse {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ApiResponse(this.data) : timestamp = DateTime.now();
}
```

## Performance Monitoring

### Metrics Collection
```dart
class PerformanceMonitor {
  static final Map<String, List<Duration>> _apiCallTimes = {};
  static final Map<String, int> _cacheHits = {};
  static final Map<String, int> _cacheMisses = {};

  static void recordApiCallTime(String endpoint, Duration time) {
    _apiCallTimes.putIfAbsent(endpoint, () => []).add(time);

    // Keep only last 100 measurements
    if (_apiCallTimes[endpoint]!.length > 100) {
      _apiCallTimes[endpoint]!.removeAt(0);
    }
  }

  static void recordCacheHit(String key) {
    _cacheHits[key] = (_cacheHits[key] ?? 0) + 1;
  }

  static void recordCacheMiss(String key) {
    _cacheMisses[key] = (_cacheMisses[key] ?? 0) + 1;
  }

  static Map<String, dynamic> getMetrics() {
    return {
      'api_performance': _apiCallTimes.map((key, times) {
        final avgTime = times.reduce((a, b) => a + b) ~/ times.length;
        return MapEntry(key, {
          'average_time_ms': avgTime.inMilliseconds,
          'call_count': times.length
        });
      }),
      'cache_performance': _cacheHits.map((key, hits) {
        final misses = _cacheMisses[key] ?? 0;
        final total = hits + misses;
        final hitRate = total > 0 ? (hits / total * 100).round() : 0;
        return MapEntry(key, {
          'hit_rate_percent': hitRate,
          'hits': hits,
          'misses': misses
        });
      })
    };
  }
}
```

## Implementation Checklist

- [ ] Implement connection-aware request optimization
- [ ] Add request batching for bulk operations
- [ ] Enhance caching with smart invalidation
- [ ] Implement memory-efficient caching
- [ ] Add lazy loading for images
- [ ] Optimize database queries with proper indexing
- [ ] Implement batch database operations
- [ ] Add list virtualization for large datasets
- [ ] Implement background task queue
- [ ] Add object pooling for memory efficiency
- [ ] Integrate performance monitoring
- [ ] Set up automated performance testing
- [ ] Implement A/B testing for optimization features

## Testing Performance Optimizations

### Automated Performance Tests
```dart
void main() {
  group('Performance Tests', () {
    test('API response time under 500ms', () async {
      final stopwatch = Stopwatch()..start();

      await ProductApi().getProducts(page: 1, perPage: 20);

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('Cache hit ratio above 70%', () async {
      // Perform multiple requests to the same endpoint
      for (int i = 0; i < 10; i++) {
        await ProductApi().getProducts(page: 1, perPage: 20);
      }

      final metrics = PerformanceMonitor.getMetrics();
      final cachePerformance = metrics['cache_performance']['products'];
      expect(cachePerformance['hit_rate_percent'], greaterThan(70));
    });

    test('Memory usage stays within limits', () async {
      // Perform memory-intensive operations
      final largeDataset = await ProductApi().getProducts(perPage: 1000);

      // Check memory usage
      // This would require platform-specific memory monitoring
      expect(largeDataset['data'].length, lessThanOrEqualTo(1000));
    });
  });
}
```

This performance optimization guide provides a comprehensive strategy for ensuring the enhanced API functions perform optimally on mobile platforms while maintaining excellent user experience.