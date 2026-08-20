import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:laundry/controller/reports/report_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ReportController());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'التقارير',
              style: TextStyle(
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
              tabs: const [
                Tab(text: 'يومي'),
                Tab(text: 'أسبوعي'),
                Tab(text: 'شهري'),
                Tab(text: 'سنوي'),
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
}) {
  final cards = [
    _ReportStat(
      'المبيعات',
      sales,
      'ر.س',
      Icons.trending_up,
      AppColors.successGradient,
    ),
    _ReportStat(
      'صافي الربح',
      profit,
      'ر.س',
      Icons.savings,
      profit >= 0 ? AppColors.primaryGradient : AppColors.dangerGradient,
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
  const _ReportStat(
    this.title,
    this.value,
    this.unit,
    this.icon,
    this.gradient,
  );
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
                  stat.title,
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
          Text(
            '${stat.value.toStringAsFixed(2)} ${stat.unit}',
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
                'الفترة المحددة',
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
          title: 'التفصيل — $type',
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
              children: const [
                _TableHeaderCell('التاريخ'),
                _TableHeaderCell('المبيعات'),
                _TableHeaderCell('الفواتير'),
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
                    '${sales.toStringAsFixed(2)} ر.س',
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

Widget _printButton() {
  return GradientButton(
    label: 'طباعة التقرير',
    icon: Icons.print,
    gradient: AppColors.primaryGradient,
    onPressed: () {
      Get.snackbar(
        'ملاحظة',
        'ميزة الطباعة قيد التطوير',
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
        return const EmptyState(
          icon: Icons.event_note_outlined,
          title: 'اضغط لاختيار التاريخ',
          subtitle: 'اختر يوماً لعرض تقريره التفصيلي',
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
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'يومي'),
              const SizedBox(height: 12),
              _printButton(),
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
        return const EmptyState(
          icon: Icons.date_range_outlined,
          title: 'اضغط لاختيار الأسبوع',
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
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'أسبوعي'),
              const SizedBox(height: 12),
              _printButton(),
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
        return const EmptyState(
          icon: Icons.calendar_month_outlined,
          title: 'اختر الشهر',
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
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'شهري'),
              const SizedBox(height: 12),
              _printButton(),
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
        return const EmptyState(
          icon: Icons.calendar_view_month_outlined,
          title: 'اختر السنة',
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
                invoices: report['invoice_count'] ?? 0,
                average:
                    (report['invoice_count'] ?? 0) > 0
                        ? (report['total_sales'] ?? 0).toDouble() /
                            (report['invoice_count'] as int)
                        : 0.0,
                subscriptions: (report['subscription_revenue'] ?? 0).toDouble(),
              ),
              const SizedBox(height: 12),
              _breakdownTable(report, 'سنوي'),
              const SizedBox(height: 12),
              _printButton(),
            ],
          ),
        ),
      );
    });
  }
}
