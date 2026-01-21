import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  late final Dio _dio;
  static ApiService? _instance;

  ApiService._() {
    debugPrint('[API] Initializing with baseUrl: ${ApiConstants.baseUrl}');
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.timeout,
      receiveTimeout: ApiConstants.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        debugPrint('[API] REQUEST: ${options.method} ${options.uri}');
        debugPrint('[API] DATA: ${options.data}');
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('[API] RESPONSE: ${response.statusCode}');
        return handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('[API] ERROR: ${error.type}');
        debugPrint('[API] ERROR message: ${error.message}');
        debugPrint('[API] ERROR response: ${error.response?.data}');
        if (error.response?.statusCode == 401) {
          // Handle unauthorized
        }
        return handler.next(error);
      },
    ));
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  // Auth
  Future<Response> login(String email, String password) async {
    debugPrint('[API] login called');
    return _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> logout() async {
    return _dio.post(ApiConstants.logout);
  }

  Future<Response> getUser() async {
    return _dio.get(ApiConstants.user);
  }

  // Sync
  Future<Response> getMasterData() async {
    return _dio.get(ApiConstants.masterData);
  }

  Future<Response> pushChanges(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.pushChanges, data: data);
  }

  // Trips
  Future<Response> getMyActiveTrip() async {
    return _dio.get(ApiConstants.myActiveTrip);
  }

  Future<Response> getMyTrips() async {
    return _dio.get(ApiConstants.myTrips);
  }

  Future<Response> startTrip(int vehicleId) async {
    return _dio.post(ApiConstants.trips, data: {
      'vehicle_id': vehicleId,
    });
  }

  Future<Response> completeTrip(int tripId) async {
    return _dio.post('${ApiConstants.trips}/$tripId/complete');
  }

  Future<Response> addStoreToTrip(int tripId, int clientId) async {
    return _dio.post('${ApiConstants.trips}/$tripId/stores', data: {
      'client_id': clientId,
    });
  }

  Future<Response> visitStore(int tripId, int storeId) async {
    return _dio.post('${ApiConstants.trips}/$tripId/stores/$storeId/visit');
  }

  Future<Response> skipStore(int tripId, int storeId, String? notes) async {
    return _dio.post('${ApiConstants.trips}/$tripId/stores/$storeId/skip', data: {
      'notes': notes,
    });
  }

  // Orders
  Future<Response> getMyOrders({Map<String, dynamic>? params}) async {
    return _dio.get(ApiConstants.myOrders, queryParameters: params);
  }

  Future<Response> getOrder(int orderId) async {
    return _dio.get('${ApiConstants.orders}/$orderId');
  }

  Future<Response> createOrder(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.orders, data: data);
  }

  // Products
  Future<Response> getProducts({Map<String, dynamic>? params}) async {
    return _dio.get(ApiConstants.products, queryParameters: params);
  }

  Future<Response> findByBarcode(String barcode) async {
    return _dio.post('${ApiConstants.products}/find-by-barcode', data: {
      'barcode': barcode,
    });
  }

  // Clients
  Future<Response> getClients({Map<String, dynamic>? params}) async {
    return _dio.get(ApiConstants.clients, queryParameters: params);
  }

  Future<Response> createClient(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.clients, data: data);
  }

  Future<Response> recordClientPayment(int clientId, double amount, String? notes) async {
    return _dio.post('${ApiConstants.clients}/$clientId/payments', data: {
      'amount': amount,
      'notes': notes,
    });
  }

  // Warehouses
  Future<Response> getWarehouses() async {
    return _dio.get('/warehouses');
  }
}
