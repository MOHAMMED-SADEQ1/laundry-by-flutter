import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/subscriptions_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// لوحة الاشتراكات الشهرية — الصورة المالية الكاملة.
///
/// **لماذا لوحة منفصلة؟** شاشة الاشتراكات تُدار فيها العمليات (تسجيل دفعة،
/// إلغاء، دراسة). أما هذه فتُجيب على سؤال المالك: «هل الاشتراكات تربحني أم
/// تكلّفني؟ وكم خدمة ما زلتُ مدينًا بها؟». الخلط بين الاثنين يجعل الشاشة
/// العملية مزدحمة بأرقام لا يحتاجها الكاشير.
class SubscriptionDashboardScreen extends StatefulWidget {
  const SubscriptionDashboardScreen({super.key});

  @override
  State<SubscriptionDashboardScreen> createState() =>
      _SubscriptionDashboardScreenState();
}

class _SubscriptionDashboardScreenState
    extends State<SubscriptionDashboardScreen> {
  final SubscriptionsController controller = Get.put(
    SubscriptionsController(),
  );

  bool _loadingRanking = true;
  List<SubscriberProfitability> _ranking = const [];
  DateTime _rangeStart = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _rangeEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await controller.loadSubscriptions();
    await _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() => _loadingRanking = true);
    final list = await SubscriptionService.instance.profitabilityRanking(
      from: _rangeStart,
      to: _rangeEnd,
    );
    if (mounted) {
      setState(() {
        _ranking = list;
        _loadingRanking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: 'لوحة الاشتراكات',
        subtitle: 'الربحية والالتزامات والإيراد المتكرّر',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          final fin = controller.financials.value;
          if (controller.isLoading.value && fin == null) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                // ─── الإيراد المتكرّر + الالتزام المتبقّي ───
                FadeInUp(
                  child: _HeroCard(
                    mrr: controller.mrr.value,
                    deferred: fin?.deferred ?? 0,
                    collected: fin?.collected ?? 0,
                    recognized: fin?.recognized ?? 0,
                  ),
                ),
                const SizedBox(height: 14),

                // ─── المطابقة المحاسبية: محصَّل vs مُعترف به ───
                FadeInUp(
                  delayMs: 60,
                  child: _SectionTitle(
                    icon: Icons.balance,
                    title: 'المطابقة المحاسبية',
                    subtitle: 'ما قُبض نقدًا مقابل ما قُدِّم من خدمة',
                  ),
                ),
                const SizedBox(height: 8),
                FadeInUp(
                  delayMs: 90,
                  child: _ReconciliationPanel(fin: fin),
                ),
                const SizedBox(height: 14),

                // ─── حالة الاشتراكات ───
                FadeInUp(
                  delayMs: 120,
                  child: _SectionTitle(
                    icon: Icons.groups_2_outlined,
                    title: 'حالة المحفظة',
                    subtitle: 'توزيع المشتركين على الحالات',
                  ),
                ),
                const SizedBox(height: 8),
                FadeInUp(
                  delayMs: 150,
                  child: _StatusGrid(fin: fin),
                ),
                const SizedBox(height: 14),

                // ─── قائمة المتابعة: قارب السقف أو تجاوزه ───
                FadeInUp(
                  delayMs: 180,
                  child: _SectionTitle(
                    icon: Icons.speed,
                    title: 'مراقبة السقف',
                    subtitle: 'اشتراكات بلغت 80% من حدّها أو تجاوزته',
                  ),
                ),
                const SizedBox(height: 8),
                FadeInUp(
                  delayMs: 210,
                  child: _WatchlistCard(
                    rows: controller.watchlist,
                    controller: controller,
                  ),
                ),
                const SizedBox(height: 14),

                // ─── ربحية المشتركين ───
                FadeInUp(
                  delayMs: 240,
                  child: _SectionTitle(
                    icon: Icons.trending_down,
                    title: 'ربحية المشتركين',
                    subtitle:
                        'الأكثر خسارة أولًا — '
                        '${DateFormat('yyyy-MM-dd').format(_rangeStart)} ← '
                        '${DateFormat('yyyy-MM-dd').format(_rangeEnd)}',
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range, size: 19),
                      tooltip: 'تغيير الفترة',
                      onPressed: _pickRange,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingRanking)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  )
                else
                  FadeInUp(
                    delayMs: 270,
                    child: _ProfitabilityList(rows: _ranking),
                  ),

                // حقوق المطوّر — نهاية لوحة الاشتراكات
                const DeveloperCredit(
                  fontSize: 12,
                  padding: EdgeInsets.only(top: 18, bottom: 6),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      // ⚠️ بلا `locale`: تمرير `Locale('ar')` بلا `flutter_localizations`
      // يُنهي التطبيق — التفصيل في `customer_statement_sheet._pickPeriod`.
    );
    if (range != null) {
      setState(() {
        _rangeStart = range.start;
        _rangeEnd = range.end;
      });
      await _loadRanking();
    }
  }
}

