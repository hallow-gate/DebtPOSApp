class Product {
  final String? id;
  final String productCode;
  final String name;
  final double costPrice;
  final double retailPrice;
  final double price;
  final int stock;
  final int lowStockThreshold;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    this.id,
    required this.productCode,
    required this.name,
    required this.costPrice,
    required this.retailPrice,
    required this.price,
    required this.stock,
    required this.lowStockThreshold,
    required this.category,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stock <= lowStockThreshold;
  bool get isOutOfStock => stock == 0;
  double get profit => retailPrice - costPrice;
  double get profitMargin => retailPrice > 0 ? (profit / retailPrice) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'productCode': productCode,
      'name': name,
      'costPrice': costPrice,
      'retailPrice': retailPrice,
      'price': price,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'category': category,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      productCode: map['productCode'] ?? '',
      name: map['name'] ?? '',
      costPrice: (map['costPrice'] ?? 0).toDouble(),
      retailPrice: (map['retailPrice'] ?? map['price'] ?? 0).toDouble(),
      price: (map['price'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      lowStockThreshold: map['lowStockThreshold'] ?? 5,
      category: map['category'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  Product copyWith({
    String? id,
    String? productCode,
    String? name,
    double? costPrice,
    double? retailPrice,
    double? price,
    int? stock,
    int? lowStockThreshold,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      costPrice: costPrice ?? this.costPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}