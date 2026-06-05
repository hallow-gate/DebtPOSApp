import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_provider.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    final lastSync = LocalStorageService.getLastSync();
    if (lastSync != null && mounted) {
      setState(() => _syncStatus = 'Last sync: ${_formatDate(lastSync)}');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing...';
    });
    
    try {
      await _syncService.syncAllData();
      
      // Refresh providers
      await Future.wait([
        Provider.of<ProductProvider>(context, listen: false).refresh(),
        Provider.of<CustomerProvider>(context, listen: false).refresh(),
        Provider.of<PurchaseProvider>(context, listen: false).refresh(),
      ]);
      
      setState(() => _syncStatus = 'Sync completed!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data synced successfully'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      setState(() => _syncStatus = 'Sync failed: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      setState(() => _isSyncing = false);
      _checkSyncStatus();
    }
  }

  Future<void> _exportData() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    
    final data = {
      'products': productProvider.products.map((p) => p.toMap()).toList(),
      'customers': customerProvider.customers.map((c) => c.toMap()).toList(),
      'purchases': purchaseProvider.purchases.map((p) => p.toMap()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    
    await Share.shareXFiles(
      [ShareXFile.fromData(Uint8List.fromList(utf8.encode(jsonString)), mimeType: 'application/json', name: 'marnie_pos_$date.json')],
      text: 'Marnie POS Data Export',
    );
  }

  void _importData() async {
    // For import, we'll show a dialog explaining how to import
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Import Data', style: TextStyle(color: Colors.white)),
        content: const Text(
          'To import data, place a JSON file in the app storage directory.\n\n'
          'Format: {"products": [...], "customers": [...], "purchases": [...]}\n\n'
          'Note: Import manually via Firebase Console for production use.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProductProvider, CustomerProvider, PurchaseProvider>(
      builder: (context, productProvider, customerProvider, purchaseProvider, _) {
        final totalSales = purchaseProvider.purchases.fold<double>(0, (sum, p) => sum + p.totalAmount);
        final paidSales = purchaseProvider.purchases
            .where((p) => p.isPaid)
            .fold<double>(0, (sum, p) => sum + p.totalAmount);
        final totalProfit = purchaseProvider.purchases.fold<double>(0, (sum, p) => sum + p.totalProfit);
        final profitMargin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0;
        final pendingCount = purchaseProvider.purchases.where((p) => !p.isPaid).length;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;
              
              if (isMobile) {
                return Column(
                  children: [
                    _buildDataManagementCard(),
                    const SizedBox(height: 16),
                    _buildAccountCard(),
                    const SizedBox(height: 16),
                    _buildFinancialCard(totalSales, paidSales, totalProfit, profitMargin, purchaseProvider.purchases.length, pendingCount),
                  ],
                );
              }
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildDataManagementCard(),
                  _buildAccountCard(),
                  _buildFinancialCard(totalSales, paidSales, totalProfit, profitMargin, purchaseProvider.purchases.length, pendingCount),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDataManagementCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Data Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Sync your data with Firebase or export as JSON backup.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          
          // Sync status
          if (_syncStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_syncStatus, style: TextStyle(color: AppColors.info, fontSize: 12)),
            ),
          
          // Sync button
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _syncNow,
            icon: _isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, size: 15),
            label: Text(_isSyncing ? 'Syncing...' : 'Sync with Firebase'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.15),
              foregroundColor: AppColors.primary,
              elevation: 0,
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 8),
          
          // Export button
          OutlinedButton.icon(
            onPressed: _exportData,
            icon: const Icon(Icons.download, size: 15),
            label: const Text('Export JSON Backup'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: BorderSide(color: AppColors.success.withOpacity(0.3)),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 8),
          
          // Import button
          OutlinedButton.icon(
            onPressed: _importData,
            icon: const Icon(Icons.upload, size: 15),
            label: const Text('Import / Inspect JSON'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle, size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Account & System', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('System', 'Marnie Store POS v2.1'),
              _infoRow('Database', 'Firebase Firestore + Hive'),
              _infoRow('Logged in as', authProvider.user?.email ?? 'Unknown', color: AppColors.primary),
              _infoRow('Status', '● Connected', color: AppColors.success),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: authProvider.logout,
                  icon: const Icon(Icons.logout, size: 15),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger.withOpacity(0.15),
                    foregroundColor: AppColors.danger,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialCard(double totalSales, double paidSales, double totalProfit, double profitMargin, int totalOrders, int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 15, color: AppColors.success),
              const SizedBox(width: 8),
              const Text('Financial Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _summaryItem('Total Revenue', '₱${totalSales.toStringAsFixed(2)}', AppColors.primary),
              _summaryItem('Paid Revenue', '₱${paidSales.toStringAsFixed(2)}', AppColors.success),
              _summaryItem('Total Profit', '₱${totalProfit.toStringAsFixed(2)}', AppColors.success),
              _summaryItem('Profit Margin', '${profitMargin.toStringAsFixed(1)}%', AppColors.warning),
              _summaryItem('Total Orders', totalOrders.toString(), AppColors.info),
              _summaryItem('Pending Orders', pendingCount.toString(), AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
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