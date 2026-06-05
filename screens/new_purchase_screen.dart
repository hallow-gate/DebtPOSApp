import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/purchase.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_provider.dart';
import '../widgets/barcode_scanner.dart';
import '../widgets/receipt_dialog.dart';
import '../utils/constants.dart';

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  // Customer fields
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  Customer? _selectedCustomer;
  List<Customer> _customerSuggestions = [];
  
  // Product fields
  final _productSearchController = TextEditingController();
  Product? _selectedProduct;
  List<Product> _productSuggestions = [];
  final _quantityController = TextEditingController(text: '1');
  
  // Cart
  List<CartItem> _cart = [];
  
  // UI state
  bool _scannerOpen = false;
  bool _finalizing = false;
  String _toast = '';
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_validateQuantity);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _productSearchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _validateQuantity() {
    final qty = int.tryParse(_quantityController.text);
    if (qty != null && qty < 1) {
      _quantityController.text = '1';
    }
  }

  void _updateCustomerSuggestions(String query) {
    if (_selectedCustomer != null) return;
    if (query.isEmpty) {
      setState(() => _customerSuggestions = []);
      return;
    }
    final customers = Provider.of<CustomerProvider>(context, listen: false).customers;
    setState(() {
      _customerSuggestions = customers.where((c) =>
        c.name.toLowerCase().contains(query.toLowerCase()) ||
        c.phone.contains(query)
      ).take(6).toList();
    });
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _customerPhoneController.text = customer.phone;
      _customerEmailController.text = customer.email;
      _customerSuggestions = [];
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerEmailController.clear();
    });
  }

  void _updateProductSuggestions(String query) {
    if (_selectedProduct != null) return;
    if (query.isEmpty) {
      setState(() => _productSuggestions = []);
      return;
    }
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    setState(() {
      _productSuggestions = products.where((p) =>
        p.name.toLowerCase().contains(query.toLowerCase()) ||
        p.productCode.toLowerCase().contains(query.toLowerCase())
      ).take(8).toList();
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _productSearchController.text = product.name;
      _productSuggestions = [];
    });
  }

  void _handleBarcodeScan(String code) {
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    final found = products.firstWhere(
      (p) => p.productCode.toLowerCase() == code.toLowerCase(),
      orElse: () => null,
    );
    if (found != null) {
      _selectProduct(found);
      _showToast('Product found: ${found.name}');
    } else {
      _showToast('No product found for barcode: "$code"');
    }
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  void _addToCart() {
    if (_selectedProduct == null) {
      _showToast('Please select a product');
      return;
    }
    
    final qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty < 1) {
      _showToast('Quantity must be at least 1');
      return;
    }
    if (qty > _selectedProduct!.stock) {
      _showToast('Only ${_selectedProduct!.stock} units available');
      return;
    }
    
    final existingIndex = _cart.indexWhere((item) => item.productId == _selectedProduct!.id);
    
    if (existingIndex != -1) {
      final newQty = _cart[existingIndex].quantity + qty;
      if (newQty > _selectedProduct!.stock) {
        _showToast('Only ${_selectedProduct!.stock} units available');
        return;
      }
      setState(() {
        _cart[existingIndex] = _cart[existingIndex].copyWith(
          quantity: newQty,
          subtotal: _cart[existingIndex].price * newQty,
        );
      });
    } else {
      setState(() {
        _cart.add(CartItem(
          productId: _selectedProduct!.id!,
          name: _selectedProduct!.name,
          price: _selectedProduct!.retailPrice,
          quantity: qty,
          subtotal: _selectedProduct!.retailPrice * qty,
          costPrice: _selectedProduct!.costPrice,
        ));
      });
    }
    
    _selectedProduct = null;
    _productSearchController.clear();
    _quantityController.text = '1';
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateCartQuantity(int index, int newQty) {
    if (newQty < 1) return;
    final item = _cart[index];
    final product = Provider.of<ProductProvider>(context, listen: false)
        .products.firstWhere((p) => p.id == item.productId);
    if (newQty > product.stock) {
      _showToast('Only ${product.stock} in stock');
      return;
    }
    setState(() {
      _cart[index] = item.copyWith(
        quantity: newQty,
        subtotal: item.price * newQty,
      );
    });
  }

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.subtotal);
  int get _totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  Future<void> _finalizePurchase() async {
    if (_cart.isEmpty) {
      _showToast('Cart is empty');
      return;
    }
    if (_customerNameController.text.trim().isEmpty) {
      _showToast('Customer name is required');
      return;
    }
    
    setState(() => _finalizing = true);
    
    try {
      Customer customer = _selectedCustomer!;
      if (customer == null) {
        final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
        customer = await customerProvider.addCustomer(Customer(
          name: _customerNameController.text.trim(),
          phone: _customerPhoneController.text,
          email: _customerEmailController.text,
        ));
      }
      
      final purchaseItems = _cart.map((item) => PurchaseItem(
        productId: item.productId,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        subtotal: item.subtotal,
        costPrice: item.costPrice,
      )).toList();
      
      final purchase = Purchase(
        createdBy: _auth.currentUser?.uid ?? 'unknown',
        createdByEmail: _auth.currentUser?.email ?? 'unknown',
        customerId: customer.id!,
        customerName: customer.name,
        items: purchaseItems,
        purchaseDate: DateTime.now(),
        status: 'pending',
        totalAmount: _cartTotal,
      );
      
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      await purchaseProvider.addPurchase(purchase);
      
      // Update stock
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      for (final item in _cart) {
        final product = productProvider.products.firstWhere((p) => p.id == item.productId);
        await productProvider.updateProduct(item.productId, {
          'stock': product.stock - item.quantity,
        });
      }
      
      // Show receipt
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ReceiptDialog(purchase: purchase),
      );
      
      // Reset form
      setState(() {
        _cart = [];
        _customerNameController.clear();
        _customerPhoneController.clear();
        _customerEmailController.clear();
        _selectedCustomer = null;
        _selectedProduct = null;
        _productSearchController.clear();
      });
    } catch (e) {
      _showToast('Failed: ${e.toString()}');
    } finally {
      setState(() => _finalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    
    return Consumer2<ProductProvider, CustomerProvider>(
      builder: (context, productProvider, customerProvider, _) {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isMobile
                  ? Column(children: [_buildCustomerSection(), const SizedBox(height: 12), _buildProductSection(), const SizedBox(height: 12), _buildCartSection()])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(children: [_buildCustomerSection(), const SizedBox(height: 12), _buildProductSection()])),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCartSection()),
                    ]),
            ),
            
            // Toast
            if (_toast.isNotEmpty)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
                    ),
                    child: Text(_toast, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ),
            
            // Barcode Scanner Modal
            if (_scannerOpen)
              BarcodeScannerModal(
                onDetected: _handleBarcodeScan,
                onClose: () => setState(() => _scannerOpen = false),
                title: 'Scan Product Barcode',
              ),
          ],
        );
      },
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          
          // Name with autocomplete
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Name *', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Stack(
                children: [
                  TextField(
                    controller: _customerNameController,
                    onChanged: (value) {
                      if (_selectedCustomer != null) _clearCustomer();
                      _updateCustomerSuggestions(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search or type new name…',
                      suffixIcon: _selectedCustomer != null
                          ? IconButton(onPressed: _clearCustomer, icon: const Icon(Icons.close, size: 13))
                          : null,
                    ),
                  ),
                ],
              ),
              if (_customerSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: _customerSuggestions.map((c) => ListTile(
                      title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: c.phone.isNotEmpty ? Text(c.phone, style: TextStyle(color: AppColors.textMuted, fontSize: 11)) : null,
                      dense: true,
                      onTap: () => _selectCustomer(c),
                    )).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Phone and Email
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phone', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _customerPhoneController,
                      decoration: const InputDecoration(hintText: 'Optional'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _customerEmailController,
                      decoration: const InputDecoration(hintText: 'Optional'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          
          // Product search with barcode button
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search by name or barcode', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _productSearchController,
                      onChanged: (value) {
                        if (_selectedProduct != null) setState(() => _selectedProduct = null);
                        _updateProductSuggestions(value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Product name or code…',
                        prefixIcon: Icon(Icons.search, size: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _scannerOpen = true),
                    icon: const Icon(Icons.qr_code_scanner),
                    color: AppColors.primary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              if (_productSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: _productSuggestions.map((p) => ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(p.productCode, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text('₱${p.retailPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      subtitle: Text('Stock: ${p.stock}', style: TextStyle(color: p.stock == 0 ? AppColors.danger : AppColors.textMuted)),
                      onTap: () => _selectProduct(p),
                    )).toList(),
                  ),
                ),
            ],
          ),
          
          // Selected product preview
          if (_selectedProduct != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedProduct!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('₱${_selectedProduct!.retailPrice.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  Text('Stock: ${_selectedProduct!.stock}', style: TextStyle(color: _selectedProduct!.stock == 0 ? AppColors.danger : AppColors.success)),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 10),
          
          // Quantity and Add button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantity', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '1'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (_totalItems > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$_totalItems', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _cart.clear()),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_cart.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 40, color: AppColors.textMuted),
                    SizedBox(height: 10),
                    Text('Cart is empty', style: TextStyle(color: AppColors.textMuted)),
                    SizedBox(height: 5),
                    Text('Scan a barcode or search above', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _cart.length,
                itemBuilder: (context, index) {
                  final item = _cart[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2),
                              Text('₱${item.price.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: item.quantity.toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onFieldSubmitted: (value) {
                              final qty = int.tryParse(value) ?? 1;
                              _updateCartQuantity(index, qty);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₱${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeFromCart(index),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: AppColors.danger,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const Divider(color: AppColors.border),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '₱${_cartTotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finalizing ? null : _finalizePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: _finalizing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 17),
                          SizedBox(width: 8),
                          Text('Finalize Purchase'),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardBackground,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    );
  }
}

class CartItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final double subtotal;
  final double? costPrice;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.costPrice,
  });

  CartItem copyWith({
    String? productId,
    String? name,
    double? price,
    int? quantity,
    double? subtotal,
    double? costPrice,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}