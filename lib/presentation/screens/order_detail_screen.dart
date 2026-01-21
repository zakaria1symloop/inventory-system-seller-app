import 'dart:typed_data';
import 'package:flutter/material.dart' hide TextDirection;
import 'package:flutter/material.dart' as material show TextDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/models/order_model.dart';
import '../../data/services/api_service.dart';
import '../../core/theme/app_theme.dart';

// Provider for single order
final orderDetailProvider = FutureProvider.family<OrderModel, int>((ref, orderId) async {
  final response = await ApiService.instance.getOrder(orderId);
  if (response.statusCode == 200) {
    return OrderModel.fromJson(response.data);
  }
  throw Exception('Failed to load order');
});

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  final OrderModel? initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Directionality(
      textDirection: material.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _printReceipt(context, orderAsync.valueOrNull ?? initialOrder),
              tooltip: 'طباعة الفاتورة',
            ),
          ],
        ),
        body: orderAsync.when(
          data: (order) => _buildOrderContent(context, order),
          loading: () => initialOrder != null
              ? _buildOrderContent(context, initialOrder!)
              : const Center(child: CircularProgressIndicator()),
          error: (error, _) => initialOrder != null
              ? _buildOrderContent(context, initialOrder!)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('خطأ: $error'),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _printReceipt(context, orderAsync.valueOrNull ?? initialOrder),
            icon: const Icon(Icons.print),
            label: const Text('طباعة الفاتورة'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderContent(BuildContext context, OrderModel order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Order Header with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رقم الطلب',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.reference ?? '#${order.id}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HeaderStat(
                        icon: Icons.calendar_today,
                        label: 'التاريخ',
                        value: _formatDateShort(order.date),
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _HeaderStat(
                        icon: Icons.inventory_2,
                        label: 'المنتجات',
                        value: '${order.items.length}',
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _HeaderStat(
                        icon: Icons.payments,
                        label: 'الدفع',
                        value: _getPaymentStatusLabel(order.paymentStatus),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Client Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'العميل',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.clientName ?? 'غير محدد',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (order.clientPhone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            order.clientPhone!,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Products Section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_cart, size: 20, color: Colors.blue),
            ),
            const SizedBox(width: 10),
            const Text(
              'المنتجات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${order.items.length} منتج',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                    Expanded(child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                    Expanded(child: Text('قطع/و', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                    Expanded(child: Text('السعر', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                    Expanded(flex: 2, child: Text('المجموع', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                  ],
                ),
              ),
              // Items
              if (order.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('لا توجد منتجات', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              else
                ...order.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: index.isEven ? Colors.white : Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.productName ?? 'منتج #${item.productId}',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.quantityOrdered}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.piecesPerPackage}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.unitPrice.toStringAsFixed(0)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${item.subtotal.toStringAsFixed(0)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${item.unitPrice.toStringAsFixed(0)}×${item.quantityOrdered}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Summary with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.successColor.withValues(alpha: 0.05),
                AppTheme.successColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _SummaryRow(label: 'المجموع الفرعي', value: '${order.totalAmount.toStringAsFixed(0)} د.ج'),
                if (order.discount > 0)
                  _SummaryRow(label: 'الخصم', value: '-${order.discount.toStringAsFixed(0)} د.ج', isNegative: true),
                if (order.tax > 0)
                  _SummaryRow(label: 'الضريبة', value: '${order.tax.toStringAsFixed(0)} د.ج'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.receipt_long, color: AppTheme.successColor),
                          SizedBox(width: 8),
                          Text(
                            'الإجمالي',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        '${order.grandTotal.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.note, size: 18, color: Colors.amber),
                    ),
                    const SizedBox(width: 10),
                    const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(order.notes!, style: TextStyle(color: Colors.grey[700], height: 1.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  String _formatDateShort(String date) {
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}';
    } catch (_) {
      return date;
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
    } catch (_) {
      return date;
    }
  }

  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'مدفوع جزئياً';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return status;
    }
  }

  Future<void> _printReceipt(BuildContext context, OrderModel? order) async {
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن طباعة الفاتورة')),
      );
      return;
    }

    final pdf = await _generateReceiptPdf(order);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf,
      name: 'فاتورة_${order.reference ?? order.id}',
    );
  }

  Future<Uint8List> _generateReceiptPdf(OrderModel order) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'فاتورة',
                      style: pw.TextStyle(font: arabicFontBold, fontSize: 24),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      order.reference ?? '#${order.id}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Client & Date Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('العميل: ${order.clientName ?? "غير محدد"}', style: pw.TextStyle(font: arabicFont)),
                  pw.Text('التاريخ: ${_formatDate(order.date)}', style: pw.TextStyle(font: arabicFont)),
                ],
              ),
              pw.SizedBox(height: 20),

              // Products Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('المنتج', style: pw.TextStyle(font: arabicFontBold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('الكمية', style: pw.TextStyle(font: arabicFontBold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('قطع/و', style: pw.TextStyle(font: arabicFontBold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('السعر', style: pw.TextStyle(font: arabicFontBold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('المجموع', style: pw.TextStyle(font: arabicFontBold), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                  // Data Rows
                  ...order.items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.productName ?? 'منتج #${item.productId}', style: pw.TextStyle(font: arabicFont)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.quantityOrdered}', style: pw.TextStyle(font: arabicFontBold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.piecesPerPackage}', style: pw.TextStyle(font: arabicFont, color: PdfColors.blue700), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.unitPrice.toStringAsFixed(0)}', style: pw.TextStyle(font: arabicFont), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('${item.subtotal.toStringAsFixed(0)}', style: pw.TextStyle(font: arabicFontBold), textAlign: pw.TextAlign.center),
                                pw.Text('${item.unitPrice.toStringAsFixed(0)}×${item.quantityOrdered}', style: pw.TextStyle(font: arabicFont, fontSize: 8, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
                              ],
                            ),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المجموع الفرعي:', style: pw.TextStyle(font: arabicFont)),
                        pw.Text('${order.totalAmount.toStringAsFixed(2)} د.ج', style: pw.TextStyle(font: arabicFont)),
                      ],
                    ),
                    if (order.discount > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('الخصم:', style: pw.TextStyle(font: arabicFont)),
                          pw.Text('-${order.discount.toStringAsFixed(2)} د.ج', style: pw.TextStyle(font: arabicFont)),
                        ],
                      ),
                    ],
                    if (order.tax > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('الضريبة:', style: pw.TextStyle(font: arabicFont)),
                          pw.Text('${order.tax.toStringAsFixed(2)} د.ج', style: pw.TextStyle(font: arabicFont)),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الإجمالي:', style: pw.TextStyle(font: arabicFontBold, fontSize: 16)),
                        pw.Text('${order.grandTotal.toStringAsFixed(2)} د.ج', style: pw.TextStyle(font: arabicFontBold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),

              if (order.notes != null && order.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('ملاحظات: ${order.notes}', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
              ],

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'شكراً لتعاملكم معنا',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isNegative;

  const _SummaryRow({required this.label, required this.value, this.isNegative = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: TextStyle(color: isNegative ? Colors.red : null)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

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
