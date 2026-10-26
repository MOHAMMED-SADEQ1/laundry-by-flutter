import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// `intl` يصدّر TextDirection خاصته فيتعارض مع appTextDirection في Flutter،
// لذلك نُخفي نسخته ونستورد الرموز المطلوبة صراحةً.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/controller/customer/debt_report_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/customer/debt_reminder_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/customer/debt_report_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/customer/customer_statement_sheet.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// تقرير أعمار الديون (Aging Report).
///
/// **القيمة المحاسبية**: يجيب على سؤال «منذ متى هذه الذمة؟» لا «كم فقط؟».
/// الذمة الحديثة تُحصَّل عادةً؛ أما المتقادمة فتتحوّل تدريجيًا إلى دَين
/// مشكوك في تحصيله ويُكوَّن لها مخصص. لذلك يُقسَّم كل مبلغ إلى فئة عمرية
/// مبنية على `invoice_date` الفعلي لكل فاتورة.
class DebtAgingScreen extends StatefulWidget {
  const DebtAgingScreen({super.key});

  @override
  State<DebtAgingScreen> createState() => _DebtAgingScreenState();
}

class _DebtAgingScreenState extends State<DebtAgingScreen> {
  final controller = Get.put(DebtReportController());

  final money = NumberFormat('#,##0.00', 'en');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            tr('أعمار الديون'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: tr('تحديث'),
              onPressed: () => controller.loadAging(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.loadingAging.value &&
              controller.agingRows.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = controller.filteredAging;
          if (controller.agingRows.isEmpty) {
            return _emptyState();
          }
          return RefreshIndicator(
            onRefresh: () => controller.loadAging(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _summaryHeader(),
                const SizedBox(height: 12),
                _provisionCard(),
                const SizedBox(height: 12),
                _searchField(),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        tr('لا زبون يطابق البحث'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  _agingTable(rows),
                const SizedBox(height: 16),
                _bucketLegend(),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ───────────────────────── الأجزاء ─────────────────────────

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 44,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr('لا توجد ذمم قائمة'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('كل فواتير الزبائن مسدّدة بالكامل'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// ترويسة الإجماليات: المبلغ الكلي + عدد المدينين + أكبر فئة متأخرة
  Widget _summaryHeader() {
    final s = controller.filteredSummary;
    final worstIndex = _worstBucketIndex(s.bucketTotals);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow(blur: 10, y: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white70, size: 17),
              const SizedBox(width: 6),
              Text(
                tr('إجمالي الذمم القائمة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12.5,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trf('{0} زبون · {1} فاتورة', [
                    '${s.debtorCount}',
                    '${s.openInvoiceCount}',
                  ]),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                money.format(s.grandTotal),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                tr('ر.س'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (worstIndex >= 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.trending_down,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    trf(
                      'أكبر تركيز: {0} ({1} ر.س — {2}%)',
                      [
                        tr(kAgingBuckets[worstIndex].label),
                        money.format(s.bucketTotals[worstIndex]),
                        (s.shareOf(worstIndex) * 100).toStringAsFixed(0),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// بطاقة المخصص المقترح للديون المشكوك في تحصيلها
  Widget _provisionCard() {
    final s = controller.filteredSummary;
    final rate = controller.provisionRate.value;
    final provision = s.proposedProvision(over90Rate: rate);
    final over90 = _over90Total(s.bucketTotals);

    if (over90 <= 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined,
                size: 18, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('لا ديون متأخرة أكثر من 90 يومًا — لا حاجة لمخصص'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('المخصص المقترح للديون المشكوك في تحصيلها'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                trf('{0} ر.س', [money.format(provision)]),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trf(
              tr('على المتأخر أكثر من 90 يومًا ({0} ر.س) بنسبة {1}% — سياسة تحفّظية قابلة للتعديل من إعداد «نسبة مخصص الديون».'),
              [
                money.format(over90),
                (rate * 100).toStringAsFixed(0),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => controller.searchQuery.value = v,
      style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
      decoration: InputDecoration(
        hintText: tr('ابحث باسم الزبون أو رقم الجوال…'),
        hintStyle: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 12.5,
          color: AppColors.textMuted,
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  /// جدول الأعمار — أعمدة لكل فئة عمرية + الإجمالي، مرتّب بالأقدم ذمة.
  Widget _agingTable(List<CustomerAgingRow> rows) {
    final s = controller.filteredSummary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow(blur: 8, y: 3),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 22,
                  child: Text(
                    tr('الزبون'),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                for (final b in kAgingBuckets)
                  Expanded(
                    flex: 14,
                    child: Text(
                      b.maxDays == null
                          ? '‎+90'
                          : '${b.minDays}-${b.maxDays! - 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 16,
                  child: Text(
                    tr('الإجمالي'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 34),
              ],
            ),
          ),
          ...rows.map((r) => _agingRow(r)),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 22,
                  child: Text(
                    tr('الإجمالي'),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                for (final t in s.bucketTotals)
                  Expanded(
                    flex: 14,
                    child: Text(
                      t > 0 ? money.format(t) : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: t > 0
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 16,
                  child: Text(
                    money.format(s.grandTotal),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 34),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _agingRow(CustomerAgingRow r) {
    final riskColor = _riskColor(r.riskLevel);
    return InkWell(
      onTap: () => _showCustomerDetails(r),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr(r.riskLevel),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        trf('أقدم {0} يوم', ['${r.oldestDays ?? 0}']),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < kAgingBuckets.length; i++)
              Expanded(
                flex: 14,
                child: Text(
                  r.bucketAmounts[i] > 0
                      ? money.format(r.bucketAmounts[i])
                      : '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    color: r.bucketAmounts[i] > 0
                        ? _bucketColor(i)
                        : AppColors.textMuted,
                    fontWeight: r.bucketAmounts[i] > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            Expanded(
              flex: 16,
              child: Text(
                money.format(r.totalDebt),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: tr('دفعة سريعة'),
                onPressed: () => _quickPayDialog(r),
                icon: const Icon(Icons.payments_outlined,
                    size: 17, color: AppColors.success),
              ),
            ),
            SizedBox(
              width: 34,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: tr('كشف حساب (طباعة/إرسال)'),
                onPressed: () => showCustomerStatementSheet(
                  context,
                  r.customerId,
                  customerName: r.customerName,
                ),
                icon: const Icon(Icons.receipt_long,
                    size: 16, color: AppColors.info),
              ),
            ),
            SizedBox(
              width: 34,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: tr('مطالبة واتساب'),
                onPressed: () => DebtReminderService.sendReminder(r),
                icon: const Icon(Icons.chat,
                    size: 16, color: Color(0xFF25D366)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// دليل ألوان الفئات — يجعل الأعمدة مفهومة دون حفظ الأرقام
  Widget _bucketLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('دلالة الفئات العمرية'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _legendItem(
                kAgingBuckets[0].label,
                tr('ذمة حديثة — متابعة عادية'),
                AppColors.success,
              ),
              _legendItem(
                kAgingBuckets[1].label,
                tr('تأخر مبدئي — تذكير أول'),
                AppColors.info,
              ),
              _legendItem(
                kAgingBuckets[2].label,
                tr('تأخر مقلق — مطالبة جدّية'),
                AppColors.warning,
              ),
              _legendItem(
                kAgingBuckets[3].label,
                tr('مشكوك في تحصيله — يُكوَّن مخصص'),
                AppColors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String title, String subtitle, Color color) {
    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
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
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── الحوارات ─────────────────────────

  /// تفاصيل الزبون: فواتيره المفتوحة بأعمارها + إجراءات سريعة
  Future<void> _showCustomerDetails(CustomerAgingRow row) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerDebtSheet(
        row: row,
        onQuickPay: () {
          Navigator.pop(context);
          _quickPayDialog(row);
        },
      ),
    );
  }

  /// دفعة سريعة: تُسجَّل في الدفتر أولًا ثم تُوزَّع FIFO
  Future<void> _quickPayDialog(CustomerAgingRow row) async {
    final ctrl = TextEditingController(
      text: row.totalDebt.toStringAsFixed(2),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.payments, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trf('دفعة من {0}', [row.customerName]),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      tr('الذمة القائمة:'),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      trf('{0} ر.س', [money.format(row.totalDebt)]),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: tr('المبلغ المستلَم'),
                  labelStyle: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                  ),
                  suffixText: tr('ر.س'),
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'يُوزَّع المبلغ على الفواتير الأقدم أولًا، وأي فائض يصبح رصيدًا دائنًا للزبون (سلفة).',
                ),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in [0.25, 0.5, 1.0])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ActionChip(
                        label: Text(
                          p == 1.0
                              ? tr('سداد كامل')
                              : '${(p * 100).toInt()}%',
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                          ),
                        ),
                        onPressed: () {
                          ctrl.text =
                              (row.totalDebt * p).toStringAsFixed(2);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                tr('إلغاء'),
                style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                tr('تسجيل الدفعة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      ctrl.dispose();
      return;
    }

    final amount = double.tryParse(ctrl.text.trim()) ?? 0;
    ctrl.dispose();

    if (amount <= 0) {
      Get.snackbar(
        tr('تنبيه'),
        tr('أدخل مبلغًا صحيحًا أكبر من صفر'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    final ok = await controller.recordQuickPayment(
      customerId: row.customerId,
      amount: amount,
      userId: SessionManager.currentUserId,
    );

    Get.snackbar(
      ok ? tr('تمت العملية') : tr('فشل'),
      ok
          ? trf('سُجّلت دفعة {0} ر.س من {1}', [
              money.format(amount),
              row.customerName,
            ])
          : tr('تعذر تسجيل الدفعة — أعد المحاولة'),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      colorText: Colors.white,
      icon: Icon(
        ok ? Icons.check_circle : Icons.error,
        color: Colors.white,
      ),
    );
  }

  // ───────────────────────── مساعدات اللون ─────────────────────────

  static int _worstBucketIndex(List<double> totals) {
    var idx = -1;
    var max = 0.0;
    for (var i = 0; i < totals.length; i++) {
      if (totals[i] > max) {
        max = totals[i];
        idx = i;
      }
    }
    return idx;
  }

  static double _over90Total(List<double> totals) {
    var sum = 0.0;
    for (var i = 0; i < kAgingBuckets.length && i < totals.length; i++) {
      if (kAgingBuckets[i].minDays >= 91) sum += totals[i];
    }
    return sum;
  }

  static Color _bucketColor(int index) {
    switch (index) {
      case 0:
        return AppColors.success;
      case 1:
        return AppColors.info;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  static Color _riskColor(String risk) {
    switch (risk) {
      case 'مشكوك في تحصيله':
        return AppColors.danger;
      case 'مرتفع':
        return AppColors.warning;
      case 'متوسط':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }
}

/// لوحة تفاصيل ذمة الزبون: فواتيره المفتوحة بأعمارها وعدد أيامها.
class _CustomerDebtSheet extends StatefulWidget {
  final CustomerAgingRow row;
  final VoidCallback onQuickPay;

  const _CustomerDebtSheet({required this.row, required this.onQuickPay});

  @override
  State<_CustomerDebtSheet> createState() => _CustomerDebtSheetState();
}

class _CustomerDebtSheetState extends State<_CustomerDebtSheet> {
  final _db = _DbProxy();
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  final money = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.openInvoicesOf(widget.row.customerId);
    if (!mounted) return;
    setState(() {
      _invoices = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.receipt_long,
                        size: 19, color: AppColors.danger),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.row.customerName,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          trf(
                            '{0} فاتورة مفتوحة · أقدمها {1} يوم',
                            [
                              '${widget.row.openInvoices}',
                              '${widget.row.oldestDays ?? 0}',
                            ],
                          ),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    trf('{0} ر.س', [
                      money.format(widget.row.totalDebt),
                    ]),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _invoices.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _invoiceTile(_invoices[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        DebtReminderService.sendReminder(widget.row);
                      },
                      icon: const Icon(Icons.chat, size: 17),
                      label: Text(
                        tr('مطالبة واتساب'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: widget.onQuickPay,
                      icon: const Icon(Icons.payments,
                          color: Colors.white, size: 18),
                      label: Text(
                        tr('تسجيل دفعة'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceTile(Map<String, dynamic> inv) {
    final id = inv['invoices_id'];
    final due = ((inv['remaining_amount'] ?? 0) as num).toDouble();
    final date = _parse(inv['invoice_date']);
    final days = date == null ? 0 : _daysSince(date);
    final color = days >= 91
        ? AppColors.danger
        : days >= 61
            ? AppColors.warning
            : days >= 31
                ? AppColors.info
                : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trf('فاتورة #{0}', ['$id']),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? tr('تاريخ غير معروف')
                      : trf('{0} · منذ {1} يوم', [
                          DateFormat('yyyy/MM/dd').format(date),
                          '$days',
                        ]),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trf('{0} ر.س', [money.format(due)]),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// أيام كاملة بين تاريخ واليوم — نفس قاعدة الخدمة ليتوافق العرض مع الحساب
int _daysSince(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final then = DateTime(date.year, date.month, date.day);
  return today.difference(then).inDays;
}

/// قراءة تاريخ مرن
DateTime? _parse(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) ?? DateTime.tryParse(text.split(' ').first);
}

/// قراءة الفواتير المفتوحة لزبون — تُستخدم في لوحة تفاصيل الذمة.
class _DbProxy {
  final SqlDB _db = SqlDB();

  Future<List<Map<String, dynamic>>> openInvoicesOf(int customerId) async {
    try {
      return await _db.readData(
        'SELECT invoices_id, remaining_amount, invoice_date, final_amount,        paid_amount FROM invoices WHERE customer_id = ? AND subscription_id IS NULL   AND COALESCE(remaining_amount, 0) > 0.004 ORDER BY invoice_date ASC',
        [customerId],
      );
    } catch (_) {
      return [];
    }
  }
}
