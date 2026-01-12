import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;
  double unitPrice; // Price per 1 piece
  double originalPrice; // Original price per piece (to track changes)
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    required this.unitPrice,
    double? originalPrice,
    this.discount = 0,
  }) : originalPrice = originalPrice ?? unitPrice;

  // Subtotal = unit_price (per piece) × pieces_per_package × quantity - discount
  double get subtotal => (unitPrice * product.piecesPerPackage * quantity) - discount;

  Map<String, dynamic> toOrderItem() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
    };
  }
}

class CartState {
  final List<CartItem> items;
  final int? clientId;
  final String? clientName;

  CartState({
    this.items = const [],
    this.clientId,
    this.clientName,
  });

  double get totalAmount {
    return items.fold(0, (sum, item) => sum + item.subtotal);
  }

  int get itemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  CartState copyWith({
    List<CartItem>? items,
    int? clientId,
    String? clientName,
  }) {
    return CartState(
      items: items ?? this.items,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void setClient(int clientId, String clientName) {
    state = state.copyWith(clientId: clientId, clientName: clientName);
  }

  void addItem(ProductModel product, {int quantity = 1, double? price}) {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Update quantity if product already in cart
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex].quantity += quantity;
      state = state.copyWith(items: updatedItems);
    } else {
      // Add new item with unit price (per carton/box)
      final unitPrice = price ?? product.unitPrice;
      final newItem = CartItem(
        product: product,
        quantity: quantity,
        unitPrice: unitPrice,
        originalPrice: unitPrice,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void updatePrice(int productId, double price) {
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      updatedItems[index].unitPrice = price;
      state = state.copyWith(items: updatedItems);
    }
  }

  void removeItem(int productId) {
    final updatedItems = state.items.where((item) => item.product.id != productId).toList();
    state = state.copyWith(items: updatedItems);
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      updatedItems[index].quantity = quantity;
      state = state.copyWith(items: updatedItems);
    }
  }

  void updateDiscount(int productId, double discount) {
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      updatedItems[index].discount = discount;
      state = state.copyWith(items: updatedItems);
    }
  }

  void clearCart() {
    state = CartState();
  }

  List<Map<String, dynamic>> getOrderItems() {
    return state.items.map((item) => item.toOrderItem()).toList();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
