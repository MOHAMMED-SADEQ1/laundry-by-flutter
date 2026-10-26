import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/processing_status.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/customer/customer_search.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customer/customaddcustomer.dart';
import 'package:laundry/view/widget/customer/customer_statement_sheet.dart';
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
      appBar: CustomAppbar(
        title: tr('الزبائن'),
        subtitle: tr('إدارة سجل الزبائن'),
      ),
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
          // نعتمد على الحالة التفاعلية للزبائن، فتظهر الإضافة فوراً بدون إعادة فتح الشاشة
          child: Obx(() {
            final controller = Get.put(CustomersNumberController());
            if (controller.loadingCustomers.value &&
                controller.customers.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              );
            }
            final data = controller.customers;
            if (data.isEmpty) {
              return EmptyState(
                icon: Icons.contacts_outlined,
                title: tr('لا يوجد زبائن'),
                subtitle: tr('اضغط زر + لإضافة زبون جديد'),
              );
            }

            // الفلترة تشمل **الاسم وأي من الرقمين** (كانت بالاسم وحده رغم أن
            // تلميح الحقل ينصّ على الرقم). المنطق الخالص في
            // `services/customer/customer_search.dart`.
            final filtered = CustomerSearch.filter(data, _query);

            return Column(
              children: [
                // ─── ملخص الذمم ───
                Obx(() {
                  final ctrl = Get.put(CustomersNumberController());
                  if (ctrl.totalDebt.value <= 0) {
                    return const SizedBox.shrink();
                  }
                  return InkWell(
                    onTap: () => Get.toNamed(AppRoute.debtAging),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trf('إجمالي الذمم: {0} ر.س', [
                                    ctrl.totalDebt.value.toStringAsFixed(2),
                                  ]),
                                  style: const TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                                Text(
                                  trf(
                                    '{0} زبون عليهم ذمة قائمة · اضغط لعرض أعمار الديون',
                                    [ctrl.debtorsCount.value],
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 11,
                                    color: AppColors.danger.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_back_ios_new,
                            size: 13,
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: tr('ابحث عن زبون بالاسم أو الرقم...'),
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
                          ? EmptyState(
                            icon: Icons.search_off,
                            title: tr('لا توجد نتائج'),
                            subtitle: tr('جرّب البحث باسم آخر أو برقم الجوال'),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final customer = filtered[i];
                              return FadeInUp(
                                delayMs: (i % 10) * 40,
                                child: _CustomerCard(customer: customer),
                              );
                            },
                          ),
                ),
              ],
            );
          }),
        ),
      ),
      floatingActionButton: CustomAddCustomer(
        onAdded: (name, phone) => setState(() {}),
      ),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 12, color: AppColors.success),
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
                    if (customer['phone_2']?.toString().isNotEmpty == true) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.phone_forwarded,
                        size: 12,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer['phone_2'].toString(),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ],
                ),
                // ─── شارة الذمة / الرصيد ───
                _DebtBadge(customer: customer),
              ],
            ),
          ),
          _StatementBtn(customer: customer),
          _AccountBtn(customer: customer),
          CustomDeleteExpanded(id: customer['customer_id']),
        ],
      ),
    );
  }
}

