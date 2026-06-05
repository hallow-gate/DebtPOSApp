import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/purchase.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_provider.dart';
import '../utils/constants.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String? _expandedId;
  bool _editMode = false;
  
  final _editNameController = TextEditingController();
  final _editPhoneController = TextEditingController();
  final _editEmailController = TextEditingController();
  String? _editingCustomerId;

  @override
  void dispose() {
    _searchController.dispose();
    _editNameController.dispose();
    _editPhoneController.dispose();
    _editEmailController.dispose();
    super.dispose();
  }

  void _startEdit(Customer customer) {
    _editingCustomerId = customer.id;
    _editNameController.text = customer.name;
    _editPhoneController.text = customer.phone;
    _editEmailController.text = customer.email;
    setState(() => _editMode = true);
  }

  Future<void> _saveEdit() async {
    if (_editingCustomerId == null) return;
    await Provider.of<CustomerProvider>(context, listen: false).updateCustomer(
      _editingCustomerId!,
      {
        'name': _editNameController.text.trim(),
        'phone': _editPhoneController.text,
        'email': _editEmailController.text,
      },
    );
    setState(() {
      _editMode = false;
      _editingCustomerId = null;
    });
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Customer', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${customer.name}" and all their purchases?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Provider.of<CustomerProvider>(context, listen: false).deleteCustomer(customer.id!);
      if (_expandedId == customer.id) setState(() => _expandedId = null);
    }
  }

  Future<void> _markPurchasePaid(Purchase purchase) async {
    await Provider.of<PurchaseProvider>(context, listen: false).updatePurchase(
      purchase.id!,
      {'status': purchase.status == 'paid' ? 'pending' : 'paid'},
    );
  }

  Future<void> _deletePurchase(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Purchase', style: TextStyle(color: Colors.white)),
        content: const Text('Delete this purchase?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Provider.of<PurchaseProvider>(context, listen: false).deletePurchase(id);
    }
  }

  void _printReport(Customer customer, List<Purchase> purchases) {
    final totalSpent = purchases.fold<double>(0, (sum, p) => sum + p.totalAmount);
    // Simple print - in production use printing package
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Report: ${customer.name}', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone: ${customer.phone.isEmpty ? 'N/A' : customer.phone}', style: TextStyle(color: AppColors.textSecondary)),
              Text('Email: ${customer.email.isEmpty ? 'N/A' : customer.email}', style: TextStyle(color: AppColors.textSecondary)),
              const Divider(color: AppColors.border),
              const Text('Purchase History:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: purchases.length,
                  itemBuilder: (context, i) {
                    final p = purchases[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${p.purchaseDate.month}/${p.purchaseDate.day}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          Expanded(child: Text(p.items.map((item) => '${item.name} ×${item.quantity}').join(', '), style: TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('₱${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontSize: 11)),
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
                  const Text('Total Spent:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('₱${totalSpent.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CustomerProvider, PurchaseProvider>(
      builder: (context, customerProvider, purchaseProvider, _) {
        final filtered = customerProvider.customers.where((c) =>
          c.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          c.phone.contains(_searchController.text)
        ).toList();
        
        return SingleChildScrollView(
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
                      const Text('Customers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${customerProvider.customers.length} registered customers', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              // Search
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search name or phone…',
                  prefixIcon: Icon(Icons.search, size: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              
              // Customer list
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('No customers found', style: TextStyle(color: AppColors.textMuted)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final isExpanded = _expandedId == c.id;
                    final customerPurchases = purchaseProvider.purchases
                        .where((p) => p.customerId == c.id)
                        .toList();
                    final totalSpent = customerPurchases.fold<double>(0, (sum, p) => sum + p.totalAmount);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          // Row
                          InkWell(
                            onTap: () => setState(() => _expandedId = isExpanded ? null : c.id),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.success]),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Text(c.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        Text(c.phone.isNotEmpty ? c.phone : c.email.isNotEmpty ? c.email : 'No contact', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₱${totalSpent.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                      Text('${customerPurchases.length} orders', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 14),
                                ],
                              ),
                            ),
                          ),
                          
                          // Expanded content
                          if (isExpanded && !_editMode)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _startEdit(c),
                                        icon: const Icon(Icons.edit, size: 12),
                                        label: const Text('Edit'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary.withOpacity(0.15),
                                          foregroundColor: AppColors.primary,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _printReport(c, customerPurchases),
                                        icon: const Icon(Icons.print, size: 12),
                                        label: const Text('Report'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.info.withOpacity(0.15),
                                          foregroundColor: AppColors.info,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _deleteCustomer(c),
                                        icon: const Icon(Icons.delete, size: 12),
                                        label: const Text('Delete'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.danger.withOpacity(0.15),
                                          foregroundColor: AppColors.danger,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Purchase History', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(height: 8),
                                  if (customerPurchases.isEmpty)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Text('No purchases yet.', style: TextStyle(color: AppColors.textMuted)),
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: customerPurchases.length,
                                      itemBuilder: (context, i) {
                                        final p = customerPurchases[i];
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.cardBackground,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${p.purchaseDate.month}/${p.purchaseDate.day}/${p.purchaseDate.year} ${p.purchaseDate.hour}:${p.purchaseDate.minute.toString().padLeft(2, '0')}',
                                                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        p.items.map((item) => '${item.name} ×${item.quantity}').join(', '),
                                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text('₱${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                                      const SizedBox(height: 4),
                                                      _StatusBadge(status: p.status),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  TextButton(
                                                    onPressed: () => _markPurchasePaid(p),
                                                    style: TextButton.styleFrom(
                                                      backgroundColor: p.isPaid ? AppColors.warning.withOpacity(0.15) : AppColors.success.withOpacity(0.15),
                                                      foregroundColor: p.isPaid ? AppColors.warning : AppColors.success,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    ),
                                                    child: Text(p.isPaid ? 'Mark Pending' : 'Mark Paid'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    onPressed: () => _deletePurchase(p.id!),
                                                    icon: const Icon(Icons.delete_outline, size: 16),
                                                    color: AppColors.danger,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  if (customerPurchases.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Total Spent', style: TextStyle(color: AppColors.textMuted)),
                                          Text('₱${totalSpent.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          
                          // Edit mode
                          if (isExpanded && _editMode && _editingCustomerId == c.id)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  const Text('Edit Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _editNameController,
                                    decoration: const InputDecoration(labelText: 'Name'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _editPhoneController,
                                    decoration: const InputDecoration(labelText: 'Phone'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _editEmailController,
                                    decoration: const InputDecoration(labelText: 'Email'),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _saveEdit,
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                          child: const Text('Save'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => setState(() => _editMode = false),
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? AppColors.success.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPaid ? Icons.check_circle : Icons.schedule, size: 10, color: isPaid ? AppColors.success : AppColors.warning),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(color: isPaid ? AppColors.success : AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}