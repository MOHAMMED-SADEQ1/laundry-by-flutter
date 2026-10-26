import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/subscriptions_controller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// شاشة الاشتراكات الشهرية للزبائن
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SubscriptionsController());

    return Scaffold(
      appBar: CustomAppbar(
        title: tr('الاشتراكات الشهرية'),
        subtitle: tr('متابعة فواتير الاشتراكات واستحقاقاتها'),
        actions: IconButton(
          tooltip: tr('لوحة الاشتراكات'),
          icon: const Icon(Icons.insights_outlined, color: Colors.white),
          onPressed: () => Get.toNamed(AppRoute.subscriptionDashboard),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (controller.isLoading.value && controller.subscriptions.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            );
          }
          if (controller.subscriptions.isEmpty) {
            return EmptyState(
              icon: Icons.card_membership,
              title: tr('لا توجد اشتراكات'),
              subtitle: tr('اضغط زر + لإضافة اشتراك لزبون محدد'),
            );
          }
          // ─── ملخص ───
          final overdue =
              controller.subscriptions
                  .where((s) => controller.isOverdue(s))
                  .toList();
          final active = controller.subscriptions.length;
          final monthlyTotal = controller.subscriptions.fold<double>(
            0,
            (sum, s) => sum + ((s['amount'] ?? 0) as num).toDouble(),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    _MiniStat(
                      label: tr('اشتراكات نشطة'),
                      value: '$active',
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: tr('مستحقات متأخرة'),
                      value: '${overdue.length}',
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: tr('إيراد الشهر المقطوع'),
                      value: monthlyTotal.toStringAsFixed(0),
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),

              // ─── 💰 شريط المؤشرات المالية: إيراد مُعترف به + التزام متبقٍّ ───
              // كانت هذه الأرقام غائبة تمامًا: الشاشة تعرض ما سيُقبَض، ولا
              // تعرض ما استُهلك فعلًا ولا ما بقي واجبًا على المحل تقديمه.
              Obx(() {
                final fin = controller.financials.value;
                if (fin == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.softShadow(blur: 8, y: 2),
                    ),
                    child: Row(
                      children: [
                        _finCell(
                          tr('خدمة مُقدَّمة'),
                          fin.recognized,
                          AppColors.info,
                        ),
                        _divider(),
                        _finCell(
                          tr('محصَّل'),
                          fin.collected,
                          AppColors.success,
                        ),
                        _divider(),
                        _finCell(
                          tr('التزام متبقٍّ'),
                          fin.deferred,
                          AppColors.violet,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: () => _showStudyDialog(controller),
                        icon: const Icon(Icons.assessment, size: 17),
                        label: Text(
                          tr('دراسة نهاية الشهر'),
                          style: TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          side: BorderSide(
                            color: AppColors.violet.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: () => _showDueRenewals(controller),
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          size: 17,
                        ),
                        label: Text(
                          tr('مستحقّ التجديد'),
                          style: TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadSubscriptions,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                    itemCount: controller.subscriptions.length,
                    itemBuilder: (context, i) {
                      final sub = controller.subscriptions[i];
                      return FadeInUp(
                        delayMs: (i % 10) * 40,
                        child: _SubscriptionCard(
                          controller: controller,
                          sub: sub,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(controller),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          tr('اشتراك جديد'),
          style: TextStyle(
            fontFamily: 'cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _finCell(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 9.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 26,
    color: AppColors.border,
  );

  /// الاشتراكات المستحقّة للتجديد خلال 7 أيام — تنبيه مبكّر للإدارة.
  void _showDueRenewals(SubscriptionsController controller) {
    final due = controller.subscriptions.where((s) {
      final d = SubscriptionService.daysRemaining(s);
      return d >= 0 && d <= 7;
    }).toList()
      ..sort(
        (a, b) => SubscriptionService.daysRemaining(
          a,
        ).compareTo(SubscriptionService.daysRemaining(b)),
      );

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                decoration: const BoxDecoration(
                  gradient: AppColors.violetGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('اشتراكات تستحقّ التجديد خلال 7 أيام'),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: due.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          tr(
                            'لا يوجد اشتراك يستحقّ التجديد خلال الأيام السبعة القادمة.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12.5,
                            height: 1.7,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                        itemCount: due.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = due[i];
                          final d = SubscriptionService.daysRemaining(s);
                          return Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: d <= 2
                                    ? AppColors.warning.withValues(alpha: 0.5)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: (d <= 2
                                            ? AppColors.warning
                                            : AppColors.info)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    d <= 2 ? Icons.warning_amber : Icons.schedule,
                                    size: 15,
                                    color: d <= 2
                                        ? AppColors.warning
                                        : AppColors.info,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${s['customer_name']}',
                                        style: TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        trf(
                                          '{0} ر.س — يغطي حتى {1}',
                                          [
                                            '${s['amount'] ?? 0}',
                                            DateFormat('yyyy-MM-dd').format(
                                              SubscriptionService.paidUntil(s),
                                            ),
                                          ],
                                        ),
                                        style: TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                LabelChip(
                                  text: d == 0
                                      ? tr('اليوم')
                                      : trf('بعد {0} يوم', ['$d']),
                                  color: d <= 2
                                      ? AppColors.warning
                                      : AppColors.info,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }

  /// حوار دراسة نهاية الشهر — ملخص كامل للاشتراكات
  void _showStudyDialog(SubscriptionsController controller) {
    final rows = controller.monthStudy();
    double totalPaid = 0;
    int totalPieces = 0;
    for (final r in rows) {
      totalPaid += (r['paid_this_month'] ?? 0).toDouble();
      totalPieces += (r['pieces'] ?? 0) as int;
    }

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assessment,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trf('دراسة نهاية الشهر — {0}', [
                          DateFormat('yyyy-MM').format(DateTime.now()),
                        ]),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // الملخص
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Row(
                  children: [
                    _MiniStat(
                      label: tr('اشتراكات نشطة'),
                      value: '${rows.length}',
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: tr('قطع الغسيل'),
                      value: '$totalPieces',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: tr('مدفوع هذا الشهر'),
                      value: totalPaid.toStringAsFixed(0),
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              const Divider(height: 18),
              // الجدول
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          tr('لا توجد اشتراكات نشطة'),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final statusRaw = r['status'] as String;
                          final overdue =
                              statusRaw == SubStatus.overdue.code ||
                              statusRaw == SubStatus.overdue.label;
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: overdue
                                    ? AppColors.danger.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${r['customer_name']}',
                                        style: TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    LabelChip(
                                      text: tr(r['status'] as String),
                                      color: overdue
                                          ? AppColors.danger
                                          : AppColors.success,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  trf(
                                    'الاشتراك: {0} ر.س / {1} يوم — يغطي حتى {2}',
                                    [
                                      r['price'].toStringAsFixed(0),
                                      '${r['period_days']}',
                                      DateFormat('yyyy-MM-dd').format(
                                        r['paid_until'] as DateTime,
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trf(
                                    'قطع الغسيل: {0} قطعة — مدفوع هذا الشهر: {1} ر.س',
                                    [
                                      '${r['pieces']}',
                                      r['paid_this_month'].toStringAsFixed(2),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if ('${r['top_pieces']}'.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    trf('الأصناف: {0}', ['${r['top_pieces']}']),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }

  // ═══════════ دراسة مشترك: فواتيره كاملة + مقارنة المدفوع بالقيمة ═══════════
  // (static — تُستدعى من بطاقة _SubscriptionCard)
  static Future<void> showSubscriberStudyDialog(
    SubscriptionsController controller,
    Map<String, dynamic> sub,
  ) async {
    final study = await controller.subscriberStudy(sub);
    final invoices = study['invoices'] as List<Map<String, dynamic>>;
    final itemsValue = (study['items_value'] as double);
    final paid = (study['paid_this_month'] as double);
    final price = (study['price'] as double);
    final diff = (study['difference'] as double);

    if (!Get.isRegistered<SubscriptionsController>()) return;
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                decoration: const BoxDecoration(
                  gradient: AppColors.violetGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_search, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trf(
                          'دراسة: {0} — {1}',
                          [
                            '${study['customer_name']}',
                            DateFormat('yyyy-MM').format(DateTime.now()),
                          ],
                        ),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Row(
                  children: [
                    _MiniStat(
                      label: tr('قيمة غسيله'),
                      value: itemsValue.toStringAsFixed(0),
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: tr('مدفوع'),
                      value: paid.toStringAsFixed(0),
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: diff >= 0 ? tr('نسبة لنا') : tr('علينا'),
                      value: diff.abs().toStringAsFixed(0),
                      color: diff >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  trf(
                    'الاشتراك: {0} ر.س — {1} فاتورة هذا الشهر، قيمة غسيله الفعلية {2} ر.س (التغطية: {0} ر.س)',
                    [
                      price.toStringAsFixed(0),
                      '${invoices.length}',
                      itemsValue.toStringAsFixed(2),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Divider(height: 18),
              Flexible(
                child: invoices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          tr('لا توجد فواتير مرتبطة بهذا الاشتراك هذا الشهر'),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final inv = invoices[i];
                          final value = (inv['_value'] as double? ?? 0);
                          final pieces = (inv['_pieces'] as int? ?? 0);
                          List items = [];
                          try {
                            items = inv['list_data']?.toString().isNotEmpty == true
                                ? (jsonDecode(inv['list_data'].toString()) as List)
                                : [];
                          } catch (_) {}
                          return Container(
                            padding: const EdgeInsets.all(10),
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
                                      trf(
                                        'فاتورة #{0}',
                                        ['${inv['invoices_id']}'],
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      trf(
                                        '{0} قطعة — {1} ر.س',
                                        [
                                          '$pieces',
                                          value.toStringAsFixed(2),
                                        ],
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ],
                                ),
                                if (items.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  ...items.map(
                                    (it) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 2,
                                      ),
                                      child: Text(
                                        '${trf(
                                          '• {0} ({1}) × {2} = {3} ر.س',
                                          [
                                            localized(it, 'vestments'),
                                            localized(it, 'content'),
                                            '${it['count']}',
                                            '${it['total_price']}',
                                          ],
                                        )}${'${it['note'] ?? ''}'.trim().isNotEmpty ? '  📝 ${it['note']}' : ''}',
                                        style: TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 10.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }

  void _showAddDialog(SubscriptionsController controller) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '50');
    final periodCtrl = TextEditingController(text: '30');
    // سقف الاستخدام (اختياري) — القطع والقيمة معاً، ويُطبَّق أيهما ينفد أولاً
    final limitPiecesCtrl = TextEditingController();
    final limitValueCtrl = TextEditingController();
    int? selectedId;
    String selectedName = '';

    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('إضافة اشتراك شهري'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              // اختيار الزبون
              DropdownButtonFormField<int>(
                initialValue: selectedId,
                isExpanded: true,
                hint: Text(
                  tr('اختر الزبون...'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                ),
                items:
                    controller.customers
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['customer_id'],
                            child: Text(
                              '${c['customer_name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  selectedId = v;
                  final c = controller.customers.firstWhere(
                    (x) => x['customer_id'] == v,
                  );
                  selectedName = c['customer_name']?.toString() ?? '';
                  nameCtrl.text = selectedName;
                },
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_search,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: tr('اسم الزبون (من السجل)'),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: tr('المبلغ الشهري (ر.س)'),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.payments, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: periodCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('المدة بالأيام'),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.calendar_month, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: limitPiecesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('سقف القطع (اختياري)'),
                        helperText: tr('0 = بلا حدود'),
                        helperStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                        ),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.checkroom, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: limitValueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: tr('سقف القيمة (اختياري)'),
                        helperText: tr('0 = بلا حدود'),
                        helperStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                        ),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.speed, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        tr('إلغاء'),
                        style: const TextStyle(fontFamily: 'cairo'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () async {
                        if (selectedId == null) {
                          Get.snackbar(
                            tr('تنبيه'),
                            tr('يجب اختيار زبون من سجل الزبائن'),
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColors.warning,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        final amount =
                            double.tryParse(
                              amountCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        final period = int.tryParse(periodCtrl.text) ?? 30;
                        if (amount <= 0) {
                          Get.snackbar(
                            tr('تنبيه'),
                            tr('أدخل مبلغاً صحيحاً'),
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColors.warning,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        await controller.addSubscription(
                          customerId: selectedId!,
                          customerName:
                              selectedName.isEmpty
                                  ? nameCtrl.text.trim()
                                  : selectedName,
                          amount: amount,
                          periodDays: period,
                          usageLimitPieces:
                              int.tryParse(limitPiecesCtrl.text.trim()) ?? 0,
                          usageLimitValue:
                              double.tryParse(
                                limitValueCtrl.text.replaceAll(',', '.'),
                              ) ??
                              0,
                        );
                        Get.back();
                      },
                      child: Text(
                        tr('إضافة الاشتراك'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
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
              value,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionsController controller;
  final Map<String, dynamic> sub;
  const _SubscriptionCard({required this.controller, required this.sub});

  @override
  Widget build(BuildContext context) {
    final amount = (sub['amount'] ?? 0).toDouble();
    final days = controller.daysRemaining(sub);
    final status = SubscriptionService.statusOf(
      sub,
      usedPieces: (sub['pieces_count'] as num?)?.toInt(),
      usedValue: (sub['used_value'] as num?)?.toDouble(),
    );
    final overdue = status == SubStatus.overdue || status == SubStatus.pending;
    final statusColor = switch (status) {
      SubStatus.active => days <= 7 ? AppColors.warning : AppColors.success,
      SubStatus.capped => AppColors.warning,
      SubStatus.overdue => AppColors.danger,
      SubStatus.pending => AppColors.slate,
      SubStatus.cancelled => AppColors.textMuted,
    };
    final statusText = switch (status) {
      SubStatus.pending => tr('لم يُسدد بعد'),
      SubStatus.overdue => tr('متأخر عن السداد'),
      SubStatus.capped => tr('استُهلك السقف'),
      SubStatus.active =>
        days <= 7
            ? trf('سداد قريب ({0} يوم)', ['$days'])
            : trf('نشط ({0} يوم)', ['$days']),
      SubStatus.cancelled => tr('ملغى'),
    };

    final ratio = (sub['usage_ratio'] as num?)?.toDouble() ?? 0;
    final limitP = SubscriptionService.limitPieces(sub);
    final limitV = SubscriptionService.limitValue(sub);
    final usedP = (sub['pieces_count'] as num?)?.toInt() ?? 0;
    final usedV = (sub['used_value'] as num?)?.toDouble() ?? 0;
    final hasLimit = limitP > 0 || limitV > 0;

    return SoftCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_membership,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sub['customer_name']}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      trf(
                        'اشتراك #{0} — {1} ر.س / {2} يوم',
                        [
                          '${sub['subscription_id']}',
                          '$amount',
                          '${sub['period_days']}',
                        ],
                      ),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              LabelChip(
                text: statusText,
                color: statusColor,
                icon: overdue ? Icons.error_outline : Icons.verified_user,
              ),
            ],
          ),
          if (sub['notes'] != null && '${sub['notes']}'.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              localized(sub, 'notes'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // ─── قطع الغسيل ودفعات الشهر ───
          Container(
            width: double.infinity,
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
                    const Icon(
                      Icons.local_laundry_service,
                      size: 14,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasLimit && limitP > 0
                            ? trf('استهلاك الدورة: {0} قطعة / {1}', [
                                '$usedP',
                                '$limitP',
                              ])
                            : trf('استهلاك الدورة: {0} قطعة', ['$usedP']),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (limitV > 0)
                      Text(
                        trf('{0} / {1} ر.س', [
                          usedV.toStringAsFixed(0),
                          limitV.toStringAsFixed(0),
                        ]),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.violet,
                        ),
                      ),
                  ],
                ),
                // ─── شريط السقف: يُظهر للكاشير كم بقي قبل المنع ───
                if (hasLimit) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                        ratio >= 1
                            ? AppColors.danger
                            : ratio >= 0.8
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ratio >= 1
                        ? tr(
                            'السقف مستهلك بالكامل — لن تُقبل فاتورة جديدة إلا بموافقة مدير أو تجديد',
                          )
                        : trf('استُهلك {0}% من السقف', [
                            '${(ratio * 100).round()}',
                          ]),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 9.5,
                      fontWeight: ratio >= 0.8
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: ratio >= 0.8
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('بلا سقف استخدام — يُنصح بتحديد حدّ'),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.payments,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trf('مدفوع هذا الشهر: {0} ر.س', [
                          (sub['paid_this_month'] ?? 0).toStringAsFixed(2),
                        ]),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (status == SubStatus.active ||
                        status == SubStatus.capped)
                      Text(
                        trf('حتى {0}', [
                          DateFormat(
                            'yyyy-MM-dd',
                          ).format(SubscriptionService.paidUntil(sub)),
                        ]),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.info,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ─── فواتير المشترك هذا الشهر (تُحفظ بأسعارها داخلياً) ───
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.violet.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 14,
                        color: AppColors.violet,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trf(
                            'فواتير هذا الشهر: {0} بقيمة {1} ر.س (محفوظة داخلياً — تُطبع بدون أسعار)',
                            [
                              '${sub['invoices_count'] ?? 0}',
                              (sub['invoices_value'] ?? 0).toStringAsFixed(0),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.violet,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: tr('فواتير ودراسة'),
                  icon: Icons.assessment_outlined,
                  color: AppColors.info,
                  onTap: () => SubscriptionsScreen.showSubscriberStudyDialog(
                    controller,
                    sub,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: tr('تسجيل دفعة'),
                  icon: Icons.payment_rounded,
                  color: AppColors.success,
                  onTap: () => _showPaymentDialog(controller, sub),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: tr('السقف'),
                  icon: Icons.speed,
                  color: AppColors.violet,
                  onTap: () => _showLimitsDialog(controller, sub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: tr('إلغاء بتسوية'),
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                  onTap: () => _confirmCancel(controller, sub),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// حوار تعديل سقف الاستخدام — قرار إداري يحتاج صلاحية وأثرًا تدقيقيًا.
  void _showLimitsDialog(SubscriptionsController controller, sub) {
    if (!SessionManager.isManager) {
      Get.snackbar(
        tr('صلاحية غير كافية'),
        tr('تعديل سقف الاستخدام قرار إداري — لا يملكه إلا مدير.'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final piecesCtrl = TextEditingController(
      text: SubscriptionService.limitPieces(sub) > 0
          ? '${SubscriptionService.limitPieces(sub)}'
          : '',
    );
    final valueCtrl = TextEditingController(
      text: SubscriptionService.limitValue(sub) > 0
          ? SubscriptionService.limitValue(sub).toStringAsFixed(0)
          : '',
    );

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trf('سقف الاستخدام — {0}', ['${sub['customer_name']}']),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'السقف يحمي من اشتراك صغير يستهلك غسيلًا بلا حدّ. اتركه فارغًا أو صفرًا لإلغاء السقف. يُطبَّق أيّهما استُنفد أولًا.',
                ),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10.5,
                  height: 1.65,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: piecesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('سقف القطع'),
                        hintText: tr('مثال: 50'),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.checkroom, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: tr('سقف القيمة (ر.س)'),
                        hintText: tr('مثال: 150'),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.attach_money, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trf('الحالي: {0} — {1}', [
                    SubscriptionService.limitPieces(sub) > 0
                        ? trf('{0} قطعة', [
                            '${SubscriptionService.limitPieces(sub)}',
                          ])
                        : tr('بلا سقف قطع'),
                    SubscriptionService.limitValue(sub) > 0
                        ? trf('{0} ر.س', [
                            SubscriptionService.limitValue(
                              sub,
                            ).toStringAsFixed(0),
                          ])
                        : tr('بلا سقف قيمة'),
                  ]),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        tr('إلغاء'),
                        style: const TextStyle(fontFamily: 'cairo'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.violet,
                      ),
                      onPressed: () async {
                        final p = int.tryParse(piecesCtrl.text.trim()) ?? 0;
                        final v =
                            double.tryParse(
                              valueCtrl.text.replaceAll(',', '.').trim(),
                            ) ??
                            0;
                        await controller.updateUsageLimits(
                          subscriptionId: sub['subscription_id'] as int,
                          limitPieces: p < 0 ? 0 : p,
                          limitValue: v < 0 ? 0 : v,
                        );
                        if (Get.isDialogOpen == true) Get.back();
                        Get.snackbar(
                          tr('تم التحديث'),
                          trf('سقف الاستخدام: {0} — {1}', [
                            p > 0 ? trf('{0} قطعة', ['$p']) : tr('بلا سقف قطع'),
                            v > 0
                                ? trf('{0} ر.س', [v.toStringAsFixed(0)])
                                : tr('بلا سقف قيمة'),
                          ]),
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.success,
                          colorText: Colors.white,
                        );
                      },
                      child: Text(
                        tr('حفظ السقف'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }

  /// تأكيد الإلغاء **بتسوية**: عرض قيمة الأيام غير المُقدَّمة وطريقة ردّها.
  ///
  /// الإلغاء السابق كان مجرد `is_active = 0`: المبلغ المدفوع مقابل خدمة لن
  /// تُقدَّم يبقى مسجَّلًا بلا تسوية. الآن يُحسب ويُعاد رصيدًا أو نقدًا.
  void _confirmCancel(SubscriptionsController controller, sub) {
    final remaining = controller.daysRemaining(sub);
    final price = (sub['amount'] ?? 0).toDouble();
    final periodDays = ((sub['period_days'] ?? 30) as num).toInt();
    final days = periodDays <= 0 ? 30 : periodDays;
    final refund = remaining > 0 && price > 0
        ? (price / days) * remaining
        : 0.0;
    bool refundAsCredit = true;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.danger,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trf('إلغاء بتسوية — {0}', [
                            '${sub['customer_name']}',
                          ]),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (refund > 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('قيمة الأيام غير المُقدَّمة'),
                                  style: const TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                trf('{0} ر.س', [refund.toStringAsFixed(2)]),
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            trf(
                              'متبقٍّ {0} يوم من أصل {1} — {2} ر.س/يوم. هذا المبلغ مقابل خدمة لن تُقدَّم، فلا يصحّ أن يبقى إيرادًا للمحل.',
                              [
                                '$remaining',
                                '$days',
                                (price / days).toStringAsFixed(2),
                              ],
                            ),
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 10.5,
                              height: 1.65,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('طريقة التسوية'),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _settlementOption(
                      title: tr('رصيد لدى المحل (مُوصى به)'),
                      subtitle: tr(
                        'يبقى في الدرج كسلفة للزبون، ويُخصم تلقائيًا من فواتيره القادمة. لا يُخرج نقدية.',
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      selected: refundAsCredit,
                      color: AppColors.success,
                      onTap: () => setState(() => refundAsCredit = true),
                    ),
                    const SizedBox(height: 6),
                    _settlementOption(
                      title: tr('استرداد نقدي'),
                      subtitle: tr(
                        'يُخرج المبلغ من الدرج ويُسجَّل في المصروفات، فيظهر في إقفال الوردية.',
                      ),
                      icon: Icons.payments_outlined,
                      selected: !refundAsCredit,
                      color: AppColors.danger,
                      onTap: () => setState(() => refundAsCredit = false),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        remaining <= 0
                            ? tr(
                                'لا توجد أيام مدفوعة متبقّية — الإلغاء تعطيل بسيط بلا استرداد.',
                              )
                            : tr(
                                'سعر الاشتراك صفر — لا يمكن احتساب قيمة أيام للتسوية.',
                              ),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          height: 1.65,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          child: Text(
                            tr('تراجع'),
                            style: const TextStyle(fontFamily: 'cairo'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () async {
                            final result = await controller.cancel(
                              sub['subscription_id'] as int,
                              refundAsCredit: refundAsCredit,
                              reason: tr('إلغاء من شاشة الاشتراكات'),
                            );
                            if (Get.isDialogOpen == true) Get.back();
                            Get.snackbar(
                              tr('تم الإلغاء'),
                              result.hasRefund
                                  ? trf(
                                      'أُعيد {0} ر.س {1} عن {2} يوم غير مُقدَّم.',
                                      [
                                        result.refundedAmount.toStringAsFixed(
                                          2,
                                        ),
                                        result.refundAsCredit
                                            ? tr('رصيدًا لدى المحل')
                                            : tr('نقدًا'),
                                        '${result.remainingDays}',
                                      ],
                                    )
                                  : tr('عُطِّل الاشتراك بلا استرداد.'),
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.success,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 5),
                            );
                          },
                          child: Text(
                            tr('تأكيد الإلغاء'),
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierColor: Colors.black54,
    );
  }

  Widget _settlementOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.07)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: selected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 9.5,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 17,
              color: selected ? color : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── حوار تسجيل دفعة ───────────────────────

  void _showPaymentDialog(SubscriptionsController controller, sub) {
    final price = (sub['amount'] ?? 0).toDouble();
    final amountCtrl = TextEditingController(text: price.toStringAsFixed(2));
    String method = PaymentMethod.cash.key;
    String notes = '';

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: StatefulBuilder(
          builder: (context, setState) {
            void setAmount(double v) {
              setState(() {
                amountCtrl.text = v.toStringAsFixed(2);
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trf('تسجيل دفعة — {0}', ['${sub['customer_name']}']),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trf(
                        'الاشتراك: {0} ر.س / {1} يوم — التغطية الحالية حتى {2}',
                        [
                          '$price',
                          '${sub['period_days']}',
                          DateFormat(
                            'yyyy-MM-dd',
                          ).format(controller.paidUntil(sub)),
                        ],
                      ),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('مبلغ الدفعة (ر.س)'),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickAmtChip(
                          label: trf('ربع ({0})', [
                            (price * 0.25).toStringAsFixed(0),
                          ]),
                          onTap: () => setAmount(price * 0.25),
                        ),
                        _QuickAmtChip(
                          label: trf('نصف ({0})', [
                            (price * 0.5).toStringAsFixed(0),
                          ]),
                          onTap: () => setAmount(price * 0.5),
                        ),
                        _QuickAmtChip(
                          label: trf('ثلاثة أرباع ({0})', [
                            (price * 0.75).toStringAsFixed(0),
                          ]),
                          onTap: () => setAmount(price * 0.75),
                        ),
                        _QuickAmtChip(
                          label: trf('كامل ({0})', [price.toStringAsFixed(0)]),
                          selected: true,
                          onTap: () => setAmount(price),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.payments, size: 18),
                        labelStyle: const TextStyle(fontFamily: 'cairo'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('طريقة الدفع'),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MethodChip(
                          label: PaymentMethod.cash.label,
                          selected: method == PaymentMethod.cash.key,
                          onTap: () =>
                              setState(() => method = PaymentMethod.cash.key),
                        ),
                        const SizedBox(width: 8),
                        _MethodChip(
                          label: PaymentMethod.card.label,
                          selected: method == PaymentMethod.card.key,
                          onTap: () =>
                              setState(() => method = PaymentMethod.card.key),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => notes = v,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: tr('ملاحظة (اختياري)'),
                        labelStyle: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(Icons.sticky_note_2, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Get.back(),
                      child: Text(
                        tr('إلغاء'),
                        style: const TextStyle(fontFamily: 'cairo'),
                      ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            onPressed: () async {
                              final amt =
                                  double.tryParse(
                                    amountCtrl.text.replaceAll(',', '.'),
                                  ) ??
                                  0;
                              if (amt <= 0) {
                                Get.snackbar(
                                  tr('تنبيه'),
                                  tr('أدخل مبلغاً صحيحاً أكبر من صفر'),
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: AppColors.warning,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              final until = await controller.pay(
                                sub: sub,
                                amount: amt,
                                method: method,
                                notes: notes.trim().isEmpty ? null : notes.trim(),
                              );
                              if (context.mounted) Get.back();
                              Get.snackbar(
                                tr('تم تسجيل الدفعة'),
                                trf(
                                  '{0} ر.س — التغطية حتى {1}',
                                  [
                                    '$amt',
                                    DateFormat('yyyy-MM-dd').format(until),
                                  ],
                                ),
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.success,
                                colorText: Colors.white,
                              );
                            },
                            child: Text(
                              tr('تسجيل الدفعة'),
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      barrierColor: Colors.black54,
    );
  }
}

class _QuickAmtChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;
  const _QuickAmtChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.success : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.8 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: [
                Icon(icon, color: Colors.white, size: 15),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
