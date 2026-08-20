import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/home/dashboard_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة التحكم',
          style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshData(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.todaySales.value == 0) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }
        return RefreshIndicator(
          onRefresh: () => controller.refreshData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(controller),
                const SizedBox(height: 14),
                _buildKpiGrid(controller),
                const SizedBox(height: 14),
                _buildWeeklySales(controller),
                const SizedBox(height: 14),
                _buildPeakHours(controller),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildTopItems(controller)),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: _buildPaymentMethods(controller)),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(DashboardController c) {
    final today = DateFormat('EEEE yyyy-MM-dd', 'ar').format(DateTime.now());
    return SoftCard(
      gradient: AppColors.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملخص أداء المغسلة اليوم',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      today,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'ر.س',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat(
                'مبيعات الأمس',
                c.yesterdaySales.value,
                const Color(0xFFFCD34D),
              ),
              const SizedBox(width: 12),
              _miniStat(
                'الأسبوع الماضي',
                c.lastWeekSales.value,
                const Color(0xFFA3E635),
              ),
              const SizedBox(width: 12),
              _miniStat(
                'الشهر الماضي',
                c.lastMonthSales.value,
                const Color(0xFF7DD3FC),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: ${value.toStringAsFixed(1)}',
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
    );
  }

  Widget _buildKpiGrid(DashboardController c) {
    final kpis = [
      _KpiData(
        'مبيعات اليوم',
        c.todaySales.value,
        'ر.س',
        Icons.monetization_on,
        AppColors.successGradient,
      ),
      _KpiData(
        'الفواتير اليوم',
        c.todayInvoices.value.toDouble(),
        '',
        Icons.receipt_long,
        AppColors.primaryGradient,
      ),
      _KpiData(
        'متوسط الفاتورة',
        c.todayAverage.value,
        'ر.س',
        Icons.analytics,
        AppColors.amberGradient,
      ),
      _KpiData(
        'صافي الربح',
        c.todayProfit.value,
        'ر.س',
        Icons.trending_up,
        c.todayProfit.value >= 0
            ? AppColors.successGradient
            : AppColors.dangerGradient,
      ),
    ];

    return LayoutBuilder(
      builder: (context, cons) {
        final cols = cons.maxWidth > 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.9,
          ),
          itemCount: kpis.length,
          itemBuilder:
              (context, i) =>
                  FadeInUp(delayMs: i * 80, child: _KpiCard(data: kpis[i])),
        );
      },
    );
  }

  Widget _buildWeeklySales(DashboardController c) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'مبيعات آخر 7 أيام',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child:
                c.weeklySales.isEmpty
                    ? Center(
                      child: Text(
                        'لا توجد بيانات بعد',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(c.weeklySales.length, (i) {
                        final val = (c.weeklySales[i]['total'] ?? 0).toDouble();
                        double maxVal = 1;
                        for (final item in c.weeklySales) {
                          final v = (item['total'] ?? 0).toDouble();
                          if (v > maxVal) maxVal = v;
                        }
                        final raw = c.weeklySales[i]['day']?.toString() ?? '';
                        final label =
                            raw.length >= 10 ? raw.substring(5, 10) : raw;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  val.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  height: (val / maxVal) * 130,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                      bottom: Radius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItems(DashboardController c) {
    final items = c.topItems;
    double maxRevenue = 1;
    for (final item in items) {
      final v = (item['total_revenue'] ?? 0).toDouble();
      if (v > maxRevenue) maxRevenue = v;
    }

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'الأصناف الأكثر مبيعاً',
            icon: Icons.emoji_events_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),
          items.isEmpty
              ? Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'لا توجد بيانات بعد',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              : Column(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final name = item['item_name']?.toString() ?? 'غير محدد';
                  final count = (item['total_count'] ?? 0).toString();
                  final revenue = (item['total_revenue'] ?? 0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AppColors.amberGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '$count مبيعة',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${revenue.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedBar(
                          value: revenue / maxRevenue,
                          color: AppColors.warning,
                          height: 7,
                        ),
                      ],
                    ),
                  );
                }),
              ),
        ],
      ),
    );
  }

  Widget _buildPeakHours(DashboardController c) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'ساعات الذروة (آخر 7 أيام)',
            icon: Icons.schedule,
          ),
          const SizedBox(height: 6),
          Text(
            'توقع مبيعات اليوم حتى الآن: ${c.forecastToday.value.toStringAsFixed(1)} ر.س',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          c.peakHours.isEmpty
              ? Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'لا توجد بيانات كافية بعد',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              : Obx(
                () => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(c.peakHours.length, (i) {
                    final h = c.peakHours[i];
                    final hour = int.tryParse('${h['hour']}') ?? 0;
                    final count = (h['count'] ?? 0).toInt();
                    final maxCount = c.peakHours.first['count'] ?? 1;
                    final ratio = count / maxCount;
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBar(
                            value: ratio,
                            color:
                                ratio >= 0.75
                                    ? AppColors.danger
                                    : ratio >= 0.5
                                    ? AppColors.warning
                                    : AppColors.info,
                            height: 34,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(DashboardController c) {
    final methods = c.paymentMethods;
    final total = methods.fold<double>(
      0,
      (sum, m) => sum + (m['total'] ?? 0).toDouble(),
    );
    final colors = [
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      AppColors.violet,
      AppColors.danger,
    ];

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'طرق الدفع اليوم',
            icon: Icons.payment_rounded,
          ),
          const SizedBox(height: 12),
          methods.isEmpty
              ? Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'لا توجد بيانات بعد',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              : Column(
                children: List.generate(methods.length, (i) {
                  final m = methods[i];
                  final methodTotal = (m['total'] ?? 0).toDouble();
                  final pct = total > 0 ? (methodTotal / total) * 100 : 0.0;
                  final color = colors[i % colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${m['payment_method'] ?? 'غير محدد'}',
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${methodTotal.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AnimatedBar(value: pct / 100, color: color, height: 6),
                      ],
                    ),
                  );
                }),
              ),
        ],
      ),
    );
  }
}

class _KpiData {
  final String title;
  final double value;
  final String unit;
  final IconData icon;
  final Gradient gradient;
  const _KpiData(this.title, this.value, this.unit, this.icon, this.gradient);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: data.gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow(blur: 12, y: 4),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.value.toStringAsFixed(1)} ${data.unit}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
