double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _toDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    // Handle decimal strings like "100.00"
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
  }
  return 0;
}

Map<int, double> _parseCategoryPrices(dynamic value) {
  if (value == null || value is! List) return {};
  final Map<int, double> result = {};
  for (final item in value) {
    if (item is Map) {
      final catId = item["client_category_id"];
      final price = item["price"];
      if (catId != null && price != null) {
        result[_toInt(catId)] = _toDouble(price);
      }
    }
  }
  return result;
}

class ProductModel {
  final int id;
  final String name;
  final int categoryId;
  final int? brandId;
  final int unitBuyId;
  final int unitSaleId;
  final String? barcode;
  final String? description;
  final double costPrice;
  final double retailPrice;
  final double wholesalePrice;
  final double? minSellingPrice;
  final int? stockAlert;
  final String? image;
  final bool isActive;
  final String? categoryName;
  final String? brandName;
  final String? unitBuyName;
  final String? unitSaleName;
  final String? unitSaleShortName;
  final int piecesPerPackage;
  final Map<int, double> categoryPrices;
  int? currentStock;
  int? availableStock;

  // Get the effective stock to use (available stock takes priority over current stock)
  int get effectiveStock => availableStock ?? currentStock ?? 0;

  // Get price per unit (carton/box) - retailPrice is already per unit
  double get unitPrice => retailPrice;

  // Get min selling price per unit
  double get minUnitPrice => minSellingPrice ?? retailPrice;

  // Get price for a specific client category
  double getPriceForCategory(int? categoryId) {
    if (categoryId != null && categoryPrices.containsKey(categoryId)) {
      return categoryPrices[categoryId]!;
    }
    return wholesalePrice > 0 ? wholesalePrice : retailPrice;
  }

  ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.brandId,
    required this.unitBuyId,
    required this.unitSaleId,
    this.barcode,
    this.description,
    required this.costPrice,
    required this.retailPrice,
    required this.wholesalePrice,
    this.minSellingPrice,
    this.stockAlert,
    this.image,
    required this.isActive,
    this.categoryName,
    this.brandName,
    this.unitBuyName,
    this.unitSaleName,
    this.unitSaleShortName,
    this.piecesPerPackage = 1,
    this.categoryPrices = const {},
    this.currentStock,
    this.availableStock,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: _toInt(json["id"]),
      name: json["name"]?.toString() ?? "",
      categoryId: _toInt(json["category_id"]),
      brandId: json["brand_id"] != null ? _toInt(json["brand_id"]) : null,
      unitBuyId: _toInt(json["unit_buy_id"]),
      unitSaleId: _toInt(json["unit_sale_id"]),
      barcode: json["barcode"]?.toString(),
      description: json["description"]?.toString(),
      costPrice: _toDouble(json["cost_price"]),
      retailPrice: _toDouble(json["retail_price"]),
      wholesalePrice: _toDouble(json["wholesale_price"]),
      minSellingPrice: _toDoubleNullable(json["min_selling_price"]),
      stockAlert: json["stock_alert"] != null ? _toInt(json["stock_alert"]) : null,
      image: json["image"]?.toString(),
      isActive: json["is_active"] ?? true,
      categoryName: json["category"]?["name"]?.toString(),
      brandName: json["brand"]?["name"]?.toString(),
      unitBuyName: json["unit_buy"]?["name"]?.toString(),
      unitSaleName: json["unit_sale"]?["name"]?.toString(),
      unitSaleShortName: json["unit_sale"]?["short_name"]?.toString(),
      piecesPerPackage: _toInt(json["pieces_per_package"]) > 0 ? _toInt(json["pieces_per_package"]) : 1,
      categoryPrices: _parseCategoryPrices(json["category_prices"]),
      currentStock: json["current_stock"] != null ? _toInt(json["current_stock"]) : null,
      availableStock: json["available_stock"] != null ? _toInt(json["available_stock"]) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "category_id": categoryId,
      "brand_id": brandId,
      "unit_buy_id": unitBuyId,
      "unit_sale_id": unitSaleId,
      "barcode": barcode,
      "description": description,
      "cost_price": costPrice,
      "retail_price": retailPrice,
      "wholesale_price": wholesalePrice,
      "min_selling_price": minSellingPrice,
      "stock_alert": stockAlert,
      "image": image,
      "is_active": isActive,
    };
  }
}
