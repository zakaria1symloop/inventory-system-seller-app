import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity; // Cartons
  int extraPieces; // Extra individual pieces (0 to piecesPerPackage-1)
  double unitPrice; // Price per piece (will be multiplied by pieces_per_package)
  double originalPrice; // Original price per piece (to track changes)
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.extraPieces = 0,
    required this.unitPrice,
    double? originalPrice,
    this.discount = 0,
  }) : originalPrice = originalPrice ?? unitPrice;

  // Total pieces = (cartons × piecesPerPackage) + extraPieces
  int get totalPieces => (quantity * product.piecesPerPackage) + extraPieces;

  // Subtotal = unitPrice × totalPieces - discount
  double get subtotal => (unitPrice * totalPieces) - discount;

  // Quantity to send to backend: cartons + extraPieces/piecesPerPackage (decimal)
  double get orderQuantity {
    if (product.piecesPerPackage <= 1) return quantity.toDouble();
    return quantity + (extraPieces / product.piecesPerPackage);
  }

  Map<String, dynamic> toOrderItem() {
    return {
      'product_id': product.id,
      'quantity': orderQuantity,
      'unit_price': unitPrice,
      'discount': discount,
    };
  }
}

class CartState {
  final List<CartItem> items;
  final int? clientId;
  final String? clientName;
  final int? clientCategoryId;

  CartState({
    this.items = const [],
    this.clientId,
    this.clientName,
    this.clientCategoryId,
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
    int? clientCategoryId,
    bool clearClientCategoryId = false,
  }) {
    return CartState(
      items: items ?? this.items,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientCategoryId: clearClientCategoryId ? null : (clientCategoryId ?? this.clientCategoryId),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void setClient(int clientId, String clientName, {int? clientCategoryId}) {
    state = state.copyWith(
      clientId: clientId,
      clientName: clientName,
      clientCategoryId: clientCategoryId,
      clearClientCategoryId: clientCategoryId == null,
    );

    // Re-price existing cart items based on client category
    if (state.items.isNotEmpty) {
      final updatedItems = List<CartItem>.from(state.items);
      for (var item in updatedItems) {
        final categoryPrice = item.product.getPriceForCategory(clientCategoryId);
        item.unitPrice = categoryPrice;
      }
      state = state.copyWith(items: updatedItems);
    }
  }

  void addItem(ProductModel product, {int quantity = 1, double? price}) {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Update quantity if product already in cart
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex].quantity += quantity;
      state = state.copyWith(items: updatedItems);
    } else {
      // Add new item with category-specific price or default
      final unitPrice = price ?? product.getPriceForCategory(state.clientCategoryId);
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
      // Check if there are extra pieces — if so, keep the item with 0 cartons
      final updatedItems = List<CartItem>.from(state.items);
      final index = updatedItems.indexWhere((item) => item.product.id == productId);
      if (index >= 0 && updatedItems[index].extraPieces > 0) {
        updatedItems[index].quantity = 0;
        state = state.copyWith(items: updatedItems);
        return;
      }
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

  void updateExtraPieces(int productId, int pieces) {
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final item = updatedItems[index];
      // Clamp extra pieces to 0..(piecesPerPackage - 1)
      final maxPieces = item.product.piecesPerPackage - 1;
      updatedItems[index].extraPieces = pieces.clamp(0, maxPieces);
      // Remove item if both cartons and pieces are 0
      if (updatedItems[index].quantity <= 0 && updatedItems[index].extraPieces <= 0) {
        updatedItems.removeAt(index);
      }
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
