import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customer/customaddcustomer.dart';
import 'package:laundry/view/widget/customer/customdeletecustomer.dart';

class CustomerNumber extends StatefulWidget {
  const CustomerNumber({super.key});

  @override
  State<CustomerNumber> createState() => _CustomerNumberState();
}

class _CustomerNumberState extends State<CustomerNumber> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(title: 'الزبائن', subtitle: 'إدارة سجل الزبائن'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF0FDFA)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {},
          child: GetBuilder<CustomersNumberController>(
            init: CustomersNumberController(),
            builder:
                (controller) => FutureBuilder(
                  future: controller.readData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      );
                    }
                    if (snapshot.hasError) {
                      return const EmptyState(
                        icon: Icons.error_outline,
                        title: 'حدث خطأ في جلب البيانات',
                        color: AppColors.danger,
                      );
                    }
                    final data = snapshot.data;
                    if (data == null || data.isEmpty) {
                      return const EmptyState(
                        icon: Icons.contacts_outlined,
                        title: 'لا يوجد زبائن',
                        subtitle: 'اضغط زر + لإضافة زبون جديد',
                      );
                    }

                    final filtered =
                        _query.isEmpty
                            ? data
                            : data
                                .where(
                                  (c) => (c['customer_name'] ?? '')
                                      .toString()
                                      .contains(_query),
                                )
                                .toList();

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v.trim()),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن زبون بالاسم أو الرقم...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon:
                                  _query.isEmpty
                                      ? null
                                      : IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _query = '');
                                        },
                                      ),
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              filtered.isEmpty
                                  ? const EmptyState(
                                    icon: Icons.search_off,
                                    title: 'لا توجد نتائج',
                                    subtitle: 'جرّب البحث باسم آخر',
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      14,
                                      90,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, i) {
                                      final customer = filtered[i];
                                      return FadeInUp(
                                        delayMs: (i % 10) * 40,
                                        child: _CustomerCard(
                                          customer: customer,
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ),
      ),
      floatingActionButton: CustomAddCustomer(onAdded: () => setState(() {})),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // ─── الحرف الأول ───
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initialOf(customer['customer_name']),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ─── البيانات ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['customer_name'] ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 12,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer['phone_1']?.toString().isNotEmpty == true
                                ? customer['phone_1'].toString()
                                : '-',
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone_forwarded,
                            size: 12,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer['phone_2']?.toString().isNotEmpty == true
                                ? customer['phone_2'].toString()
                                : '-',
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _StatementBtn(customer: customer),
          CustomDeleteExpanded(id: customer['customer_id']),
        ],
      ),
    );
  }
}

String _initialOf(dynamic value) {
  final name = value?.toString() ?? '';
  return name.isEmpty ? '؟' : name.substring(0, 1);
}

/// زر كشف حساب الزبون — فواتير وذمم
class _StatementBtn extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _StatementBtn({required this.customer});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'كشف حساب الزبون',
      onPressed: () {
        Get.dialog(
          _CustomerStatementDialog(customer: customer),
          barrierColor: Colors.black54,
        );
      },
      icon: const Icon(Icons.receipt_long, color: AppColors.primary, size: 21),
    );
  }
}

class _CustomerStatementDialog extends StatefulWidget {
  final Map<String, dynamic> customer;
  const _CustomerStatementDialog({required this.customer});

  @override
  State<_CustomerStatementDialog> createState() =>
      _CustomerStatementDialogState();
}

class _CustomerStatementDialogState extends State<_CustomerStatementDialog> {
  final SqlDB db = SqlDB();
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> subPayments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await db.safeRead(
      'invoices',
      where: 'customer_name LIKE ?',
      whereArgs: ['%${widget.customer['customer_name']}%'],
      orderBy: 'invoices_id DESC',
      limit: 100,
    );
    final pays = await db
        .readData(
          'SELECT sp.*, s.amount AS sub_price, s.period_days AS sub_period '
          'FROM subscription_payments sp '
          'JOIN subscriptions s ON s.subscription_id = sp.subscription_id '
          'WHERE s.customer_id = ? ORDER BY sp.paid_date DESC',
          [widget.customer['customer_id']],
        )
        .catchError((_) => <Map<String, dynamic>>[]);
    if (mounted) {
      setState(() {
        invoices = rows;
        subPayments = pays;
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> inv) {
    final raw = inv['list_data'];
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw.toString()));
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = 0, paid = 0, remaining = 0, subPaid = 0;
    for (final inv in invoices) {
      total += double.tryParse('${inv['total_price'] ?? 0}') ?? 0;
      paid += double.tryParse('${inv['paid_amount'] ?? 0}') ?? 0;
      remaining += double.tryParse('${inv['remaining_amount'] ?? 0}') ?? 0;
    }
    for (final p in subPayments) {
      subPaid += double.tryParse('${p['amount'] ?? 0}') ?? 0;
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── الرأس ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كشف حساب — ${widget.customer['customer_name']}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.customer['phone_1'] ?? ''}',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // ─── الملخص ───
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  _SumBox(
                    label: 'المشتريات',
                    value: total,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _SumBox(
                    label: 'المدفوع',
                    value: paid,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _SumBox(
                    label: 'المتبقي (ذمة)',
                    value: remaining,
                    color: remaining > 0 ? AppColors.danger : AppColors.slate,
                  ),
                  const SizedBox(width: 8),
                  _SumBox(
                    label: 'دفعات الاشتراكات',
                    value: subPaid,
                    color: AppColors.violet,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // ─── الفواتير ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الفواتير (${invoices.length})',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child:
                  loading
                      ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                      : invoices.isEmpty && subPayments.isEmpty
                      ? Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'لا توجد فواتير أو اشتراكات لهذا الزبون',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                      : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        children: [
                          if (subPayments.isNotEmpty) ...[
                            Text(
                              'دفعات الاشتراكات (${subPayments.length})',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...subPayments.map(_paymentTile),
                            const SizedBox(height: 14),
                          ],
                          ...invoices.map(_invoiceTile),
                        ],
                      ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final paidDate = '${p['paid_date'] ?? ''}'.split('T').first;
    final notes = p['notes']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payment_rounded,
                size: 14,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                'دفعة اشتراك',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${p['amount']} ر.س',
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'التاريخ: $paidDate — ${p['method'] ?? 'كاش'}'
            '${notes.isEmpty ? '' : ' — $notes'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceTile(Map<String, dynamic> inv) {
    final items = _itemsOf(inv);
    final invRemaining =
        double.tryParse('${inv['remaining_amount'] ?? 0}') ?? 0;
    final status = inv['status']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'فاتورة #${inv['invoices_id']}',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (inv['pickup_code'] != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'رمز: ${inv['pickup_code']}',
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (status.isNotEmpty)
                LabelChip(
                  text: status,
                  color: AppColors.info,
                  icon: Icons.local_laundry_service,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            items.isEmpty
                ? '${inv['invoice_date'] ?? ''}'
                : '${items.take(2).map((x) => '${x['vestments']} ×${x['count']}').join('، ')}${items.length > 2 ? ' +${items.length - 2}' : ''} — ${inv['invoice_date']?.toString().split('T').first ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'إجمالي ${inv['total_price']}',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'مدفوع ${inv['paid_amount']}',
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              const Spacer(),
              if (invRemaining > 0)
                Text(
                  'متبقي ${invRemaining.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SumBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SumBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
