import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../helpers/api_cache.dart';
import '../models/system.dart';
import 'api.dart';

class ProductApi extends Api {
  // Get all products with filtering and pagination (with caching)
  Future<Map<String, dynamic>> getProducts(
      {int? categoryId,
      String? searchTerm,
      int? perPage = 50,
      int? page = 1,
      String? orderBy = 'name',
      String? orderDirection = 'asc',
      bool useCache = true}) async {
    // Create cache key based on parameters
    String cacheKey =
        'products_${categoryId ?? 'all'}_${searchTerm ?? 'none'}_${perPage ?? 50}_${page ?? 1}_${orderBy ?? 'name'}_${orderDirection ?? 'asc'}';

    // Try to get from cache first (only for first page and no search to avoid stale data)
    if (useCache && page == 1 && (searchTerm == null || searchTerm.isEmpty)) {
      Map<String, dynamic>? cachedData = await ApiCache.get(cacheKey);
      if (cachedData != null) {
        log("Returning cached products data");
        return cachedData;
      }
    }

    try {
      String url = '${this.baseUrl}${this.apiUrl}/product';

      // Build query parameters
      Map<String, String> queryParams = {};
      if (categoryId != null)
        queryParams['category_id'] = categoryId.toString();
      if (searchTerm != null && searchTerm.isNotEmpty)
        queryParams['search'] = searchTerm;
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (page != null) queryParams['page'] = page.toString();
      if (orderBy != null) queryParams['order_by'] = orderBy;
      if (orderDirection != null)
        queryParams['order_direction'] = orderDirection;

      if (queryParams.isNotEmpty) {
        String queryString =
            queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url += '?$queryString';
      }

      var token = await System().getToken();
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var products = jsonDecode(response.body);
        log("Products API Response: ${response.body}");

        Map<String, dynamic> result = {
          'data': products['data'] ?? [],
          'current_page': products['current_page'] ?? 1,
          'last_page': products['last_page'] ?? 1,
          'per_page': products['per_page'] ?? perPage,
          'total': products['total'] ?? 0,
          'links': products['links'] ?? {}
        };

        // Cache the result (only for first page and no search)
        if (useCache &&
            page == 1 &&
            (searchTerm == null || searchTerm.isEmpty)) {
          await ApiCache.set(cacheKey, result, duration: Duration(minutes: 15));
        }

        return result;
      } else {
        log("Products API Error: ${response.statusCode} - ${response.body}");
        return {
          'data': [],
          'current_page': 1,
          'last_page': 1,
          'per_page': perPage ?? 50,
          'total': 0,
          'links': {}
        };
      }
    } catch (e) {
      log("ERROR fetching products: ${e.toString()}");
      return {
        'data': [],
        'current_page': 1,
        'last_page': 1,
        'per_page': perPage ?? 50,
        'total': 0,
        'links': {}
      };
    }
  }

  // Get specific product by ID
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var product = jsonDecode(response.body);
        log("Product details API Response: ${response.body}");

        if (product != null && product['data'] != null) {
          return product['data'] as Map<String, dynamic>;
        } else {
          log("No product data found for ID: $productId");
          return null;
        }
      } else {
        log("Product API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching product by ID: ${e.toString()}");
      return null;
    }
  }

  // Create new product
  Future<Map<String, dynamic>?> createProduct(
      Map<String, dynamic> productData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product';
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(productData));

      if (response.statusCode == 201 || response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Create product API Response: ${response.body}");
        return result;
      } else {
        log("Create product API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR creating product: ${e.toString()}");
      return null;
    }
  }

  // Update product
  Future<Map<String, dynamic>?> updateProduct(
      String productId, Map<String, dynamic> productData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId';
      var token = await System().getToken();

      var response = await http.put(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(productData));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Update product API Response: ${response.body}");
        return result;
      } else {
        log("Update product API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR updating product: ${e.toString()}");
      return null;
    }
  }

  // Delete product
  Future<bool> deleteProduct(String productId) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId';
      var token = await System().getToken();

      var response =
          await http.delete(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("Product deleted successfully: $productId");
        return true;
      } else {
        log("Delete product API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR deleting product: ${e.toString()}");
      return false;
    }
  }

  // Get product categories
  Future<List<dynamic>> getProductCategories() async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/taxonomy?type=product';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var categories = jsonDecode(response.body);
        log("Product categories API Response: ${response.body}");

        if (categories != null && categories['data'] != null) {
          // Store categories in local database
          System().insert('product_categories', jsonEncode(categories['data']));
          return categories['data'] as List<dynamic>;
        } else {
          return [];
        }
      } else {
        log("Product categories API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching product categories: ${e.toString()}");
      return [];
    }
  }

  // Search products
  Future<Map<String, dynamic>> searchProducts(String query,
      {int? perPage = 20, int? page = 1}) async {
    return await getProducts(searchTerm: query, perPage: perPage, page: page);
  }

  // Get products by category
  Future<Map<String, dynamic>> getProductsByCategory(int categoryId,
      {int? perPage = 50, int? page = 1}) async {
    return await getProducts(
        categoryId: categoryId, perPage: perPage, page: page);
  }

  // Get low stock products
  Future<List<dynamic>> getLowStockProducts({int threshold = 10}) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product-stock-report?low_stock_threshold=$threshold';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var stockReport = jsonDecode(response.body);
        log("Low stock products API Response: ${response.body}");

        if (stockReport != null && stockReport['data'] != null) {
          List<dynamic> products = stockReport['data'];
          // Filter for low stock items
          return products.where((product) {
            int stock = product['current_stock'] ?? 0;
            return stock <= threshold && stock > 0;
          }).toList();
        } else {
          return [];
        }
      } else {
        log("Low stock products API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching low stock products: ${e.toString()}");
      return [];
    }
  }

  // Get out of stock products
  Future<List<dynamic>> getOutOfStockProducts() async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product-stock-report';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var stockReport = jsonDecode(response.body);
        log("Out of stock products API Response: ${response.body}");

        if (stockReport != null && stockReport['data'] != null) {
          List<dynamic> products = stockReport['data'];
          // Filter for out of stock items
          return products.where((product) {
            int stock = product['current_stock'] ?? 0;
            return stock <= 0;
          }).toList();
        } else {
          return [];
        }
      } else {
        log("Out of stock products API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching out of stock products: ${e.toString()}");
      return [];
    }
  }

  // Upload product image
  Future<Map<String, dynamic>?> uploadProductImage(
      String productId, String imagePath) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product/$productId/upload-image';
      var token = await System().getToken();

      // Create multipart request for file upload
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(this.getHeader('$token'));

      // Add image file
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var result = jsonDecode(responseData.body);
        log("Upload product image API Response: ${responseData.body}");
        return result;
      } else {
        log("Upload product image API Error: ${response.statusCode} - ${responseData.body}");
        return null;
      }
    } catch (e) {
      log("ERROR uploading product image: ${e.toString()}");
      return null;
    }
  }

  // Delete product image
  Future<bool> deleteProductImage(String productId, String imageId) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product/$productId/image/$imageId';
      var token = await System().getToken();

      var response =
          await http.delete(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("Product image deleted successfully: $imageId");
        return true;
      } else {
        log("Delete product image API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR deleting product image: ${e.toString()}");
      return false;
    }
  }

  // Create product variant
  Future<Map<String, dynamic>?> createProductVariant(
      String productId, Map<String, dynamic> variantData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId/variant';
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(variantData));

      if (response.statusCode == 201 || response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Create product variant API Response: ${response.body}");
        return result;
      } else {
        log("Create product variant API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR creating product variant: ${e.toString()}");
      return null;
    }
  }

  // Update product variant
  Future<Map<String, dynamic>?> updateProductVariant(String productId,
      String variantId, Map<String, dynamic> variantData) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product/$productId/variant/$variantId';
      var token = await System().getToken();

      var response = await http.put(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(variantData));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Update product variant API Response: ${response.body}");
        return result;
      } else {
        log("Update product variant API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR updating product variant: ${e.toString()}");
      return null;
    }
  }

  // Delete product variant
  Future<bool> deleteProductVariant(String productId, String variantId) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product/$productId/variant/$variantId';
      var token = await System().getToken();

      var response =
          await http.delete(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("Product variant deleted successfully: $variantId");
        return true;
      } else {
        log("Delete product variant API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR deleting product variant: ${e.toString()}");
      return false;
    }
  }

  // Create product category
  Future<Map<String, dynamic>?> createProductCategory(
      Map<String, dynamic> categoryData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/taxonomy';
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(categoryData));

      if (response.statusCode == 201 || response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Create product category API Response: ${response.body}");
        return result;
      } else {
        log("Create product category API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR creating product category: ${e.toString()}");
      return null;
    }
  }

  // Update product category
  Future<Map<String, dynamic>?> updateProductCategory(
      String categoryId, Map<String, dynamic> categoryData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/taxonomy/$categoryId';
      var token = await System().getToken();

      var response = await http.put(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(categoryData));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Update product category API Response: ${response.body}");
        return result;
      } else {
        log("Update product category API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR updating product category: ${e.toString()}");
      return null;
    }
  }

  // Delete product category
  Future<bool> deleteProductCategory(String categoryId) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/taxonomy/$categoryId';
      var token = await System().getToken();

      var response =
          await http.delete(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("Product category deleted successfully: $categoryId");
        return true;
      } else {
        log("Delete product category API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR deleting product category: ${e.toString()}");
      return false;
    }
  }

  // Create product tag
  Future<Map<String, dynamic>?> createProductTag(
      Map<String, dynamic> tagData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product-tags';
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(tagData));

      if (response.statusCode == 201 || response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Create product tag API Response: ${response.body}");
        return result;
      } else {
        log("Create product tag API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR creating product tag: ${e.toString()}");
      return null;
    }
  }

  // Get product tags
  Future<List<dynamic>> getProductTags() async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product-tags';
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var tags = jsonDecode(response.body);
        log("Product tags API Response: ${response.body}");

        if (tags != null && tags['data'] != null) {
          return tags['data'] as List<dynamic>;
        } else {
          return [];
        }
      } else {
        log("Product tags API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching product tags: ${e.toString()}");
      return [];
    }
  }

  // Add tag to product
  Future<bool> addTagToProduct(String productId, String tagId) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product/$productId/tag/$tagId';
      var token = await System().getToken();

      var response =
          await http.post(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 201) {
        log("Tag added to product successfully");
        return true;
      } else {
        log("Add tag to product API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR adding tag to product: ${e.toString()}");
      return false;
    }
  }

  // Remove tag from product
  Future<bool> removeTagFromProduct(String productId, String tagId) async {
    try {
      String url =
          '${this.baseUrl}${this.apiUrl}/product/$productId/tag/$tagId';
      var token = await System().getToken();

      var response =
          await http.delete(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        log("Tag removed from product successfully");
        return true;
      } else {
        log("Remove tag from product API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      log("ERROR removing tag from product: ${e.toString()}");
      return false;
    }
  }

  // Create product promotion/discount
  Future<Map<String, dynamic>?> createProductPromotion(
      Map<String, dynamic> promotionData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product-promotions';
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(promotionData));

      if (response.statusCode == 201 || response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Create product promotion API Response: ${response.body}");
        return result;
      } else {
        log("Create product promotion API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR creating product promotion: ${e.toString()}");
      return null;
    }
  }

  // Get product promotions
  Future<List<dynamic>> getProductPromotions({String? productId}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product-promotions';
      if (productId != null) {
        url += '?product_id=$productId';
      }
      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var promotions = jsonDecode(response.body);
        log("Product promotions API Response: ${response.body}");

        if (promotions != null && promotions['data'] != null) {
          return promotions['data'] as List<dynamic>;
        } else {
          return [];
        }
      } else {
        log("Product promotions API Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      log("ERROR fetching product promotions: ${e.toString()}");
      return [];
    }
  }

  // Update product stock
  Future<Map<String, dynamic>?> updateProductStock(
      String productId, Map<String, dynamic> stockData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId/stock';
      var token = await System().getToken();

      var response = await http.put(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(stockData));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Update product stock API Response: ${response.body}");
        return result;
      } else {
        log("Update product stock API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR updating product stock: ${e.toString()}");
      return null;
    }
  }

  // Get product analytics/performance
  Future<Map<String, dynamic>?> getProductAnalytics(String productId,
      {String? startDate, String? endDate}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId/analytics';

      Map<String, String> queryParams = {};
      if (startDate != null && startDate.isNotEmpty)
        queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty)
        queryParams['end_date'] = endDate;

      if (queryParams.isNotEmpty) {
        String queryString =
            queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
        url += '?$queryString';
      }

      var token = await System().getToken();
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var analytics = jsonDecode(response.body);
        log("Product analytics API Response: ${response.body}");
        return analytics['data'] as Map<String, dynamic>?;
      } else {
        log("Product analytics API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR fetching product analytics: ${e.toString()}");
      return null;
    }
  }

  // Bulk update products
  Future<Map<String, dynamic>?> bulkUpdateProducts(
      List<Map<String, dynamic>> productsData) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/products/bulk-update';
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'),
          body: jsonEncode({'products': productsData}));

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Bulk update products API Response: ${response.body}");
        return result;
      } else {
        log("Bulk update products API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR bulk updating products: ${e.toString()}");
      return null;
    }
  }

  // Get products by tags
  Future<Map<String, dynamic>> getProductsByTags(List<String> tagIds,
      {int? perPage = 50, int? page = 1}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/products/by-tags';

      Map<String, String> queryParams = {
        'tags': tagIds.join(','),
        'per_page': perPage.toString(),
        'page': page.toString()
      };

      String queryString =
          queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      url += '?$queryString';

      var token = await System().getToken();
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      if (response.statusCode == 200) {
        var products = jsonDecode(response.body);
        log("Products by tags API Response: ${response.body}");

        return {
          'data': products['data'] ?? [],
          'current_page': products['current_page'] ?? 1,
          'last_page': products['last_page'] ?? 1,
          'per_page': products['per_page'] ?? perPage,
          'total': products['total'] ?? 0
        };
      } else {
        log("Products by tags API Error: ${response.statusCode} - ${response.body}");
        return {
          'data': [],
          'current_page': 1,
          'last_page': 1,
          'per_page': perPage ?? 50,
          'total': 0
        };
      }
    } catch (e) {
      log("ERROR fetching products by tags: ${e.toString()}");
      return {
        'data': [],
        'current_page': 1,
        'last_page': 1,
        'per_page': 50,
        'total': 0
      };
    }
  }

  // Duplicate product
  Future<Map<String, dynamic>?> duplicateProduct(String productId,
      {String? newName,
      bool copyVariants = true,
      bool copyImages = true}) async {
    try {
      String url = '${this.baseUrl}${this.apiUrl}/product/$productId/duplicate';
      var token = await System().getToken();

      Map<String, dynamic> data = {
        'copy_variants': copyVariants,
        'copy_images': copyImages
      };
      if (newName != null) data['name'] = newName;

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: jsonEncode(data));

      if (response.statusCode == 201 || response.statusCode == 200) {
        var result = jsonDecode(response.body);
        log("Duplicate product API Response: ${response.body}");
        return result;
      } else {
        log("Duplicate product API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      log("ERROR duplicating product: ${e.toString()}");
      return null;
    }
  }
}
