import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caisse_provider.dart';
import '../../providers/sync_provider.dart';
import '../../core/theme/app_theme.dart';
import 'clients_screen.dart';
import 'products_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  List<Widget> get _screens => [
    _DashboardTab(onNavigateToTab: _navigateToTab),
    const ClientsScreen(),
    const ProductsScreen(),
    const OrdersScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectivityProvider.notifier).checkConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final connectivityState = ref.watch(connectivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          if (connectivityState.isChecking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Badge(
                isLabelVisible: false,
                label: Text('${0}'),
                child: const Icon(Icons.sync),
              ),
              onPressed: () async {
                await ref.read(connectivityProvider.notifier).checkConnection();
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(authState.user?.name ?? 'المستخدم'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppTheme.dangerColor),
                    SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: AppTheme.dangerColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_currentIndex],
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'العملاء',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'المنتجات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'الطلبات',
          ),
        ],
      ),
    );
  }

  Widget? _buildFAB() {
    switch (_currentIndex) {
      case 1:
        return FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.pushNamed(context, '/add-client');
            if (!mounted) return;
            if (result == true) {
              ref.invalidate(clientsProvider(null));
            }
          },
          child: const Icon(Icons.person_add),
        );
      case 3:
        return FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.pushNamed(context, '/create-order');
            if (!mounted) return;
            if (result == true) {
              ref.invalidate(todayOrdersProvider);
            }
          },
          child: const Icon(Icons.add_shopping_cart),
        );
      default:
        return null;
    }
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'الرئيسية';
      case 1:
        return 'العملاء';
      case 2:
        return 'المنتجات';
      case 3:
        return 'الطلبات';
      default:
        return 'تطبيق البائع';
    }
  }
}

class _DashboardTab extends ConsumerWidget {
  final void Function(int) onNavigateToTab;

  const _DashboardTab({required this.onNavigateToTab});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final connectivityState = ref.watch(connectivityProvider);
    final ordersAsync = ref.watch(todayOrdersProvider);
    final caisseAsync = ref.watch(myCaisseProvider);

    // Calculate today's stats
    final todayOrders = ordersAsync.valueOrNull ?? [];
    final totalOrders = todayOrders.length;
    final totalRevenue = todayOrders.fold<double>(
      0,
      (sum, o) => sum + o.grandTotal,
    );
    final pendingOrders = todayOrders
        .where((o) => o.status == 'pending')
        .length;
    final confirmedOrders = todayOrders
        .where((o) => o.status == 'confirmed')
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(connectivityProvider.notifier).checkConnection();
        ref.invalidate(todayOrdersProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authState.user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحبا، ${authState.user?.name ?? 'المستخدم'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(DateTime.now()),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: connectivityState.isChecking
                          ? Colors.orange
                          : AppTheme.successColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          connectivityState.isChecking
                              ? Icons.sync
                              : Icons.cloud_done,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          connectivityState.isChecking ? 'جاري...' : 'متصل',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Caisse Balance Card
            caisseAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (caisse) {
                if (caisse == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/caisse'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رصيد الصندوق',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${caisse.balance.toStringAsFixed(2)} د.ج',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_left,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Today's Stats
            const Text(
              'إحصائيات اليوم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.receipt_long,
                    label: 'الطلبات',
                    value: '$totalOrders',
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.payments,
                    label: 'المبيعات',
                    value: '${totalRevenue.toStringAsFixed(0)}',
                    subLabel: 'د.ج',
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.pending_actions,
                    label: 'معلق',
                    value: '$pendingOrders',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    label: 'مؤكد',
                    value: '$confirmedOrders',
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'إجراءات سريعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _QuickActionCard(
                  icon: Icons.add_shopping_cart,
                  label: 'طلب جديد',
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.pushNamed(context, '/create-order');
                  },
                ),
                _QuickActionCard(
                  icon: Icons.person_add,
                  label: 'عميل جديد',
                  color: AppTheme.successColor,
                  onTap: () {
                    Navigator.pushNamed(context, '/add-client');
                  },
                ),
                _QuickActionCard(
                  icon: Icons.inventory,
                  label: 'المنتجات',
                  color: AppTheme.warningColor,
                  onTap: () => onNavigateToTab(2),
                ),
                _QuickActionCard(
                  icon: Icons.history,
                  label: 'سجل الطلبات',
                  color: AppTheme.secondaryColor,
                  onTap: () => onNavigateToTab(3),
                ),
                _QuickActionCard(
                  icon: Icons.account_balance_wallet,
                  label: 'صندوقي',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pushNamed(context, '/caisse');
                  },
                ),
              ],
            ),

            // Recent orders preview
            if (todayOrders.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'آخر الطلبات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => onNavigateToTab(3),
                    child: const Text('عرض الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...todayOrders
                  .take(3)
                  .map(
                    (order) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              order.status,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt,
                            color: _getStatusColor(order.status),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          order.clientName ?? 'عميل',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          order.reference ?? '#${order.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${order.grandTotal.toStringAsFixed(0)} د.ج',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  order.status,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusLabel(order.status),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getStatusColor(order.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/order-detail',
                            arguments: order,
                          );
                        },
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppTheme.successColor;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return AppTheme.dangerColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'pending':
        return 'معلق';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subLabel;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (subLabel != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          subLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