// ═══════════════════════════ البطاقة الرئيسية ═══════════════════════════

class _HeroCard extends StatelessWidget {
  final double mrr;
  final double deferred;
  final double collected;
  final double recognized;

  const _HeroCard({
    required this.mrr,
    required this.deferred,
    required this.collected,
    required this.recognized,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow(blur: 18, y: 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.repeat_on_outlined,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'الإيراد الشهري المتكرّر (MRR)',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                mrr.toStringAsFixed(2),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ر.س / شهر',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'مُطبَّع على شهر 30 يومًا — الاشتراكات ذات المدد المختلفة مُوحَّدة '
            'لتصبح قابلة للجمع',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'التزام متبقٍّ',
                    value: deferred.toStringAsFixed(0),
                    hint: 'خدمة لم تُقدَّم',
                    warn: deferred > collected && collected > 0,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'محصَّل هذا الشهر',
                    value: collected.toStringAsFixed(0),
                    hint: 'نقدية',
                    warn: false,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'خدمة مُقدَّمة',
                    value: recognized.toStringAsFixed(0),
                    hint: 'إيراد مُعترف به',
                    warn: false,
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

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final bool warn;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.hint,
    required this.warn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (warn) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 12,
                color: Color(0xFFFCD34D),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              value,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: warn ? const Color(0xFFFCD34D) : Colors.white,
              ),
            ),
          ],
        ),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 8.5,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════ لوحة المطابقة المحاسبية ═══════════════════════

class _ReconciliationPanel extends StatelessWidget {
  final SubscriptionFinancials? fin;

  const _ReconciliationPanel({required this.fin});

