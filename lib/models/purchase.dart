class PurchaseItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final double subtotal;
  final double? costPrice;

  PurchaseItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.costPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
      if (costPrice != null) 'cost_price': costPrice,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['product_id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      costPrice: map['cost_price']?.toDouble(),
    );
  }
}

class Purchase {
  final String? id;
  final String createdBy;
  final String createdByEmail;
  final String customerId;
  final String customerName;
  final List<PurchaseItem> items;
  final DateTime purchaseDate;
  final String status;
  final double totalAmount;

  Purchase({
    this.id,
    required this.createdBy,
    required this.createdByEmail,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.purchaseDate,
    required this.status,
    required this.totalAmount,
  });

  bool get isPaid => status == 'paid';
  double get totalCost => items.fold(0, (sum, item) => sum + ((item.costPrice ?? 0) * item.quantity));
  double get totalProfit => totalAmount - totalCost;

  Map<String, dynamic> toMap() {
    return {
      'created_by': createdBy,
      'created_by_email': createdByEmail,
      'customer_id': customerId,
      'customer_name': customerName,
      'product_data': _serializeItems(),
      'purchase_date': purchaseDate.toIso8601String(),
      'status': status,
      'total_amount': totalAmount,
    };
  }

  String _serializeItems() {
    final itemsList = items.map((item) => item.toMap()).toList();
    return itemsList.toString();
  }

  factory Purchase.fromMap(String id, Map<String, dynamic> map) {
    List<PurchaseItem> items = [];
    final productData = map['product_data'];
    
    if (productData is String) {
      // Parse string representation of list
      try {
        final cleaned = productData.replaceAll('{', '').replaceAll('}', '');
        // Simple parsing for demo
        items = [];
      } catch (e) {
        items = [];
      }
    } else if (productData is List) {
      items = productData.map((item) => PurchaseItem.fromMap(item)).toList();
    }

    return Purchase(
      id: id,
      createdBy: map['created_by'] ?? '',
      createdByEmail: map['created_by_email'] ?? '',
      customerId: map['customer_id'] ?? '',
      customerName: map['customer_name'] ?? '',
      items: items,
      purchaseDate: map['purchase_date'] != null 
          ? DateTime.parse(map['purchase_date']) 
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
    );
  }
}