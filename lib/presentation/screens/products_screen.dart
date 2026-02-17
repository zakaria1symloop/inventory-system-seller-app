import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../data/models/product_model.dart";
import "../../data/services/api_service.dart";
import "../../core/theme/app_theme.dart";

final productsProvider = FutureProvider.family<List<ProductModel>, String?>((ref, search) async {
  debugPrint("[PRODUCTS] Fetching...");
  final params = <String, dynamic>{
    'warehouse_id': 1, // Get stock for warehouse 1
  };
  if (search != null && search.isNotEmpty) {
    params['search'] = search;
  }
  final response = await ApiService.instance.getProducts(params: params);
  final data = response.data;
  debugPrint("[PRODUCTS] Data type: ${data.runtimeType}");

  final List productsList = data is Map ? (data["data"] ?? []) : data;
  debugPrint("[PRODUCTS] Count: ${productsList.length}");

  if (productsList.isNotEmpty) {
    debugPrint("[PRODUCTS] Sample: ${productsList[0]}");
  }

  final result = <ProductModel>[];
  for (var p in productsList) {
    try {
      result.add(ProductModel.fromJson(p));
    } catch (e) {
      debugPrint("[PRODUCTS] ERROR: $e");
      debugPrint("[PRODUCTS] DATA: $p");
    }
  }
  return result;
});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = "";
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(_searchQuery.isEmpty ? null : _searchQuery));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "بحث عن منتج...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        Expanded(
          child: productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("لا يوجد منتجات", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(productsProvider(_searchQuery.isEmpty ? null : _searchQuery));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCard(product: product);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint("[PRODUCTS] UI Error: $error");
              return Center(child: Text("Error: $error"));
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2, color: AppTheme.primaryColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (product.categoryName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.categoryName!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${product.unitPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        "د.ج/قطعة",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                      if (product.piecesPerPackage > 1) ...[
                        const SizedBox(height: 2),
                        Text(
                          "${(product.unitPrice * product.piecesPerPackage).toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                        Text(
                          "د.ج/كرتون",
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (product.piecesPerPackage > 1)
                  Text(
                    '${product.piecesPerPackage} قطعة/${product.unitSaleShortName ?? "وحدة"}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 10,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      product.effectiveStock > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      size: 12,
                      color: product.effectiveStock > 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${product.effectiveStock}",
                      style: TextStyle(
                        fontSize: 12,
                        color: product.effectiveStock > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