  @override
  Widget build(BuildContext context) {
    final collected = fin?.collected ?? 0;
    final recognized = fin?.recognized ?? 0;
    final deferred = fin?.deferred ?? 0;
    // الفرق: ما قُبض ولم يُقدَّم بعد ⇒ يجب أن يطابق الالتزام المتبقّي تقريبًا
    final gap = collected - recognized;

    return SoftCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          _row(
            'النقدية المقبوضة',
            collected,
            AppColors.success,
            Icons.payments_outlined,
          ),
          const SizedBox(height: 8),
          _row(
            'قيمة الخدمة المُقدَّمة',
            recognized,
            AppColors.info,
            Icons.local_laundry_service_outlined,
          ),
          const Divider(height: 20),
          _row(
            'الالتزام المتبقّي',
            deferred,
            AppColors.violet,
            Icons.pending_actions_outlined,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
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
                    Expanded(
                      child: Text(
                        'فرق القبض عن الخدمة',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${gap >= 0 ? '+' : ''}${gap.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: gap >= 0 ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  gap >= 0
                      ? 'قبضنا أكثر مما قدّمنا ⇒ الرصيد خدمة غير مُقدَّمة، '
                            'وليس ربحًا خالصًا. سيُستنفد مع استمرار الغسيل.'
                      : 'قدّمنا خدمة أكثر مما قبضنا ⇒ ذمم أو تجاوزات تستحق '
                            'المتابعة والتحصيل.',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10,
                    height: 1.6,
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

  Widget _row(String label, double value, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'ر.س',
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 9.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════ شبكة حالة المحفظة ═══════════════════════

class _StatusGrid extends StatelessWidget {
  final SubscriptionFinancials? fin;

  const _StatusGrid({required this.fin});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'نشط',
        fin?.activeCount ?? 0,
        AppColors.success,
        Icons.verified_user_outlined,
      ),
      (
        'مستهلك السقف',
        fin?.cappedCount ?? 0,
        AppColors.warning,
        Icons.speed,
      ),
      (
        'متأخر',
        fin?.overdueCount ?? 0,
        AppColors.danger,
        Icons.schedule,
      ),
      (
        'لم يُسدد',
        fin?.pendingCount ?? 0,
        AppColors.slate,
        Icons.hourglass_empty,
      ),
    ];
    final total = items.fold<int>(0, (s, e) => s + e.$2);

    return SoftCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            children: items
                .map(
                  (e) => Expanded(
                    child: _statusTile(e.$1, e.$2, e.$3, e.$4, total),
                  ),
                )
                .toList(),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 9,
                child: Row(
                  children: items
                      .where((e) => e.$2 > 0)
                      .map(
                        (e) => Expanded(
                          flex: e.$2,
                          child: Container(color: e.$3),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'إجمالي $total اشتراك — القطع المُستهلكة هذا الشهر: '
                    '${fin?.totalPiecesUsed ?? 0}',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10,
                      color: AppColors.textSecondary,
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

  Widget _statusTile(
    String label,
    int count,
    Color color,
    IconData icon,
    int total,
  ) {
    final pct = total <= 0 ? 0 : (count * 100 / total).round();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 9.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (total > 0)
          Text(
            '$pct%',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════ قائمة مراقبة السقف ═══════════════════════

class _WatchlistCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final SubscriptionsController controller;

  const _WatchlistCard({required this.rows, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 17,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'لا يوجد اشتراك قارب سقفه — كل المشتركين داخل الحدود.',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11.5,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: rows.map((r) {
        final ratio = (r['usage_ratio'] as num?)?.toDouble() ?? 0;
        final capped = '${r['status']}' == 'capped';
        final color = capped
            ? AppColors.danger
            : ratio >= 0.95
            ? AppColors.warning
            : AppColors.info;
        final lp = SubscriptionService.limitPieces(r);
        final lv = SubscriptionService.limitValue(r);
        final usedP = (r['used_pieces'] as num?)?.toInt() ?? 0;
        final usedV = (r['used_value'] as num?)?.toDouble() ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.all(11),
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
                      text: capped ? 'استُهلك السقف' : '${(ratio * 100).round()}%',
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 3,
                  children: [
                    if (lp > 0)
                      Text(
                        'القطع: $usedP / $lp',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    if (lv > 0)
                      Text(
                        'القيمة: ${usedV.toStringAsFixed(2)} / '
                        '${lv.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.violet,
                        ),
                      ),
                    Text(
                      'حتى ${_fmtDate(r['paid_until_date'])}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  capped || ratio >= 0.95
                      ? 'يحتاج تجديدًا أو رفع سقف قبل الفاتورة القادمة.'
                      : 'راقبه — يقترب من الحدّ.',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 9.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _fmtDate(Object? raw) {
    final d = DateTime.tryParse('$raw');
    if (d == null) return '—';
    return DateFormat('yyyy-MM-dd').format(d);
  }
}

// ═══════════════════════ قائمة الربحية ═══════════════════════

class _ProfitabilityList extends StatelessWidget {
  final List<SubscriberProfitability> rows;

  const _ProfitabilityList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'لا توجد اشتراكات نشطة لتحليل ربحيتها',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      children: rows.map((p) {
        final loss = p.isLossMaking;
        final color = loss
            ? AppColors.danger
            : p.margin >= 0.5
            ? AppColors.success
            : AppColors.warning;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        loss
                            ? Icons.trending_down
                            : Icons.trending_up,
                        size: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.customerName,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    LabelChip(
                      text: loss
                          ? 'خاسر'
                          : 'هامش ${(p.margin * 100).round()}%',
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _cell(
                      'السعر',
                      p.price.toStringAsFixed(0),
                      AppColors.textPrimary,
                    ),
                    _cell(
                      'مُحصَّل',
                      p.paymentCollected.toStringAsFixed(0),
                      AppColors.success,
                    ),
                    _cell(
                      'تكلفة الخدمة',
                      p.costOfService.toStringAsFixed(2),
                      AppColors.danger,
                    ),
                    _cell(
                      'الصافي',
                      '${p.netContribution >= 0 ? '+' : ''}'
                          '${p.netContribution.toStringAsFixed(2)}',
                      color,
                      bold: true,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 3,
                  children: [
                    Text(
                      'القطع: ${p.pieces}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'القيمة المستهلكة: ${p.consumedValue.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'الاستهلاك من السعر: '
                      '${(p.utilization * 100).round()}%',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: p.utilization > 1
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (loss) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'تكلفة الخدمة تتجاوز ما حُصِّل — هذا الاشتراك يُنزف. '
                      'الخيارات: رفع السعر، تقليص السقف، أو إنهاء الاشتراك.',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        height: 1.6,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _cell(String label, String value, Color color, {bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
