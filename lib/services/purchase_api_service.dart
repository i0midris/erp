import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config.dart';

import '../models/purchase_models.dart';
import '../models/system.dart';

/// API Service for Purchase operations
/// Based on Modules/Connector PurchaseController implementation
class PurchaseApiService {
  final Dio _dio;
  final String _baseUrl;
  final String _apiUrl;

  PurchaseApiService({
    required Dio dio,
    required String baseUrl,
    String apiUrl = '/connector/api',
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _apiUrl = apiUrl {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // Add request/response interceptors for logging and auth
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authorization header
          try {
            final token = await System().getToken();
            if (token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
              log('API Request: ${options.method} ${options.uri} (Authenticated)');
            } else {
              log('API Request: ${options.method} ${options.uri} (No Auth Token)');
            }
          } catch (e) {
            log('Error getting auth token: $e');
          }
          options.headers['Content-Type'] = 'application/json';
          options.headers['Accept'] = 'application/json';

          if (options.data != null) {
            log('Request Data: ${options.data}');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          log('API Response: ${response.statusCode} ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (error, handler) {
          log('API Error: ${error.response?.statusCode} ${error.requestOptions.uri}');
          if (error.response?.data != null) {
            log('Error Data: ${error.response?.data}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // (removed unused _getToken helper)

  /// Create a new purchase
  Future<Purchase> createPurchase(CreatePurchaseRequest request) async {
    try {
      final response = await _dio.post(
        '$_apiUrl/purchase',
        data: request.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;

        // Handle Laravel API Resource response format: { data: {...}, success: true, ... }
        if (data['success'] == true && data['data'] != null) {
          return Purchase.fromJson(data['data']);
        }
        // Handle direct response format: { id: 123, contact_id: 4, ... }
        else if (data is Map && data['id'] != null) {
          return Purchase.fromJson(data.cast<String, dynamic>());
        } else {
          throw ApiException(
            message: data['msg'] ?? 'Failed to create purchase',
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiException(
          message: 'Failed to create purchase',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Update an existing purchase
  Future<Purchase> updatePurchase(UpdatePurchaseRequest request) async {
    try {
      final response = await _dio.put(
        '$_apiUrl/purchase/${request.purchaseId}',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return Purchase.fromJson(data['data']);
        } else {
          throw ApiException(
            message: data['msg'] ?? 'Failed to update purchase',
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiException(
          message: 'Failed to update purchase',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Get purchase by ID
  Future<Purchase> getPurchase(int purchaseId) async {
    try {
      final response = await _dio.get('$_apiUrl/purchase/$purchaseId');

      if (response.statusCode == 200) {
        final data = response.data;
        // Accept both connector style {data: {...}} and plain object
        if (data is Map && data['data'] != null) {
          return Purchase.fromJson(
              (data['data'] as Map).cast<String, dynamic>());
        }
        if (data is Map) {
          return Purchase.fromJson((data as Map).cast<String, dynamic>());
        }
        throw ApiException(
          message: 'Purchase not found',
          statusCode: response.statusCode,
        );
      } else {
        throw ApiException(
          message: 'Failed to fetch purchase',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Get list of purchases with filtering
  Future<PurchaseListResponse> getPurchases({
    int? supplierId,
    int? locationId,
    String? status,
    String? paymentStatus,
    DateTime? startDate,
    DateTime? endDate,
    String? refNo,
    int? perPage = 20,
    int? page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId;
      }
      if (locationId != null) {
        queryParams['location_id'] = locationId;
      }
      if (status != null) {
        queryParams['status'] = status;
      }
      if (paymentStatus != null) {
        queryParams['payment_status'] = paymentStatus;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (refNo != null) {
        queryParams['ref_no'] = refNo;
      }
      if (perPage != null) {
        queryParams['per_page'] = perPage;
      }
      if (page != null) {
        queryParams['page'] = page;
      }

      final response = await _dio.get(
        '$_apiUrl/purchase',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle connector style: { data: [...], current_page, last_page, ... }
        if (data is Map && data['data'] is List) {
          final list = (data['data'] as List)
              .map((item) =>
                  Purchase.fromJson((item as Map).cast<String, dynamic>()))
              .toList();
          return PurchaseListResponse(
            purchases: list,
            currentPage:
                data['current_page'] ?? data['data']['current_page'] ?? 1,
            lastPage: data['last_page'] ?? data['data']['last_page'] ?? 1,
            perPage:
                data['per_page'] ?? data['data']['per_page'] ?? (perPage ?? 20),
            total: data['total'] ?? data['data']['total'] ?? list.length,
          );
        }

        // Handle legacy wrapper: { success:true, data:{ data:[...], ... } }
        if (data is Map && data['success'] == true && data['data'] is Map) {
          final inner = data['data'] as Map;
          final list = (inner['data'] as List?)
                  ?.map((item) =>
                      Purchase.fromJson((item as Map).cast<String, dynamic>()))
                  .toList() ??
              [];
          return PurchaseListResponse(
            purchases: list,
            currentPage: inner['current_page'] ?? 1,
            lastPage: inner['last_page'] ?? 1,
            perPage: inner['per_page'] ?? (perPage ?? 20),
            total: inner['total'] ?? list.length,
          );
        }

        throw ApiException(
          message: 'Failed to fetch purchases',
          statusCode: response.statusCode,
        );
      } else {
        throw ApiException(
          message: 'Failed to fetch purchases',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Delete purchase
  Future<void> deletePurchase(int purchaseId) async {
    try {
      final response = await _dio.delete('$_apiUrl/purchase/$purchaseId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final data = response.data;
        if (data['success'] == true) {
          return;
        } else {
          throw ApiException(
            message: data['msg'] ?? 'Failed to delete purchase',
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiException(
          message: 'Failed to delete purchase',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Update purchase status
  Future<void> updatePurchaseStatus(int purchaseId, String status) async {
    try {
      final response = await _dio.post(
        '$_apiUrl/purchase/$purchaseId/status',
        data: {'status': status},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return;
        } else {
          throw ApiException(
            message: data['msg'] ?? 'Failed to update status',
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiException(
          message: 'Failed to update status',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Get suppliers for purchase
  Future<List<Supplier>> getSuppliers({String? searchTerm}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (searchTerm != null && searchTerm.isNotEmpty) {
        queryParams['name'] = searchTerm;
      }

      final response = await _dio.get(
        '$_apiUrl/purchase/suppliers',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((item) => Supplier.fromJson(item)).toList();
        }
        if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => Supplier.fromJson(item))
              .toList();
        }
        if (data is Map && data['results'] is List) {
          return (data['results'] as List)
              .map((item) => Supplier.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw ApiException(
          message: 'Failed to fetch suppliers',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Get products for purchase
  Future<List<PurchaseProduct>> getProducts({String? searchTerm}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (searchTerm != null && searchTerm.isNotEmpty) {
        queryParams['name'] = searchTerm;
      }

      final response = await _dio.get(
        '$_apiUrl/purchase/products',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((item) => PurchaseProduct.fromJson(item)).toList();
        }
        if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => PurchaseProduct.fromJson(item))
              .toList();
        }
        if (data is Map && data['results'] is List) {
          return (data['results'] as List)
              .map((item) => PurchaseProduct.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw ApiException(
          message: 'Failed to fetch products',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Get locations for purchase
  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final response = await _dio.get('$_apiUrl/business-location');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((item) => item as Map<String, dynamic>).toList();
        }
        if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        }
        if (data is Map && data['results'] is List) {
          return (data['results'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        }
        return [];
      } else {
        throw ApiException(
          message: 'Failed to fetch locations',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Check if reference number is duplicate
  Future<bool> checkReferenceNumber(int supplierId, String refNo) async {
    try {
      final params = {
        'contact_id': supplierId,
        'ref_no': refNo,
      };
      final response = await _dio.get(
        '$_apiUrl/purchase/check-ref',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['exists'] == true;
      } else {
        throw ApiException(
          message: 'Failed to check reference number',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Unexpected error: $e');
    }
  }

  /// Handle Dio errors and convert to ApiException
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Connection timeout. Please check your internet connection.',
          statusCode: 408,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        if (statusCode == 401) {
          // Clear invalid token on authentication failure
          try {
            // Note: This assumes System() has a clearToken method
            // You may need to implement this in your System class
            // System().clearToken();
          } catch (_) {}
          return ApiException(
            message: 'Authentication failed. Please login again.',
            statusCode: statusCode,
          );
        } else if (statusCode == 403) {
          return ApiException(
            message: 'You do not have permission to perform this action.',
            statusCode: statusCode,
          );
        } else if (statusCode == 404) {
          return ApiException(
            message:
                'API endpoint not found. Please check your connection or contact support.',
            statusCode: statusCode,
          );
        } else if (statusCode == 422) {
          // Validation errors
          String message = 'Validation failed';
          if (data != null && data['errors'] != null) {
            final errors = data['errors'] as Map<String, dynamic>;
            final errorMessages = <String>[];
            errors.forEach((field, messages) {
              if (messages is List) {
                errorMessages.addAll(messages.map((msg) => '$field: $msg'));
              }
            });
            message = errorMessages.join('\n');
          }
          return ApiException(
            message: message,
            statusCode: statusCode,
          );
        } else {
          // Try to extract meaningful message across different backend wrappers
          String message = 'Server error occurred';
          try {
            final d = data as dynamic;
            message = d?['message'] ??
                d?['msg'] ??
                d?['error']?['message'] ??
                d?['error'] ??
                message;
          } catch (_) {}
          return ApiException(
            message: message,
            statusCode: statusCode,
          );
        }

      case DioExceptionType.cancel:
        return const ApiException(
          message: 'Request was cancelled',
          statusCode: 499,
        );

      default:
        return const ApiException(
          message: 'Network error occurred. Please try again.',
          statusCode: 0,
        );
    }
  }
}

/// Response model for purchase list
class PurchaseListResponse {
  final List<Purchase> purchases;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PurchaseListResponse({
    required this.purchases,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasNextPage => currentPage < lastPage;
  bool get hasPreviousPage => currentPage > 1;
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Provider for PurchaseApiService
final purchaseApiServiceProvider = Provider<PurchaseApiService>((ref) {
  final dio = Dio();
  return PurchaseApiService(
    dio: dio,
    baseUrl: Config.baseUrl,
  );
});
