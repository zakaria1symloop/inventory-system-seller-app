import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/models/client_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/api_service.dart';
import '../../providers/cart_provider.dart';

// Pagination state class
class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  PaginatedState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

// Clients state notifier with search and pagination
class ClientsNotifier extends StateNotifier<PaginatedState<ClientModel>> {
  String _searchQuery = '';

  ClientsNotifier() : super(PaginatedState<ClientModel>()) {
    loadClients();
  }

  Future<void> loadClients({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiService.instance.getClients(params: {
        'page': page,
        'per_page': 20,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> clientsList;
        int? lastPage;

        if (data is Map) {
          clientsList = data['data'] as List<dynamic>? ?? [];
          lastPage = data['last_page'] as int?;
        } else if (data is List) {
          clientsList = data;
        } else {
          clientsList = [];
        }

        final clients = clientsList.map((json) => ClientModel.fromJson(json)).toList();
        final hasMore = lastPage != null ? page < lastPage : clients.length >= 20;

        state = state.copyWith(
          items: refresh ? clients : [...state.items, ...clients],
          isLoading: false,
          hasMore: hasMore,
          currentPage: page + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void search(String query) {
    _searchQuery = query;
    state = PaginatedState<ClientModel>();
    loadClients(refresh: true);
  }

  void refresh() {
    state = PaginatedState<ClientModel>();
    loadClients(refresh: true);
  }
}

// Products state notifier with search and pagination
class ProductsNotifier extends StateNotifier<PaginatedState<ProductModel>> {
  String _searchQuery = '';

  ProductsNotifier() : super(PaginatedState<ProductModel>()) {
    loadProducts();
  }

  Future<void> loadProducts({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiService.instance.getProducts(params: {
        'page': page,
        'per_page': 20,
        'warehouse_id': 1, // Get stock for warehouse 1
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> productsList;
        int? lastPage;

        if (data is Map) {
          productsList = data['data'] as List<dynamic>? ?? [];
          lastPage = data['last_page'] as int?;
        } else if (data is List) {
          productsList = data;
        } else {
          productsList = [];
        }

        final products = productsList.map((json) => ProductModel.fromJson(json)).toList();
        final hasMore = lastPage != null ? page < lastPage : products.length >= 20;

        state = state.copyWith(
          items: refresh ? products : [...state.items, ...products],
          isLoading: false,
          hasMore: hasMore,
          currentPage: page + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void search(String query) {
    _searchQuery = query;
    state = PaginatedState<ProductModel>();
    loadProducts(refresh: true);
  }

  void refresh() {
    state = PaginatedState<ProductModel>();
    loadProducts(refresh: true);
  }
}

// Providers
final orderClientsProvider = StateNotifierProvider<ClientsNotifier, PaginatedState<ClientModel>>((ref) {
  return ClientsNotifier();
});

final orderProductsProvider = StateNotifierProvider<ProductsNotifier, PaginatedState<ProductModel>>((ref) {
  return ProductsNotifier();
});

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  int _currentStep = 0;
  final _clientSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _clientScrollController = ScrollController();
  final _productScrollController = ScrollController();
  bool _isSubmitting = false;

  // Map to store quantity controllers for each product
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _piecesControllers = {};

  // Debounce timer for search
  DateTime? _lastClientSearch;
  DateTime? _lastProductSearch;

  @override
  void initState() {
    super.initState();
    _clientScrollController.addListener(_onClientScroll);
    _productScrollController.addListener(_onProductScroll);
  }

  void _onClientScroll() {
    if (_clientScrollController.position.pixels >=
        _clientScrollController.position.maxScrollExtent - 200) {
      ref.read(orderClientsProvider.notifier).loadClients();
    }
  }

  void _onProductScroll() {
    if (_productScrollController.position.pixels >=
        _productScrollController.position.maxScrollExtent - 200) {
      ref.read(orderProductsProvider.notifier).loadProducts();
    }
  }

  void _onClientSearchChanged(String value) {
    setState(() {}); // Update clear button visibility
    _lastClientSearch = DateTime.now();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastClientSearch != null &&
          DateTime.now().difference(_lastClientSearch!).inMilliseconds >= 500) {
        ref.read(orderClientsProvider.notifier).search(value);
      }
    });
  }

  void _onProductSearchChanged(String value) {
    setState(() {}); // Update clear button visibility
    _lastProductSearch = DateTime.now();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_lastProductSearch != null &&
          DateTime.now().difference(_lastProductSearch!).inMilliseconds >= 500) {
        ref.read(orderProductsProvider.notifier).search(value);
      }
    });
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _productSearchController.dispose();
    _clientScrollController.dispose();
    _productScrollController.dispose();
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (var controller in _piecesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getQtyController(int productId, int currentQty) {
    if (!_qtyControllers.containsKey(productId)) {
      _qtyControllers[productId] = TextEditingController(text: currentQty.toString());
    } else if (_qtyControllers[productId]!.text != currentQty.toString()) {
      _qtyControllers[productId]!.text = currentQty.toString();
    }
    return _qtyControllers[productId]!;
  }

  TextEditingController _getPiecesController(int productId, int currentPieces) {
    if (!_piecesControllers.containsKey(productId)) {
      _piecesControllers[productId] = TextEditingController(text: currentPieces.toString());
    } else if (_piecesControllers[productId]!.text != currentPieces.toString()) {
      _piecesControllers[productId]!.text = currentPieces.toString();
    }
    return _piecesControllers[productId]!;
  }

  void _clearQtyControllers() {
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    _qtyControllers.clear();
    for (var controller in _piecesControllers.values) {
      controller.dispose();
    }
    _piecesControllers.clear();
  }

  void _selectClient(ClientModel client) {
    ref.read(cartProvider.notifier).setClient(
      client.id,
      client.name,
      clientCategoryId: client.clientCategoryId,
    );
    setState(() {
      _currentStep = 1;
    });
  }

  int _getAvailableStock(ProductModel product) {
    // Use effectiveStock which prioritizes available_stock over current_stock
    return product.effectiveStock;
  }

  void _updateQuantityFromText(ProductModel product, String text) {
    final availableStock = _getAvailableStock(product);
    int qty = int.tryParse(text) ?? 0;

    if (qty > availableStock) {
      qty = availableStock;
      _qtyControllers[product.id]?.text = qty.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الحد الأقصى: $availableStock'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    if (qty > 0) {
      ref.read(cartProvider.notifier).updateQuantity(product.id, qty);
    } else {
      ref.read(cartProvider.notifier).removeItem(product.id);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.clientId == null || cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار عميل وإضافة منتجات')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final orderData = {
        'client_id': cart.clientId,
        'warehouse_id': 1,
        'status': 'pending',
        'items': ref.read(cartProvider.notifier).getOrderItems(),
        'notes': '',
      };

      final response = await ApiService.instance.createOrder(orderData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ref.read(cartProvider.notifier).clearCart();
        // Refresh products to get updated available stock
        ref.read(orderProductsProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final errorMsg = response.data?['message'] ?? 'فشل في إنشاء الطلب';
        _showErrorDialog('خطأ', errorMsg);
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMessage = 'حدث خطأ غير متوقع';
        if (e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey('message')) {
            errorMessage = data['message'];
          }
        }
        _showErrorDialog('خطأ في الطلب', errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('خطأ', 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _addToCart(ProductModel product) {
    final availableStock = _getAvailableStock(product);
    final cart = ref.read(cartProvider);
    final existingItem = cart.items.where((i) => i.product.id == product.id).firstOrNull;
    final currentQty = existingItem?.quantity ?? 0;

    if (currentQty + 1 > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الكمية المتوفرة: $availableStock فقط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ref.read(cartProvider.notifier).addItem(product);
  }

  void _incrementQuantity(ProductModel product, int currentQty) {
    final availableStock = _getAvailableStock(product);
    if (currentQty + 1 > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الكمية المتوفرة: $availableStock فقط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    ref.read(cartProvider.notifier).updateQuantity(product.id, currentQty + 1);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle()),
          actions: [
            if (cart.items.isNotEmpty)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      setState(() {
                        _currentStep = 2;
                      });
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _buildCurrentStep(),
        bottomNavigationBar: _buildBottomBar(cart),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'اختيار العميل';
      case 1:
        return 'اختيار المنتجات';
      case 2:
        return 'مراجعة الطلب';
      default:
        return 'طلب جديد';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildClientSelection();
      case 1:
        return _buildProductSelection();
      case 2:
        return _buildCartReview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildClientSelection() {
    final clientsState = ref.watch(orderClientsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/add-client');
                    if (result == true) {
                      ref.read(orderClientsProvider.notifier).refresh();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة عميل جديد'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _clientSearchController,
            decoration: InputDecoration(
              hintText: 'بحث عن عميل...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _clientSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _clientSearchController.clear();
                        ref.read(orderClientsProvider.notifier).search('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: _onClientSearchChanged,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildClientsList(clientsState),
        ),
      ],
    );
  }

  Widget _buildClientsList(PaginatedState<ClientModel> state) {
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('خطأ: ${state.error}'),
            ElevatedButton(
              onPressed: () => ref.read(orderClientsProvider.notifier).refresh(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty && !state.isLoading) {
      return const Center(
        child: Text('لا يوجد عملاء'),
      );
    }

    return ListView.builder(
      controller: _clientScrollController,
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final client = state.items[index];
        return ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Row(
            children: [
              Flexible(child: Text(client.name)),
              if (client.clientCategoryName != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    client.clientCategoryName!,
                    style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(client.phone ?? ''),
          trailing: const Icon(Icons.arrow_back_ios),
          onTap: () => _selectClient(client),
        );
      },
    );
  }

  Widget _buildProductSelection() {
    final productsState = ref.watch(orderProductsProvider);
    final cart = ref.watch(cartProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _productSearchController,
            decoration: InputDecoration(
              hintText: 'بحث عن منتج...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _productSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _productSearchController.clear();
                        ref.read(orderProductsProvider.notifier).search('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: _onProductSearchChanged,
          ),
        ),
        Expanded(
          child: _buildProductsList(productsState, cart),
        ),
      ],
    );
  }

  Widget _buildProductsList(PaginatedState<ProductModel> state, CartState cart) {
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('خطأ: ${state.error}'),
            ElevatedButton(
              onPressed: () => ref.read(orderProductsProvider.notifier).refresh(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty && !state.isLoading) {
      return const Center(
        child: Text('لا توجد منتجات'),
      );
    }

    return ListView.builder(
      controller: _productScrollController,
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final product = state.items[index];
        final cartItem = cart.items.where((i) => i.product.id == product.id).firstOrNull;
        final inCart = cartItem != null;
        final availableStock = _getAvailableStock(product);
        final isOutOfStock = availableStock <= 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final categoryId = ref.read(cartProvider).clientCategoryId;
                        final displayPrice = product.getPriceForCategory(categoryId);
                        final isCustomPrice = categoryId != null && product.categoryPrices.containsKey(categoryId);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCustomPrice
                                ? Colors.amber.withOpacity(0.15)
                                : Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${displayPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isCustomPrice ? Colors.amber[800] : Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'د.ج/قطعة',
                                    style: TextStyle(
                                      color: isCustomPrice
                                          ? Colors.amber[700]
                                          : Theme.of(context).primaryColor.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (product.piecesPerPackage > 1)
                                Text(
                                  '${(displayPrice * product.piecesPerPackage).toStringAsFixed(2)} د.ج/كرتون',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      if (product.piecesPerPackage > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${product.piecesPerPackage} قطعة/${product.unitSaleShortName ?? "وحدة"}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isOutOfStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                            size: 14,
                            color: isOutOfStock ? Colors.red : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'المتوفر: $availableStock',
                            style: TextStyle(
                              color: isOutOfStock ? Colors.red : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (inCart)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cartons row
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (cartItem.quantity > 1) {
                                  ref.read(cartProvider.notifier).updateQuantity(
                                    product.id,
                                    cartItem.quantity - 1,
                                  );
                                } else if (cartItem.extraPieces > 0) {
                                  ref.read(cartProvider.notifier).updateQuantity(product.id, 0);
                                } else {
                                  ref.read(cartProvider.notifier).removeItem(product.id);
                                  _qtyControllers.remove(product.id);
                                  _piecesControllers.remove(product.id);
                                }
                              },
                              iconSize: 20,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(
                              width: 50,
                              child: TextField(
                                controller: _getQtyController(product.id, cartItem.quantity),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                onSubmitted: (value) => _updateQuantityFromText(product, value),
                                onTapOutside: (_) {
                                  final controller = _qtyControllers[product.id];
                                  if (controller != null) {
                                    _updateQuantityFromText(product, controller.text);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: cartItem.quantity >= availableStock
                                    ? Colors.grey
                                    : null,
                              ),
                              onPressed: cartItem.quantity >= availableStock
                                  ? null
                                  : () => _incrementQuantity(product, cartItem.quantity),
                              iconSize: 20,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Extra pieces row (only for products with piecesPerPackage > 1)
                      if (product.piecesPerPackage > 1) ...[
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: cartItem.extraPieces > 0
                                    ? () {
                                        ref.read(cartProvider.notifier).updateExtraPieces(
                                          product.id,
                                          cartItem.extraPieces - 1,
                                        );
                                      }
                                    : null,
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                              SizedBox(
                                width: 30,
                                child: TextField(
                                  controller: _getPiecesController(product.id, cartItem.extraPieces),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.orange[800],
                                  ),
                                  onSubmitted: (value) {
                                    int pieces = int.tryParse(value) ?? 0;
                                    ref.read(cartProvider.notifier).updateExtraPieces(product.id, pieces);
                                  },
                                  onTapOutside: (_) {
                                    final controller = _piecesControllers[product.id];
                                    if (controller != null) {
                                      int pieces = int.tryParse(controller.text) ?? 0;
                                      ref.read(cartProvider.notifier).updateExtraPieces(product.id, pieces);
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: cartItem.extraPieces >= product.piecesPerPackage - 1
                                      ? Colors.grey
                                      : Colors.orange[800],
                                ),
                                onPressed: cartItem.extraPieces >= product.piecesPerPackage - 1
                                    ? null
                                    : () {
                                        ref.read(cartProvider.notifier).updateExtraPieces(
                                          product.id,
                                          cartItem.extraPieces + 1,
                                        );
                                      },
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'قطعة',
                          style: TextStyle(fontSize: 9, color: Colors.orange[700]),
                        ),
                      ],
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: isOutOfStock ? null : () => _addToCart(product),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isOutOfStock ? 'نفذ' : 'إضافة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: isOutOfStock ? Colors.grey : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartReview() {
    final cart = ref.watch(cartProvider);

    if (cart.items.isEmpty) {
      return const Center(
        child: Text('السلة فارغة'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                Text('العميل: ${cart.clientName ?? "غير محدد"}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'المنتجات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...cart.items.map((item) {
          final availableStock = _getAvailableStock(item.product);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${item.unitPrice.toStringAsFixed(0)} د.ج/قطعة',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                            if (item.product.piecesPerPackage > 1)
                              Text(
                                '${(item.unitPrice * item.product.piecesPerPackage).toStringAsFixed(0)} د.ج/كرتون',
                                style: TextStyle(color: Colors.orange[700], fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            if (item.product.piecesPerPackage > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.product.piecesPerPackage}ق',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Quantity controls
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cartons row
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  ref.read(cartProvider.notifier).updateQuantity(
                                    item.product.id,
                                    item.quantity - 1,
                                  );
                                } else if (item.extraPieces > 0) {
                                  ref.read(cartProvider.notifier).updateQuantity(item.product.id, 0);
                                } else {
                                  ref.read(cartProvider.notifier).removeItem(item.product.id);
                                }
                              },
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(
                              width: 40,
                              child: TextField(
                                controller: _getQtyController(item.product.id, item.quantity),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                onSubmitted: (value) => _updateQuantityFromText(item.product, value),
                                onTapOutside: (_) {
                                  final controller = _qtyControllers[item.product.id];
                                  if (controller != null) {
                                    _updateQuantityFromText(item.product, controller.text);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                size: 18,
                                color: item.quantity >= availableStock ? Colors.grey : null,
                              ),
                              onPressed: item.quantity >= availableStock
                                  ? null
                                  : () => _incrementQuantity(item.product, item.quantity),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Extra pieces row for cart review
                      if (item.product.piecesPerPackage > 1) ...[
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange[300]!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 14),
                                onPressed: item.extraPieces > 0
                                    ? () {
                                        ref.read(cartProvider.notifier).updateExtraPieces(
                                          item.product.id,
                                          item.extraPieces - 1,
                                        );
                                      }
                                    : null,
                                iconSize: 14,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              ),
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${item.extraPieces}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, size: 14, color: item.extraPieces >= item.product.piecesPerPackage - 1 ? Colors.grey : Colors.orange[800]),
                                onPressed: item.extraPieces >= item.product.piecesPerPackage - 1
                                    ? null
                                    : () {
                                        ref.read(cartProvider.notifier).updateExtraPieces(
                                          item.product.id,
                                          item.extraPieces + 1,
                                        );
                                      },
                                iconSize: 14,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              ),
                            ],
                          ),
                        ),
                        Text('قطعة', style: TextStyle(fontSize: 8, color: Colors.orange[700])),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.subtotal.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item.extraPieces > 0
                            ? '${item.quantity}كرتون+${item.extraPieces}ق'
                            : '${item.unitPrice.toStringAsFixed(0)}×${item.quantity}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () {
                      ref.read(cartProvider.notifier).removeItem(item.product.id);
                      _qtyControllers.remove(item.product.id);
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const Divider(height: 32),
        Card(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${cart.totalAmount.toStringAsFixed(2)} د.ج',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar(CartState cart) {
    if (_currentStep == 0) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // If going back from products to client selection, clear cart
                  if (_currentStep == 1) {
                    ref.read(cartProvider.notifier).clearCart();
                    _clearQtyControllers();
                  }
                  setState(() {
                    _currentStep--;
                  });
                },
                child: const Text('رجوع'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep == 1) {
                        if (cart.items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى إضافة منتجات للسلة')),
                          );
                          return;
                        }
                        setState(() {
                          _currentStep = 2;
                        });
                      } else if (_currentStep == 2) {
                        _submitOrder();
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_currentStep == 2 ? 'تأكيد الطلب' : 'متابعة'),
            ),
          ),
        ],
      ),
    );
  }
}
