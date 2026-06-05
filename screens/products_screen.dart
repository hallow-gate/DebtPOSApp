import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../widgets/barcode_scanner.dart';
import '../utils/constants.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  
  Product? _editingProduct;
  bool _showForm = false;
  bool _isSaving = false;
  String _error = '';
  
  // Form controllers
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _retailPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _categoryController = TextEditingController();
  
  bool _scannerOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _costPriceController.dispose();
    _retailPriceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _codeController.clear();
    _nameController.clear();
    _costPriceController.clear();
    _retailPriceController.clear();
    _stockController.clear();
    _thresholdController.text = '5';
    _categoryController.clear();
    _editingProduct = null;
    _error = '';
  }

  void _startEdit(Product product) {
    _editingProduct = product;
    _codeController.text = product.productCode;
    _nameController.text = product.name;
    _costPriceController.text = product.costPrice.toString();
    _retailPriceController.text = product.retailPrice.toString();
    _stockController.text = product.stock.toString();
    _thresholdController.text = product.lowStockThreshold.toString();
    _categoryController.text = product.category;
    _showForm = true;
    _error = '';
    setState(() {});
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    final costPrice = double.tryParse(_costPriceController.text) ?? 0;
    final retailPrice = double.tryParse(_retailPriceController.text) ?? 0;
    
    if (retailPrice < costPrice) {
      setState(() => _error = 'Retail price must be ≥ cost price');
      return;
    }
    
    setState(() {
      _isSaving = true;
      _error = '';
    });
    
    try {
      final product = Product(
        id: _editingProduct?.id,
        productCode: _codeController.text.trim(),
        name: _nameController.text.trim(),
        costPrice: costPrice,
        retailPrice: retailPrice,
        price: retailPrice,
        stock: int.tryParse(_stockController.text) ?? 0,
        lowStockThreshold: int.tryParse(_thresholdController.text) ?? 5,
        category: _categoryController.text.trim(),
      );
      
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      if (_editingProduct != null) {
        await productProvider.updateProduct(_editingProduct!.id!, product.toMap());
      } else {
        await productProvider.addProduct(product);
      }
      
      _resetForm();
      _showForm = false;
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _handleBarcodeScan(String code) {
    _codeController.text = code;
    setState(() => _scannerOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final filteredProducts = productProvider.products.where((p) =>
          p.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          p.productCode.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchController.text.toLowerCase())
        ).toList();
        
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Products',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${productProvider.products.length} items in inventory',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _resetForm();
                          setState(() => _showForm = !_showForm);
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Form
                  if (_showForm) _buildForm(),
                  
                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, code, or category…',
                      prefixIcon: const Icon(Icons.search, size: 14, color: AppColors.textMuted),
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  
                  // Products grid
                  if (filteredProducts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('No products found', style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = filteredProducts[index];
                        final isLow = p.isLowStock;
                        final isOut = p.isOutOfStock;
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            border: Border.all(
                              color: isOut ? AppColors.danger.withOpacity(0.3) : 
                                     isLow ? AppColors.warning.withOpacity(0.2) : 
                                     AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.productCode}${p.category.isNotEmpty ? ' · ${p.category}' : ''}',
                                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _startEdit(p),
                                          icon: const Icon(Icons.edit, size: 13),
                                          color: AppColors.primary,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.primary.withOpacity(0.15),
                                            padding: const EdgeInsets.all(5),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        IconButton(
                                          onPressed: () => _confirmDelete(p),
                                          icon: const Icon(Icons.delete, size: 13),
                                          color: AppColors.danger,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.danger.withOpacity(0.15),
                                            padding: const EdgeInsets.all(5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Retail', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                        Text('₱${p.retailPrice.toStringAsFixed(2)}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Cost', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                        Text('₱${p.costPrice.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Stock', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isOut ? AppColors.danger.withOpacity(0.2) : 
                                                   isLow ? AppColors.warning.withOpacity(0.2) : 
                                                   AppColors.success.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${p.stock}',
                                            style: TextStyle(
                                              color: isOut ? AppColors.danger : isLow ? AppColors.warning : AppColors.success,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                      },
                    ),
                ],
              ),
            ),
            
            // Barcode Scanner Modal
            if (_scannerOpen)
              BarcodeScannerModal(
                onDetected: _handleBarcodeScan,
                onClose: () => setState(() => _scannerOpen = false),
                title: 'Scan Product Code',
              ),
          ],
        );
      },
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _editingProduct != null ? 'Edit Product' : 'New Product',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  onPressed: () {
                    _resetForm();
                    setState(() => _showForm = false);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.textMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
              childAspectRatio: 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                // Product Code
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Product Code *',
                    hintText: 'e.g. PRD-001',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _scannerOpen = true),
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                // Cost Price
                TextFormField(
                  controller: _costPriceController,
                  decoration: const InputDecoration(labelText: 'Cost Price *', prefixText: '₱ '),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                // Retail Price
                TextFormField(
                  controller: _retailPriceController,
                  decoration: const InputDecoration(labelText: 'Retail Price *', prefixText: '₱ '),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                // Stock
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: 'Stock', hintText: '0'),
                  keyboardType: TextInputType.number,
                ),
                // Low Stock Threshold
                TextFormField(
                  controller: _thresholdController,
                  decoration: const InputDecoration(labelText: 'Low-stock Alert', hintText: '5'),
                  keyboardType: TextInputType.number,
                ),
                // Category
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Beverages'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_editingProduct != null ? 'Save Changes' : 'Add Product'),
                  ),
                ),
                if (_editingProduct != null) ...[
                  const SizedBox(width: 9),
                  OutlinedButton(
                    onPressed: () {
                      _resetForm();
                      setState(() => _showForm = false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                      side: BorderSide.none,
                      backgroundColor: AppColors.surfaceLight,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Product', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${product.name}"?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.id!);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}