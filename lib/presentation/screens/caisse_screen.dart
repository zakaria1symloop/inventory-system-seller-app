import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/caisse_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/caisse_transaction_model.dart';

class CaisseScreen extends ConsumerStatefulWidget {
  const CaisseScreen({super.key});

  @override
  ConsumerState<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends ConsumerState<CaisseScreen> {
  String? _filterType;

  @override
  Widget build(BuildContext context) {
    final caisseAsync = ref.watch(myCaisseProvider);
    final transactionsAsync = ref.watch(myRecentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوقي'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myCaisseProvider);
          ref.invalidate(myRecentTransactionsProvider);
        },
        child: caisseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (caisse) {
            if (caisse == null) {
              return const Center(
                child: Text(
                  'لا يوجد صندوق لهذا الحساب',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      children: [
                        const Text(
                          'الرصيد الحالي',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${caisse.balance.toStringAsFixed(2)} د.ج',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getTypeLabel(caisse.type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الحركات الأخيرة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SegmentedButton<String?>(
                        segments: const [
                          ButtonSegment(value: null, label: Text('الكل')),
                          ButtonSegment(value: 'in', label: Text('وارد')),
                          ButtonSegment(value: 'out', label: Text('صادر')),
                        ],
                        selected: {_filterType},
                        onSelectionChanged: (selected) {
                          setState(() => _filterType = selected.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStatePropertyAll(
                            Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Transactions List
                  transactionsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(child: Text('خطأ: $e')),
                    data: (transactions) {
                      final filtered = _filterType == null
                          ? transactions
                          : transactions
                              .where((tx) => tx.type == _filterType)
                              .toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'لا توجد حركات',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _TransactionTile(
                            transaction: filtered[index],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'principale':
        return 'صندوق رئيسي';
      case 'vendeur':
        return 'صندوق بائع';
      case 'livreur':
        return 'صندوق سائق';
      default:
        return type;
    }
  }
}

class _TransactionTile extends StatelessWidget {
  final CaisseTransactionModel transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIn = transaction.type == 'in';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isIn ? AppTheme.successColor : AppTheme.dangerColor)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isIn ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIn ? AppTheme.successColor : AppTheme.dangerColor,
          size: 20,
        ),
      ),
      title: Text(
        transaction.description ?? transaction.sourceTypeLabel,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDate(transaction.createdAt),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isIn ? '+' : '-'}${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIn ? AppTheme.successColor : AppTheme.dangerColor,
            ),
          ),
          Text(
            '${transaction.balanceAfter.toStringAsFixed(2)} د.ج',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
