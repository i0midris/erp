import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiCache {
  static const String _cachePrefix = 'api_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  // Get cached data
  static Future<Map<String, dynamic>?> get(String key) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('$_cachePrefix$key');

      if (cachedData != null) {
        Map<String, dynamic> cacheEntry = jsonDecode(cachedData);

        // Check if cache is expired
        DateTime cacheTime = DateTime.parse(cacheEntry['timestamp']);
        Duration cacheDuration =
            Duration(minutes: cacheEntry['duration_minutes'] ?? 30);

        if (DateTime.now().difference(cacheTime) < cacheDuration) {
          return cacheEntry['data'];
        } else {
          // Cache expired, remove it
          await remove(key);
        }
      }
    } catch (e) {
      print('Error retrieving cache: $e');
    }
    return null;
  }

  // Set cached data
  static Future<void> set(String key, Map<String, dynamic> data,
      {Duration? duration}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> cacheEntry = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'duration_minutes': (duration ?? _defaultCacheDuration).inMinutes
      };

      await prefs.setString('$_cachePrefix$key', jsonEncode(cacheEntry));
    } catch (e) {
      print('Error setting cache: $e');
    }
  }

  // Remove cached data
  static Future<void> remove(String key) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$key');
    } catch (e) {
      print('Error removing cache: $e');
    }
  }

  // Clear all cached data
  static Future<void> clear() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Check if data is cached and not expired
  static Future<bool> isCached(String key) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('$_cachePrefix$key');

      if (cachedData != null) {
        Map<String, dynamic> cacheEntry = jsonDecode(cachedData);
        DateTime cacheTime = DateTime.parse(cacheEntry['timestamp']);
        Duration cacheDuration =
            Duration(minutes: cacheEntry['duration_minutes'] ?? 30);

        return DateTime.now().difference(cacheTime) < cacheDuration;
      }
    } catch (e) {
      print('Error checking cache: $e');
    }
    return false;
  }

  // Get cache size (approximate)
  static Future<int> getCacheSize() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      int size = 0;

      for (String key in keys) {
        if (key.startsWith(_cachePrefix)) {
          String? data = prefs.getString(key);
          if (data != null) {
            size += data.length;
          }
        }
      }
      return size;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }

  // Clean expired cache entries
  static Future<void> cleanExpired() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      List<String> expiredKeys = [];

      for (String key in keys) {
        if (key.startsWith(_cachePrefix)) {
          String? cachedData = prefs.getString(key);
          if (cachedData != null) {
            Map<String, dynamic> cacheEntry = jsonDecode(cachedData);
            DateTime cacheTime = DateTime.parse(cacheEntry['timestamp']);
            Duration cacheDuration =
                Duration(minutes: cacheEntry['duration_minutes'] ?? 30);

            if (DateTime.now().difference(cacheTime) >= cacheDuration) {
              expiredKeys.add(key);
            }
          }
        }
      }

      for (String key in expiredKeys) {
        await prefs.remove(key);
      }

      if (expiredKeys.isNotEmpty) {
        print('Cleaned ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      print('Error cleaning expired cache: $e');
    }
  }
}

// Cache-aware API response wrapper
class CachedApiResponse {
  final Map<String, dynamic> data;
  final bool fromCache;
  final DateTime cacheTime;

  CachedApiResponse(
      {required this.data, required this.fromCache, required this.cacheTime});

  factory CachedApiResponse.fromCache(
      Map<String, dynamic> data, DateTime cacheTime) {
    return CachedApiResponse(data: data, fromCache: true, cacheTime: cacheTime);
  }

  factory CachedApiResponse.fromApi(Map<String, dynamic> data) {
    return CachedApiResponse(
        data: data, fromCache: false, cacheTime: DateTime.now());
  }
}
