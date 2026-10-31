import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:laundry/controller/reports/report_controller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ReportController());

    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              tr('التقارير'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
              ),
              tabs: [
                Tab(text: tr('يومي')),
                Tab(text: tr('أسبوعي')),
                Tab(text: tr('شهري')),
                Tab(text: tr('سنوي')),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _DailyTab(controller: controller),
              _WeeklyTab(controller: controller),
              _MonthlyTab(controller: controller),
              _AnnualTab(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة ملخص النتائج المشتركة
Widget _summaryCards({
  required double sales,
  required double profit,
  required int invoices,
  required double average,
  double subscriptions = 0,
  double cost = 0,
  double customerCredits = 0,
  double totalRemaining = 0,
  double expenses = 0,
  double grossProfit = 0,
  double tax = 0,
  bool showProfit = true,
  bool showTax = true,
}) {
  final cards = [
    _ReportStat(
      'المبيعات',
      sales,
      'ر.س',
      Icons.trending_up,
      AppColors.successGradient,
    ),
    // بطاقة الربح تُخفى كليًّا عمّن لا يملك `reports.profit` — لا تُعرض صفرًا.
    if (showProfit)
      _ReportStat(
        'صافي الربح',
        profit,
        'ر.س',
        Icons.savings,
        profit >= 0 ? AppColors.primaryGradient : AppColors.dangerGradient,
        // نُفصّل الأساس حتى يُعرف من أين جاء الرقم: ربح مساهم − مصروفات
        subtitle: expenses > 0
            ? trf('مساهم {0} − مصروفات {1}', [
                grossProfit.toStringAsFixed(2),
                expenses.toStringAsFixed(2),
              ])
            : (cost > 0
                  ? trf('بعد خصم تكلفة {0} ر.س', [cost.toStringAsFixed(2)])
                  : null),
      ),
    // المصروفات التشغيلية — كانت لا تُسجَّل أصلًا ولا تُخصم من الربح
    if (showProfit && expenses > 0)
      _ReportStat(
        'المصروفات',
        expenses,
        'ر.س',
        Icons.payments_outlined,
        AppColors.dangerGradient,
        subtitle: tr('تُخصم من صافي الربح'),
      ),
    _ReportStat(
      'الفواتير',
      invoices.toDouble(),
      '',
      Icons.receipt_long,
      AppColors.amberGradient,
    ),
    _ReportStat(
      'متوسط الفاتورة',
      average,
      'ر.س',
      Icons.analytics,
      AppColors.violetGradient,
    ),
    _ReportStat(
      'إيراد الاشتراكات',
      subscriptions,
      'ر.س',
      Icons.card_membership,
      AppColors.inkGradient,
    ),
    if (totalRemaining > 0)
      _ReportStat(
        'ديون الزبائن',
        totalRemaining,
        'ر.س',
        Icons.account_balance,
        AppColors.dangerGradient,
      ),
    if (customerCredits > 0)
      _ReportStat(
        'أرصدة الزبائن (مدفوع زائد)',
        customerCredits,
        'ر.س',
        Icons.savings_outlined,
        AppColors.successGradient,
      ),
    // الضريبة المستحقة للهيئة — **ليست إيرادًا** بل التزام، وتُخصم من الربح.
    // تظهر فقط عند تفعيل الضريبة، فلا تزدحم التقارير ببطاقة صفر. وتُخفى عمّن
    // لا يملك `reports.tax` — الرقم التزام ضريبي لا معلومة تشغيلية عامة.
    if (showTax && tax > 0)
      _ReportStat(
        'ضريبة القيمة المضافة',
        tax,
        'ر.س',
        Icons.receipt_outlined,
        AppColors.inkGradient,
        subtitle: tr('مستحقة للهيئة — خارج الربح'),
      ),
  ];

  return LayoutBuilder(
    builder: (context, cons) {
      final cols = cons.maxWidth > 700 ? 4 : (cons.maxWidth > 400 ? 3 : 2);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.7,
        ),
        itemCount: cards.length,
        itemBuilder:
            (context, i) => FadeInUp(
              delayMs: i * 70,
              child: _ReportStatCard(stat: cards[i]),
            ),
      );
    },
  );
}

