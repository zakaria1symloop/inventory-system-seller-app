import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/order_model.dart';
import '../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'order_detail_screen.dart';

// Filter state class
class OrdersFilter {
  final bool todayOnly;
  final int page;
  final int perPage;

  const OrdersFilter({
    this.todayOnly = true,
    this.page = 1,
    this.perPage = 20,
  });

  OrdersFilter copyWith({
    bool? todayOnly,
    int? page,
    int? perPage,
  }) {
    return OrdersFilter(
      todayOnly: todayOnly ?? this.todayOnly,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }
}

// Orders state
class OrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final int? lastPage;
  final String? error;
  final OrdersFilter filter;

  OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.lastPage,
    this.error,
    this.filter = const OrdersFilter(),
  });

  OrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    int? lastPage,
    String? error,
    OrdersFilter? filter,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      error: error,
      filter: filter ?? this.filter,
    );
  }
}

// Orders notifier with filtering and pagination
class OrdersNotifier extends StateNotifier<OrdersState> {
  final Ref ref;

  OrdersNotifier(this.ref) : super(OrdersState()) {
    loadOrders();
  }

  Future<void> loadOrders({bool refresh = false}) async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = <String, dynamic>{
        'page': page,
        'per_page': state.filter.perPage,
      };

      // Add date filter for today only
      if (state.filter.todayOnly) {
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        params['from_date'] = dateStr;
        params['to_date'] = dateStr;
      }

      final response = await ApiService.instance.getMyOrders(params: params);

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> ordersList;
        int? lastPage;

        if (data is Map) {
          ordersList = data['data'] as List<dynamic>? ?? [];
          lastPage = data['last_page'] as int?;
        } else if (data is List) {
          ordersList = data;
        } else {
          ordersList = [];
        }

        final orders = ordersList.map((json) => OrderModel.fromJson(json)).toList();
        final hasMore = lastPage != null ? page < lastPage : orders.length >= state.filter.perPage;

        state = state.copyWith(
          orders: refresh ? orders : [...state.orders, ...orders],
          isLoading: false,
          hasMore: hasMore,
          currentPage: page + 1,
          lastPage: lastPage,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setTodayOnly(bool todayOnly) {
    state = OrdersState(filter: OrdersFilter(todayOnly: todayOnly));
    loadOrders(refresh: true);
  }

  void refresh() {
    state = OrdersState(filter: state.filter);
    loadOrders(refresh: true);
  }
}

// Provider
final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref);
});

// Keep the old provider for backward compatibility
final todayOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.user == null) return [];
  final response = await ApiService.instance.getMyOrders();
  final data = response.data;
  final List orders = data is Map ? (data["data"] ?? []) : data;
  return orders.map((o) => OrderModel.fromJson(o)).toList();
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(ordersProvider.notifier).loadOrders();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);

    return Column(
      children: [
        // Filter chips - simplified: Today / All
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: 'اليوم',
                  icon: Icons.today,
                  isSelected: ordersState.filter.todayOnly,
                  onTap: () => ref.read(ordersProvider.notifier).setTodayOnly(true),
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterChip(
                  label: 'الكل',
                  icon: Icons.history,
                  isSelected: !ordersState.filter.todayOnly,
                  onTap: () => ref.read(ordersProvider.notifier).setTodayOnly(false),
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Orders list
        Expanded(
          child: _buildOrdersList(ordersState),
        ),
      ],
    );
  }

  Widget _buildOrdersList(OrdersState state) {
    if (state.error != null && state.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('خطأ: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(ordersProvider.notifier).refresh(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (state.orders.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.filter.todayOnly ? Icons.today : Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              state.filter.todayOnly ? 'لا توجد طلبات اليوم' : 'لا توجد طلبات',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (state.filter.todayOnly)
              TextButton(
                onPressed: () => ref.read(ordersProvider.notifier).setTodayOnly(false),
                child: const Text('عرض كل الطلبات'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(ordersProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.orders.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final order = state.orders[index];
          return _OrderCard(
            order: order,
            onTap: () {
              if (order.id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailScreen(
                      orderId: order.id!,
                      initialOrder: order,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? chipColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? chipColor : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const _OrderCard({required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long, color: _getStatusColor(order.status), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.reference ?? '#${order.localId?.substring(0, 8) ?? order.id}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (order.date.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(order.date),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: order.status, isSynced: order.isSynced),
                      const SizedBox(height: 4),
                      _PaymentBadge(status: order.paymentStatus),
                    ],
                  ),
                ],
              ),
            ),

            // Client info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.clientName ?? 'عميل',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (order.clientPhone != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Text(
                            order.clientPhone!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                    if (order.clientAddress != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.clientAddress!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'المنتجات',
                      value: '${order.items.length}',
                      color: Colors.blue,
                    ),
                  ),
                  Container(width: 1, height: 35, color: Colors.grey[300]),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.discount_outlined,
                      label: 'الخصم',
                      value: '${order.discount.toStringAsFixed(0)} د.ج',
                      color: Colors.orange,
                    ),
                  ),
                  Container(width: 1, height: 35, color: Colors.grey[300]),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.receipt_outlined,
                      label: 'الضريبة',
                      value: '${order.tax.toStringAsFixed(0)} د.ج',
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),

            // Total amount
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor.withValues(alpha: 0.1), AppTheme.primaryColor.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments, size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المجموع الكلي',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          Text(
                            '${order.grandTotal.toStringAsFixed(0)} د.ج',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!order.isSynced)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            'غير مزامن',
                            style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
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
      case 'delivered':
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return date;
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String status;

  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'paid':
        bgColor = AppTheme.successColor.withValues(alpha: 0.1);
        textColor = AppTheme.successColor;
        label = 'مدفوع';
        break;
      case 'partial':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        label = 'جزئي';
        break;
      default:
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.1);
        textColor = AppTheme.dangerColor;
        label = 'غير مدفوع';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isSynced;

  const _StatusBadge({required this.status, required this.isSynced});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = AppTheme.warningColor.withValues(alpha: 0.1);
        textColor = AppTheme.warningColor;
        label = 'معلق';
        break;
      case 'confirmed':
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.1);
        textColor = AppTheme.primaryColor;
        label = 'مؤكد';
        break;
      case 'delivered':
        bgColor = AppTheme.successColor.withValues(alpha: 0.1);
        textColor = AppTheme.successColor;
        label = 'تم التسليم';
        break;
      case 'cancelled':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.1);
        textColor = AppTheme.dangerColor;
        label = 'ملغي';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
