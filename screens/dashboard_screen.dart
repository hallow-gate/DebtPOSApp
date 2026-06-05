import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/constants.dart';
import 'products_screen.dart';
import 'new_purchase_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isMobile = false;

  final List<Widget> _screens = [
    const DashboardHomeScreen(),
    const ProductsScreen(),
    const NewPurchaseScreen(),
    const CustomersScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Products',
    'New Purchase',
    'Customers',
    'Settings',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMobile = MediaQuery.of(context).size.width < 640;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isMobile ? null : _buildDesktopAppBar(),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _isMobile ? BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ) : null,
    );
  }

  PreferredSizeWidget? _buildDesktopAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.success]),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const Icon(Icons.shopping_cart, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Marnie Store'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('● LIVE', style: TextStyle(fontSize: 10, color: AppColors.success)),
          ),
        ],
      ),
      actions: [
        Text(
          _getFormattedDate(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return Text(
              authProvider.user?.email ?? '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            );
          },
        ),
        const SizedBox(width: 12),
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return TextButton(
              onPressed: authProvider.logout,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.danger.withOpacity(0.15),
                foregroundColor: AppColors.danger,
              ),
              child: const Text('Logout'),
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening with your business today.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Consumer3<ProductProvider, CustomerProvider, PurchaseProvider>(
            builder: (context, productProvider, customerProvider, purchaseProvider, _) {
              final stats = _calculateStats(
                productProvider.products,
                customerProvider.customers,
                purchaseProvider.purchases,
              );
              return Column(
                children: [
                  _buildStatsGrid(stats),
                  const SizedBox(height: 20),
                  _buildTwoColumnLayout(stats, productProvider, customerProvider, purchaseProvider),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List products, List customers, List purchases) {
    final totalSales = purchases.fold<double>(0, (sum, p) => sum + (p.totalAmount ?? 0));
    
    double totalCost = 0;
    int totalItemsSold = 0;
    
    for (final purchase in purchases) {
      for (final item in purchase.items) {
        totalCost += (item.costPrice ?? 0) * item.quantity;
        totalItemsSold += item.quantity;
      }
    }
    
    final totalProfit = totalSales - totalCost;
    final profitMargin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0;
    
    final pendingPayments = purchases.where((p) => p.status != 'paid').length;
    final pendingAmount = purchases
        .where((p) => p.status != 'paid')
        .fold<double>(0, (sum, p) => sum + (p.totalAmount ?? 0));
    
    final paidCount = purchases.where((p) => p.status == 'paid').length;
    final avgOrderValue = purchases.isNotEmpty ? totalSales / purchases.length : 0;
    
    final lowStockProducts = products.where((p) => p.isLowStock).toList();
    
    return {
      'totalSales': totalSales,
      'totalProfit': totalProfit,
      'profitMargin': profitMargin,
      'pendingAmount': pendingAmount,
      'pendingPayments': pendingPayments,
      'paidCount': paidCount,
      'avgOrderValue': avgOrderValue,
      'totalItemsSold': totalItemsSold,
      'totalOrders': purchases.length,
      'totalCustomers': customers.length,
      'totalProducts': products.length,
      'lowStockCount': lowStockProducts.length,
      'lowStockProducts': lowStockProducts,
      'recentTransactions': purchases.take(10).toList(),
    };
  }

  Widget _buildStatsGrid(Map stats) {
    final quickStats = [
      {'label': 'Total Revenue', 'value': '₱${(stats['totalSales'] ?? 0).toStringAsFixed(2)}', 'icon': Icons.attach_money, 'color': AppColors.primary},
      {'label': 'Total Profit', 'value': '₱${(stats['totalProfit'] ?? 0).toStringAsFixed(2)}', 'icon': Icons.trending_up, 'color': AppColors.success},
      {'label': 'Avg Order', 'value': '₱${(stats['avgOrderValue'] ?? 0).toStringAsFixed(2)}', 'icon': Icons.credit_card, 'color': AppColors.info},
      {'label': 'Pending', 'value': '₱${(stats['pendingAmount'] ?? 0).toStringAsFixed(2)}', 'icon': Icons.schedule, 'color': AppColors.warning},
    ];
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: quickStats.map((stat) => _StatCard(
        label: stat['label'] as String,
        value: stat['value'] as String,
        icon: stat['icon'] as IconData,
        color: stat['color'] as Color,
      )).toList(),
    );
  }

  Widget _buildTwoColumnLayout(Map stats, ProductProvider productProvider, CustomerProvider customerProvider, PurchaseProvider purchaseProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              _RecentTransactionsTable(
                transactions: stats['recentTransactions'],
                customers: customerProvider.customers,
              ),
              const SizedBox(height: 16),
              _LowStockAlerts(lowStockProducts: stats['lowStockProducts']),
              const SizedBox(height: 16),
              _PerformanceSummary(stats: stats),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _RecentTransactionsTable(
                transactions: stats['recentTransactions'],
                customers: customerProvider.customers,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _LowStockAlerts(lowStockProducts: stats['lowStockProducts']),
                  const SizedBox(height: 16),
                  _PerformanceSummary(stats: stats),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsTable extends StatelessWidget {
  final List transactions;
  final List customers;

  const _RecentTransactionsTable({
    required this.transactions,
    required this.customers,
  });

  String _getCustomerName(String? customerId) {
    final customer = customers.firstWhere(
      (c) => c.id == customerId,
      orElse: () => null,
    );
    return customer?.name ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Recent Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('Last ${transactions.length} orders', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart, size: 40, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('No transactions yet', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Customer', style: TextStyle(color: AppColors.textMuted))),
                  DataColumn(label: Text('Amount', style: TextStyle(color: AppColors.textMuted))),
                  DataColumn(label: Text('Date', style: TextStyle(color: AppColors.textMuted))),
                  DataColumn(label: Text('Status', style: TextStyle(color: AppColors.textMuted))),
                ],
                rows: transactions.map<DataRow>((t) {
                  return DataRow(
                    cells: [
                      DataCell(Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.success]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(_getCustomerName(t.customerId), style: const TextStyle(color: Colors.white)),
                        ],
                      )),
                      DataCell(Text('₱${t.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
                      DataCell(Text(_formatDate(t.purchaseDate), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                      DataCell(_StatusBadge(status: t.status)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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
          Text(
            status,
            style: TextStyle(
              color: isPaid ? AppColors.success : AppColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockAlerts extends StatelessWidget {
  final List lowStockProducts;

  const _LowStockAlerts({required this.lowStockProducts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  const Text('Low Stock Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              if (lowStockProducts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${lowStockProducts.length}', style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (lowStockProducts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 32, color: AppColors.success),
                    SizedBox(height: 12),
                    Text('All products are well-stocked!', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            )
          else
            Column(
              children: lowStockProducts.map<Widget>((p) => _LowStockItem(product: p)).toList(),
            ),
        ],
      ),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final dynamic product;

  const _LowStockItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock == 0;
    final percentage = (product.stock / product.lowStockThreshold) * 100;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (isOutOfStock ? AppColors.danger : AppColors.warning).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.warning_amber, size: 12, color: isOutOfStock ? AppColors.danger : AppColors.warning),
                    ),
                    const SizedBox(width: 8),
                    Text(product.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text('${product.productCode} • ${product.category}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOutOfStock ? AppColors.danger : AppColors.warning).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${product.stock} left', style: TextStyle(color: isOutOfStock ? AppColors.danger : AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.border,
                  color: isOutOfStock ? AppColors.danger : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceSummary extends StatelessWidget {
  final Map stats;

  const _PerformanceSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final profitMargin = stats['profitMargin'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              const Text('Performance Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Profit Margin', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('${profitMargin.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: profitMargin / 100,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _SummaryItem(label: 'Total Orders', value: '${stats['totalOrders'] ?? 0}'),
              _SummaryItem(label: 'Items Sold', value: '${stats['totalItemsSold'] ?? 0}'),
              _SummaryItem(label: 'Paid Orders', value: '${stats['paidCount'] ?? 0}', color: AppColors.success),
              _SummaryItem(label: 'Pending', value: '${stats['pendingPayments'] ?? 0}', color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}