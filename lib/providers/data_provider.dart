import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/api_service.dart';
import '../data/models/product_model.dart';
import '../data/models/client_model.dart';
import '../data/models/order_model.dart';

// Products provider
final productsProvider = FutureProvider.family<List<ProductModel>, String?>((ref, search) async {
  final response = await ApiService.instance.getProducts(
    params: search != null && search.isNotEmpty ? {'search': search} : null,
  );
  final data = response.data;
  final List products = data is Map ? (data['data'] ?? data['products'] ?? []) : data;
  return products.map((p) => ProductModel.fromJson(p)).toList();
});

// Single product provider
final productProvider = FutureProvider.family<ProductModel?, int>((ref, id) async {
  try {
    final response = await ApiService.instance.getProducts(params: {'id': id});
    final data = response.data;
    if (data is Map && data['data'] != null) {
      return ProductModel.fromJson(data['data']);
    }
    return null;
  } catch (e) {
    return null;
  }
});

// Clients provider
final clientsProvider = FutureProvider.family<List<ClientModel>, String?>((ref, search) async {
  final response = await ApiService.instance.getClients(
    params: search != null && search.isNotEmpty ? {'search': search} : null,
  );
  final data = response.data;
  final List clients = data is Map ? (data['data'] ?? data['clients'] ?? []) : data;
  return clients.map((c) => ClientModel.fromJson(c)).toList();
});

// Orders provider
final ordersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final response = await ApiService.instance.getMyOrders();
  final data = response.data;
  final List orders = data is Map ? (data['data'] ?? []) : data;
  return orders.map((o) => OrderModel.fromJson(o)).toList();
});

// Warehouses provider
final warehousesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiService.instance.getMasterData();
  final data = response.data;
  final List warehouses = data['warehouses'] ?? [];
  return warehouses.cast<Map<String, dynamic>>();
});

// Create order
class OrderNotifier extends StateNotifier<AsyncValue<OrderModel?>> {
  OrderNotifier() : super(const AsyncValue.data(null));

  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiService.instance.createOrder(orderData);
      final order = OrderModel.fromJson(response.data);
      state = AsyncValue.data(order);
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final orderNotifierProvider = StateNotifierProvider<OrderNotifier, AsyncValue<OrderModel?>>((ref) {
  return OrderNotifier();
});