/// شارة تُظهر ذمة الزبون أو رصيده السلفة — لا تظهر إن كان مُسدَّدًا
class _DebtBadge extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _DebtBadge({required this.customer});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CustomersNumberController());
    return Obx(() {
      final debt = controller.debtOf(customer['customer_id']);
      final credit = controller.creditOf(customer);

      if (debt <= 0 && credit <= 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 12,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 4),
              Text(
                tr('لا ذمة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10.5,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        );
      }

      final isDebt = debt > 0;
      final color = isDebt ? AppColors.danger : AppColors.warning;
      final label =
          isDebt
              ? trf('عليه ذمة: {0} ر.س', [debt.toStringAsFixed(2)])
              : trf('له رصيد: {0} ر.س', [credit.toStringAsFixed(2)]);

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDebt ? Icons.warning_amber_rounded : Icons.savings,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

String _initialOf(dynamic value) {
  final name = value?.toString() ?? '';
  return name.isEmpty ? tr('؟') : name.substring(0, 1);
}

/// زر كشف حساب الزبون — عرض سريع + طباعة + مشاركة PDF + ملخّص واتساب.
class _StatementBtn extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _StatementBtn({required this.customer});

  @override
  Widget build(BuildContext context) {
    final id = customer['customer_id'] as int?;
    return IconButton(
      tooltip: tr('كشف حساب الزبون'),
      onPressed:
          id == null
              ? null
              : () => showCustomerStatementSheet(
                context,
                id,
                customerName: customer['customer_name']?.toString(),
                onQuickView:
                    () => Get.dialog(
                      _CustomerStatementDialog(customer: customer),
                      barrierColor: Colors.black54,
                    ),
              ),
      icon: const Icon(Icons.receipt_long, color: AppColors.primary, size: 21),
    );
  }
}

/// زر حساب الزبون — شاشة كاملة مع الدفعات
class _AccountBtn extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _AccountBtn({required this.customer});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('حساب الزبون'),
      onPressed: () {
        Get.toNamed('/customer-account', arguments: customer['customer_id']);
      },
      icon: const Icon(
        Icons.account_balance_wallet,
        color: AppColors.success,
        size: 21,
      ),
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
  List<Map<String, dynamic>> debtPayments = [];
  double deferredLiability = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.customer['customer_id'] as int?;
    if (id == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    // **إصلاح:** الربط بمعرّف الزبون لا بالاسم. البحث بالاسم كان يجلب
    // فواتير زبائن آخرين بأسماء مشابهة (مثل «علي» و«علي أحمد»).
    final rows = await db.safeRead(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [id],
      orderBy: 'invoices_id DESC',
      limit: 200,
    );

    // سلفة/دفعات ديون الزبون من دفتر الأستاذ
    final directPays = await db
        .readData(
          'SELECT cp.*, u.full_name AS user_name FROM customer_payments cp LEFT JOIN users u ON cp.recorded_by = u.user_id WHERE cp.customer_id = ? ORDER BY cp.payment_date DESC',
          [id],
        )
        .catchError((_) => <Map<String, dynamic>>[]);

    // دفعات اشتراكاته (مصدر منفصل — اشتراك لا دين)
    final pays = await db
        .readData(
          'SELECT sp.*, s.amount AS sub_price, s.period_days AS sub_period FROM subscription_payments sp JOIN subscriptions s ON s.subscription_id = sp.subscription_id WHERE s.customer_id = ? ORDER BY sp.paid_date DESC',
          [id],
        )
        .catchError((_) => <Map<String, dynamic>>[]);

    final deferred = await _loadDeferredLiability(id);

    if (mounted) {
      setState(() {
        invoices = rows;
        debtPayments = directPays;
        subPayments = pays;
        deferredLiability = deferred;
        loading = false;
      });
    }
  }

  /// المطلوب دفعه مقابل خدمة لم تُنفَّذ بعد = التزام على المنشأة، لا دين على
  /// الزبون. فصله عن «المتبقي (ذمة)» ضروري وإلا ظهر الزبون مديناً بمبالغ
  /// دفعها مقدماً.
  Future<double> _loadDeferredLiability(int id) async {
    try {
      final subs = await db.readData(
        'SELECT subscription_id, amount, paid_until_date, period_days, status FROM subscriptions WHERE customer_id = ? AND "is_active" = 1 AND status != ?',
        [id, 'cancelled'],
      );
      final today = DateTime.now();
      double deferred = 0;
      for (final s in subs) {
        final until = SubscriptionService.paidUntil(s);
        final price = ((s['amount'] ?? 0) as num).toDouble();
        final days = ((s['period_days'] ?? 30) as num).toInt();
        if (price <= 0 || days <= 0) continue;
        final remainingDays = until.difference(today).inDays;
        if (remainingDays <= 0) continue;
        // نسبة الأيام المتبقية من الدورة × سعر الدورة = الإيراد المؤجَّل
        final perDay = price / days;
        deferred += perDay * remainingDays;
      }
      return deferred;
    } catch (_) {
      return 0;
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
    double total = 0, paid = 0, remaining = 0, debtPaid = 0;
    for (final inv in invoices) {
      total +=
          double.tryParse(
            '${inv['final_amount'] ?? inv['total_price'] ?? 0}',
          ) ??
          0;
      paid += double.tryParse('${inv['paid_amount'] ?? 0}') ?? 0;
      remaining += double.tryParse('${inv['remaining_amount'] ?? 0}') ?? 0;
    }
    for (final p in debtPayments) {
      debtPaid += double.tryParse('${p['amount'] ?? 0}') ?? 0;
    }
    // الرصيد الدائن (سلفة) من سجل الزبون
    final rawBalance = ((widget.customer['balance'] ?? 0) as num).toDouble();
    final credit = rawBalance > 0 ? rawBalance : 0.0;

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
                          trf(
                            'كشف حساب — {0}',
                            [widget.customer['customer_name']],
                          ),
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
                    label: tr('المشتريات'),
                    value: total,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _SumBox(
                    label: tr('المدفوع'),
                    value: paid,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _SumBox(
                    label: tr('المتبقي (ذمة)'),
                    value: remaining,
                    color: remaining > 0 ? AppColors.danger : AppColors.slate,
                  ),
                  const SizedBox(width: 8),
                  _SumBox(
                    label:
                        tr(credit > 0 ? 'رصيد (سلفة)' : 'دفعات الذمم'),
                    value: credit > 0 ? credit : debtPaid,
                    color: credit > 0 ? AppColors.warning : AppColors.violet,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // ─── إفصاح: إيراد مؤجَّل (التزام على المنشأة لا دين على الزبون) ───
            if (deferredLiability > 0.009)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tr(
                            'خدمة اشتراك مدفوعة مقدماً لم تُنفَّذ بعد (التزام على المنشأة — ليست ديناً على الزبون)',
                          ),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trf('{0} ر.س', [
                          deferredLiability.toStringAsFixed(2),
                        ]),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ─── الفواتير ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  trf('الفواتير ({0})', [invoices.length]),
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
                      : invoices.isEmpty &&
                          subPayments.isEmpty &&
                          debtPayments.isEmpty
                      ? Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          tr('لا توجد فواتير أو دفعات لهذا الزبون'),
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
                          if (debtPayments.isNotEmpty) ...[
                            Text(
                              trf('دفعات الذمم ({0})', [debtPayments.length]),
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...debtPayments.map(_debtPaymentTile),
                            const SizedBox(height: 14),
                          ],
                          if (subPayments.isNotEmpty) ...[
                            Text(
                              trf(
                                'دفعات الاشتراكات ({0})',
                                [subPayments.length],
                              ),
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

  /// بند دفعة ذمة (من دفتر الدفعات) — مع بيان المصدر
  Widget _debtPaymentTile(Map<String, dynamic> p) {
    final paidDate = '${p['payment_date'] ?? ''}'.split('T').first;
    final notes = p['notes']?.toString() ?? '';
    final source = p['source']?.toString() ?? 'manual';
    final method = PaymentMethods.label(
      p['method'] ?? p['payment_method'] ?? 'cash',
    );
    final amount = double.tryParse('${p['amount'] ?? 0}') ?? 0;
    final srcLabel = switch (source) {
      'delivery' => tr('سداد عند التسليم'),
      'credit_use' => tr('من الرصيد'),
      _ => tr('دفعة يدوية'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 14,
                color: AppColors.violet,
              ),
              const SizedBox(width: 6),
              Text(
                srcLabel,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                trf('{0} ر.س', [amount.toStringAsFixed(2)]),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trf(
              tr('التاريخ: {0} — {1}{2}'),
              [paidDate, method, notes.isEmpty ? '' : ' — $notes'],
            ),
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
                tr('دفعة اشتراك'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                trf('{0} ر.س', [p['amount']]),
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
            trf(
              tr('التاريخ: {0} — {1}{2}'),
              [paidDate, p['method'] ?? tr('كاش'), notes.isEmpty ? '' : ' — $notes'],
            ),
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
                trf('فاتورة #{0}', [inv['invoices_id']]),
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
                    trf('رمز: {0}', [inv['pickup_code']]),
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
                  text: ProcessingStatuses.label(status),
                  color: AppColors.info,
                  icon: Icons.local_laundry_service,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            items.isEmpty
                ? '${inv['invoice_date'] ?? ''}'
                : '${items.take(2).map((x) => '${localized(x, 'vestments')} ×${x['count']}').join('، ')}${items.length > 2 ? ' +${items.length - 2}' : ''} — ${inv['invoice_date']?.toString().split('T').first ?? ''}',
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
                trf('إجمالي {0}', [inv['total_price']]),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trf('مدفوع {0}', [inv['paid_amount']]),
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
                  trf('متبقي {0}', [invRemaining.toStringAsFixed(2)]),
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