class _ReportStat {
  final String title;
  final double value;
  final String unit;
  final IconData icon;
  final Gradient gradient;

  /// سطر توضيحي صغير أسفل القيمة (مثال: تكلفة القطع المخصومة)
  final String? subtitle;
  const _ReportStat(
    this.title,
    this.value,
    this.unit,
    this.icon,
    this.gradient, {
    this.subtitle,
  });
}

class _ReportStatCard extends StatelessWidget {
  final _ReportStat stat;
  const _ReportStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: stat.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow(blur: 8, y: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat.icon, size: 17, color: Colors.white),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  tr(stat.title),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (stat.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tr(stat.subtitle!),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            '${stat.value.toStringAsFixed(2)} ${tr(stat.unit)}'.trim(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// صف اختيار التاريخ
Widget _datePickerRow({required String label, required VoidCallback onTap}) {
  return SoftCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.calendar_today,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('الفترة المحددة'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.edit_calendar, color: AppColors.primary),
      ],
    ),
  );
}

/// جدول التفصيل
Widget _breakdownTable(Map<String, dynamic> report, String type) {
  List<dynamic> breakdown = [];
  if (report.containsKey('daily_breakdown')) {
    breakdown = report['daily_breakdown'] ?? [];
  } else if (report.containsKey('weekly_breakdown')) {
    breakdown = report['weekly_breakdown'] ?? [];
  } else if (report.containsKey('monthly_breakdown')) {
    breakdown = report['monthly_breakdown'] ?? [];
  }

  if (breakdown.isEmpty) return const SizedBox.shrink();

  return SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: trf('التفصيل — {0}', [tr(type)]),
          icon: Icons.table_chart_outlined,
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(2.2),
            2: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.surfaceSoft),
              children: [
                _TableHeaderCell(tr('التاريخ')),
                _TableHeaderCell(tr('المبيعات')),
                _TableHeaderCell(tr('الفواتير')),
              ],
            ),
            ...breakdown.map((row) {
              final label = row['day'] ?? row['week'] ?? row['month'] ?? '';
              final sales = (row['sales'] ?? 0).toDouble();
              final count = row['invoices'] ?? 0;
              return TableRow(
                children: [
                  _TableCell('$label', bold: true),
                  _TableCell(
                    trf('{0} ر.س', [sales.toStringAsFixed(2)]),
                    color: AppColors.success,
                  ),
                  _TableCell('$count'),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'cairo',
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  const _TableCell(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 11.5,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// مدخل تقارير الذمم: أعمار الديون + المطابقة ودفتر الأستاذ.
///
/// وُضعت في شاشة التقارير لأنها المكان الطبيعي الذي يبحث فيه المحاسب عن
/// تحليل الذمم — فلا يحتاج معرفة مسار مخفي.
Widget _debtReportsLauncher() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_wallet,
                size: 18, color: AppColors.danger),
            const SizedBox(width: 7),
            Text(
              tr('تحليل ذمم الزبائن'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr('أعمار الديون تكشف منذ متى الذمة، والمطابقة تكشف أي خلل في الأرصدة.'),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 10.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _debtLauncherTile(
                icon: Icons.timelapse,
                color: AppColors.warning,
                title: tr('أعمار الديون'),
                subtitle: tr('توزيع الذمم على فئات تأخر'),
                onTap: () => Get.toNamed(AppRoute.debtAging),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _debtLauncherTile(
                icon: Icons.fact_check_outlined,
                color: AppColors.info,
                title: tr('المطابقة والدفتر'),
                subtitle: tr('فحص الأرصدة وسجل الحركات'),
                onTap: () => Get.toNamed(AppRoute.debtReconciliation),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _debtLauncherTile({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 9.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

/// حقوق المطوّر — تُعرض أسفل كل تبويب تقارير (لا تدخل في الطباعة)
Widget _developerFooter() {
  return const DeveloperCredit(
    fontSize: 12,
    padding: EdgeInsets.symmetric(vertical: 18),
  );
}

Widget _printButton() {
  return GradientButton(
    label: tr('طباعة التقرير'),
    icon: Icons.print,
    gradient: AppColors.primaryGradient,
    onPressed: () {
      Get.snackbar(
        tr('ملاحظة'),
        tr('ميزة الطباعة قيد التطوير'),
        snackPosition: SnackPosition.BOTTOM,
      );
    },
  );
}

// ───────────────────────────── الأقسام الأربعة ─────────────────────────────

class _DailyTab extends StatefulWidget {
  final ReportController controller;
  const _DailyTab({required this.controller});

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.generateDailyReport(date: selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final report = widget.controller.dailyReport;
      if (report.isEmpty) {
        return EmptyState(
          icon: Icons.event_note_outlined,
          title: tr('اضغط لاختيار التاريخ'),
          subtitle: tr('اختر يوماً لعرض تقريره التفصيلي'),
        );
      }
      return RefreshIndicator(
        onRefresh:
            () async =>
                widget.controller.generateDailyReport(date: selectedDate),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _datePickerRow(
                label: DateFormat('yyyy-MM-dd').format(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                    widget.controller.generateDailyReport(date: picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              _summaryCards(
                sales: (report['total_sales'] ?? 0).toDouble(),
                profit: (report['net_profit'] ?? 0).toDouble(),
                cost: (report['total_cost'] ?? 0).toDouble(),
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
                totalRemaining: (report['total_remaining'] ?? 0).toDouble(),
                customerCredits: (report['customer_credits'] ?? 0).toDouble(),
                expenses: (report['expenses'] ?? 0).toDouble(),
                grossProfit: (report['gross_profit'] ?? 0).toDouble(),
                tax: (report['total_tax'] ?? 0).toDouble(),
                // 🛡️ `reports.profit` / `reports.tax` صارا مُنفَّذين: البطاقة
                // تُخفى هنا، والقيمة تُحجب في المتحكّم (`_guardMetrics`).
                showProfit: PermissionService.can(PermissionKeys.reportsProfit),
                showTax: PermissionService.can(PermissionKeys.reportsTax),
              ),
              const SizedBox(height: 12),
              _debtReportsLauncher(),
              const SizedBox(height: 12),
              _breakdownTable(report, 'يومي'),
              const SizedBox(height: 12),
              _printButton(),
              _developerFooter(),
            ],
          ),
        ),
      );
    });
  }
}

class _WeeklyTab extends StatefulWidget {
  final ReportController controller;
  const _WeeklyTab({required this.controller});

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.generateWeeklyReport(startDate: selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final report = widget.controller.weeklyReport;
      if (report.isEmpty) {
        return EmptyState(
          icon: Icons.date_range_outlined,
          title: tr('اضغط لاختيار الأسبوع'),
        );
      }
      return RefreshIndicator(
        onRefresh:
            () async =>
                widget.controller.generateWeeklyReport(startDate: selectedDate),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _datePickerRow(
                label:
                    '${report['start_date'] ?? ''} — ${report['end_date'] ?? ''}',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                    widget.controller.generateWeeklyReport(startDate: picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              _summaryCards(
                sales: (report['total_sales'] ?? 0).toDouble(),
                profit: (report['net_profit'] ?? 0).toDouble(),
                cost: (report['total_cost'] ?? 0).toDouble(),
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
                totalRemaining: (report['total_remaining'] ?? 0).toDouble(),
                customerCredits: (report['customer_credits'] ?? 0).toDouble(),
                expenses: (report['expenses'] ?? 0).toDouble(),
                grossProfit: (report['gross_profit'] ?? 0).toDouble(),
                tax: (report['total_tax'] ?? 0).toDouble(),
                // 🛡️ `reports.profit` / `reports.tax` صارا مُنفَّذين: البطاقة
                // تُخفى هنا، والقيمة تُحجب في المتحكّم (`_guardMetrics`).
                showProfit: PermissionService.can(PermissionKeys.reportsProfit),
                showTax: PermissionService.can(PermissionKeys.reportsTax),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'أسبوعي'),
              const SizedBox(height: 12),
              _printButton(),
              _developerFooter(),
            ],
          ),
        ),
      );
    });
  }
}

class _MonthlyTab extends StatefulWidget {
  final ReportController controller;
  const _MonthlyTab({required this.controller});

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.generateMonthlyReport(
        year: selectedYear,
        month: selectedMonth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final report = widget.controller.monthlyReport;
      if (report.isEmpty) {
        return EmptyState(
          icon: Icons.calendar_month_outlined,
          title: tr('اختر الشهر'),
        );
      }
      return RefreshIndicator(
        onRefresh:
            () async => widget.controller.generateMonthlyReport(
              year: selectedYear,
              month: selectedMonth,
            ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _datePickerRow(
                label:
                    '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(selectedYear, selectedMonth),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedYear = picked.year;
                      selectedMonth = picked.month;
                    });
                    widget.controller.generateMonthlyReport(
                      year: picked.year,
                      month: picked.month,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _summaryCards(
                sales: (report['total_sales'] ?? 0).toDouble(),
                profit: (report['net_profit'] ?? 0).toDouble(),
                cost: (report['total_cost'] ?? 0).toDouble(),
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
                totalRemaining: (report['total_remaining'] ?? 0).toDouble(),
                customerCredits: (report['customer_credits'] ?? 0).toDouble(),
                expenses: (report['expenses'] ?? 0).toDouble(),
                grossProfit: (report['gross_profit'] ?? 0).toDouble(),
                tax: (report['total_tax'] ?? 0).toDouble(),
                // 🛡️ `reports.profit` / `reports.tax` صارا مُنفَّذين: البطاقة
                // تُخفى هنا، والقيمة تُحجب في المتحكّم (`_guardMetrics`).
                showProfit: PermissionService.can(PermissionKeys.reportsProfit),
                showTax: PermissionService.can(PermissionKeys.reportsTax),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'شهري'),
              const SizedBox(height: 12),
              _printButton(),
              _developerFooter(),
            ],
          ),
        ),
      );
    });
  }
}

class _AnnualTab extends StatefulWidget {
  final ReportController controller;
  const _AnnualTab({required this.controller});

  @override
  State<_AnnualTab> createState() => _AnnualTabState();
}

class _AnnualTabState extends State<_AnnualTab> {
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.generateAnnualReport(year: selectedYear);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final report = widget.controller.annualReport;
      if (report.isEmpty) {
        return EmptyState(
          icon: Icons.calendar_view_month_outlined,
          title: tr('اختر السنة'),
        );
      }
      return RefreshIndicator(
        onRefresh:
            () async =>
                widget.controller.generateAnnualReport(year: selectedYear),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _datePickerRow(
                label: '$selectedYear',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(selectedYear),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selectedYear = picked.year);
                    widget.controller.generateAnnualReport(year: picked.year);
                  }
                },
              ),
              const SizedBox(height: 12),
              _summaryCards(
                sales: (report['total_sales'] ?? 0).toDouble(),
                profit: (report['net_profit'] ?? 0).toDouble(),
                cost: (report['total_cost'] ?? 0).toDouble(),
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
                totalRemaining: (report['total_remaining'] ?? 0).toDouble(),
                customerCredits: (report['customer_credits'] ?? 0).toDouble(),
                expenses: (report['expenses'] ?? 0).toDouble(),
                grossProfit: (report['gross_profit'] ?? 0).toDouble(),
                tax: (report['total_tax'] ?? 0).toDouble(),
                // 🛡️ `reports.profit` / `reports.tax` صارا مُنفَّذين: البطاقة
                // تُخفى هنا، والقيمة تُحجب في المتحكّم (`_guardMetrics`).
                showProfit: PermissionService.can(PermissionKeys.reportsProfit),
                showTax: PermissionService.can(PermissionKeys.reportsTax),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'سنوي'),
              const SizedBox(height: 12),
              _printButton(),
              _developerFooter(),
            ],
          ),
        ),
      );
    });
  }
}
