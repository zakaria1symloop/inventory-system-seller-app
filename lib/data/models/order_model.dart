double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    // Handle decimal strings like "2.00"
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed.toInt();
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

class OrderModel {
  final int? id;
  final String? reference;
  final int? tripId;
  final int clientId;
  final int sellerId;
  final int warehouseId;
  final String date;
  final double totalAmount;
  final double discount;
  final double tax;
  final double grandTotal;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? notes;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final String? warehouseName;
  final List<OrderItemModel> items;
  final bool isSynced;
  final String? localId;

  OrderModel({
    this.id,
    this.reference,
    this.tripId,
    required this.clientId,
    required this.sellerId,
    required this.warehouseId,
    required this.date,
    required this.totalAmount,
    this.discount = 0,
    this.tax = 0,
    required this.grandTotal,
    this.status = "pending",
    this.paymentStatus = "unpaid",
    this.paymentMethod,
    this.notes,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    this.warehouseName,
    this.items = const [],
    this.isSynced = false,
    this.localId,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json["id"] != null ? _toInt(json["id"]) : null,
      reference: json["reference"]?.toString(),
      tripId: json["trip_id"] != null ? _toInt(json["trip_id"]) : null,
      clientId: _toInt(json["client_id"]),
      sellerId: _toInt(json["seller_id"]),
      warehouseId: _toInt(json["warehouse_id"]),
      date: json["date"]?.toString() ?? "",
      totalAmount: _toDouble(json["total_amount"]),
      discount: _toDouble(json["discount"]),
      tax: _toDouble(json["tax"]),
      grandTotal: _toDouble(json["grand_total"]),
      status: json["status"]?.toString() ?? "pending",
      paymentStatus: json["payment_status"]?.toString() ?? "unpaid",
      paymentMethod: json["payment_method"]?.toString(),
      notes: json["notes"]?.toString(),
      clientName: json["client"]?["name"]?.toString(),
      clientPhone: json["client"]?["phone"]?.toString(),
      clientAddress: json["client"]?["address"]?.toString(),
      warehouseName: json["warehouse"]?["name"]?.toString(),
      items: json["items"] != null
          ? (json["items"] as List).map((e) => OrderItemModel.fromJson(e)).toList()
          : [],
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "trip_id": tripId,
      "client_id": clientId,
      "warehouse_id": warehouseId,
      "date": date,
      "discount": discount,
      "tax": tax,
      "payment_method": paymentMethod,
      "notes": notes,
      "items": items.map((e) => e.toJson()).toList(),
    };
  }
}

class OrderItemModel {
  final int? id;
  final int productId;
  final int quantityOrdered;
  final double unitPrice;
  final double discount;
  final double subtotal;
  final String? notes;
  final String? productName;
  final int piecesPerPackage;

  OrderItemModel({
    this.id,
    required this.productId,
    required this.quantityOrdered,
    required this.unitPrice,
    this.discount = 0,
    required this.subtotal,
    this.notes,
    this.productName,
    this.piecesPerPackage = 1,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json["id"] != null ? _toInt(json["id"]) : null,
      productId: _toInt(json["product_id"]),
      quantityOrdered: _toInt(json["quantity_ordered"] ?? json["quantity"]),
      unitPrice: _toDouble(json["unit_price"]),
      discount: _toDouble(json["discount"]),
      subtotal: _toDouble(json["subtotal"]),
      notes: json["notes"]?.toString(),
      productName: json["product"]?["name"]?.toString(),
      piecesPerPackage: _toInt(json["product"]?["pieces_per_package"] ?? 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "product_id": productId,
      "quantity": quantityOrdered,
      "unit_price": unitPrice,
      "discount": discount,
    };
  }
}
