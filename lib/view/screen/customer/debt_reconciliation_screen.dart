import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/controller/customer/debt_report_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/customer/debt_report_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// مطابقة أرصدة الزبائن + دفتر الأستاذ المرئي.
///
/// **القيمة المحاسبية للمطابقة**: النظام يحتفظ بمصدرين للذمة — فواتير
/// الزبون (الحقيقة) وحقل `customers.balance` (مخزَّن للسرعة). أي خلل في
/// الكتابة يجعل الرقمين يتباعدان بصمت، فتظهر تقارير رسمية خاطئة بلا إنذار.
/// هذه الشاشة تقارن الرقمين لكل زبون وتكشف الفرق فورًا، مع زر إصلاح يعيد
/// الاشتقاق من الفواتير.
///
/// **القيمة المحاسبية للدفتر**: تجيب على «لماذا رصيد هذا الزبون كذا؟» بسجل
/// زمني مرتب لكل حركة، وهو ما تعجز عنه قيمة رصيد واحدة.
class DebtReconciliationScreen extends StatefulWidget {
  const DebtReconciliationScreen({super.key});

  @override
  State<DebtReconciliationScreen> createState() =>
      _DebtReconciliationScreenState();
}

class _DebtReconciliationScreenState
    extends State<DebtReconciliationScreen> {
  final controller = Get.put(DebtReportController());
  final money = NumberFormat('#,##0.00', 'en');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              tr('المطابقة ودفتر الأستاذ'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
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
                Tab(text: tr('مطابقة الأرصدة')),
                Tab(text: tr('دفتر الأستاذ')),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ReconciliationTab(controller: controller, money: money),
              const _LedgerTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ تبويب المطابقة ═══════════════════════

class _ReconciliationTab extends StatelessWidget {
  final DebtReportController controller;
  final NumberFormat money;

  const _ReconciliationTab({required this.controller, required this.money});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final report = controller.reconciliation.value;
      if (controller.loadingReconciliation.value && report == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (report == null || report.rows.isEmpty) {
        return _empty();
      }

      final bad = report.mismatched;

      return RefreshIndicator(
        onRefresh: () => controller.loadReconciliation(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _statusCard(report, bad.isNotEmpty),
            const SizedBox(height: 12),
            _totalsRow(report),
            const SizedBox(height: 12),
            if (bad.isNotEmpty) ...[
              _repairButton(context, bad.length),
              const SizedBox(height: 12),
              _SectionTitle(
                title: tr('زبائن بأرصدة غير مطابقة'),
                subtitle: tr('مخزَّن الرصيد يختلف عن الذمة الحقيقية من الفواتير'),
                color: AppColors.danger,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: 8),
              ...bad.map((r) => _mismatchTile(r)),
              const SizedBox(height: 16),
            ],
            _SectionTitle(
              title: tr('كل الزبائن'),
              subtitle: trf(
                tr('{0} زبون لهم ذمة أو رصيد — الأكثر فرقًا أولًا'),
                ['${report.rows.length}'],
              ),
              color: AppColors.primary,
              icon: Icons.list_alt,
            ),
            const SizedBox(height: 8),
            ...report.rows.map((r) => _reconTile(r)),
          ],
        ),
      );
    });
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          tr('لا زبائن لهم ذمة أو رصيد قائم'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// بطاقة الحالة: هل القاعدة سليمة أم بها خلل؟
  Widget _statusCard(ReconciliationReport report, bool hasIssue) {
    final color = hasIssue ? AppColors.danger : AppColors.success;
    final icon = hasIssue ? Icons.warning_amber_rounded : Icons.verified_rounded;
    final title = hasIssue
        ? trf('يوجد {0} رصيد غير مطابق', ['${report.mismatched.length}'])
        : tr('كل الأرصدة مطابقة');
    final subtitle = hasIssue
        ? tr(
            'هذه أرصدة تخزينية تختلف عن مجموع الفواتير — استخدم زر الإصلاح لإعادة اشتقاقها من الفواتير.',
          )
        : tr(
            'الرصيد المخزَّن لكل زبون يساوي ذمته المحتسبة من الفواتير. لا خلل في الكتابة.',
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// الإجماليات: ذمة الفواتير / المدينون المخزَّنون / سلف الزبائن
  Widget _totalsRow(ReconciliationReport report) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: tr('ذمة الفواتير (الحقيقة)'),
            value: trf('{0} ر.س', [money.format(report.totalDerived)]),
            color: AppColors.danger,
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: tr('المخزَّن كمدين (balance)'),
            value: trf('{0} ر.س', [money.format(report.totalStoredDebt)]),
            color: AppColors.warning,
            icon: Icons.save_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: tr('سلف الزبائن'),
            value: trf('{0} ر.س', [money.format(report.totalCredit)]),
            color: AppColors.info,
            icon: Icons.savings_outlined,
          ),
        ),
      ],
    );
  }

  Widget _repairButton(BuildContext context, int count) {
    return Obx(
      () => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          onPressed: controller.repairing.value
              ? null
              : () => _confirmRepair(context, count),
          icon: controller.repairing.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.build_circle_outlined,
                  color: Colors.white, size: 19),
          label: Text(
            controller.repairing.value
                ? tr('جارٍ الإصلاح…')
                : trf('إصلاح كل الأرصدة ({0} زبون)', ['$count']),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRepair(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.build_circle,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                tr('تأكيد إصلاح الأرصدة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            trf(
              'سيُعاد اشتقاق رصيد {0} زبون من فواتيره الفعلية، فتصبح الأرصدة مطابقة للفواتير تمامًا.\n\nآمن تمامًا: لا يُحذف ولا يُعدَّل أي مبلغ في الفواتير، ولا يُمسّ الدفعات المسجلة. العملية تُصحّح حقل الرصيد فقط.',
              ['$count'],
            ),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                tr('إصلاح الآن'),
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

    if (ok != true) return;

    final fixed = await controller.repairBalances();

    // رفض الصلاحية (`-1`) وخطأ التنفيذ (`-2`) ليسا «لا حاجة لتعديل» —
    // خلطهما كان سيقول للمستخدم «كل الأرصدة سليمة» بينما لم يُنفَّذ شيء.
    if (fixed < 0) {
      Get.snackbar(
        fixed == -1 ? tr('لا تملك الصلاحية') : tr('تعذّر الإصلاح'),
        fixed == -1
            ? tr('إصلاح الأرصدة يحتاج صلاحية «إصلاح أرصدة الزبائن»، راجع مدير النظام.')
            : tr('حدث خطأ أثناء إصلاح الأرصدة، لم تُعدَّل بيانات.'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.lock_outline, color: Colors.white),
      );
      return;
    }

    Get.snackbar(
      tr('تمت المطابقة'),
      fixed > 0
          ? trf('صُحّح رصيد {0} زبون — أصبح مطابقًا للفواتير', ['$fixed'])
          : tr('كل الأرصدة كانت سليمة، لا حاجة لتعديل'),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  /// صف زبون غير مطابق — يُبرز الفرق بالأحمر
  Widget _mismatchTile(ReconciliationRow r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.customerName,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trf('فرق {0}', [money.format(r.difference.abs())]),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  tr('ذمة الفواتير'),
                  trf('{0} ر.س', [money.format(r.derivedDebt)]),
                  AppColors.danger,
                ),
              ),
              Expanded(
                child: _miniStat(
                  tr('الرصيد المخزَّن'),
                  trf('{0} ر.س', [money.format(r.storedBalance)]),
                  AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// صف زبون في القائمة العامة
  Widget _reconTile(ReconciliationRow r) {
    final balanced = r.isBalanced;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: balanced
              ? AppColors.border
              : AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            balanced ? Icons.check_circle_outline : Icons.error_outline,
            size: 17,
            color: balanced ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              r.customerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (r.derivedDebt > 0)
            Text(
              trf('ذمة {0}', [money.format(r.derivedDebt)]),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          if (r.derivedDebt > 0 && r.storedBalance > 0) ...[
            const Text(
              ' · ',
              style: TextStyle(color: AppColors.textMuted),
            ),
            Text(
              trf('سلفة {0}', [money.format(r.storedBalance)]),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.info,
              ),
            ),
          ],
          if (r.derivedDebt <= 0 && r.storedBalance <= 0)
            Text(
              trf('رصيد {0}', [money.format(r.storedBalance)]),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 9.5,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════ تبويب دفتر الأستاذ ═══════════════════════

/// دفتر الأستاذ: اختيار زبون ثم عرض كل حركات رصيده زمنيًا.
class _LedgerTab extends StatefulWidget {
  const _LedgerTab();

  @override
  State<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<_LedgerTab> {
  final _db = SqlDB();
  final money = NumberFormat('#,##0.00', 'en');

  List<Map<String, dynamic>> _customers = [];
  int? _selectedId;
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _customer;
  bool _loadingList = true;
  bool _loadingEntries = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final rows = await _db.readData(
        'SELECT customer_id, customer_name, phone_1, COALESCE(balance,0) AS bal FROM customers WHERE COALESCE(is_active, 1) = 1 ORDER BY customer_name',
      );
      if (!mounted) return;
      setState(() {
        _customers = rows;
        _loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingList = false);
    }
  }

  Future<void> _selectCustomer(Map<String, dynamic> c) async {
    setState(() {
      _selectedId = c['customer_id'] as int?;
      _customer = c;
      _loadingEntries = true;
      _entries = [];
    });
    try {
      final rows = await _db.readData(
        'SELECT * FROM customer_balance_log WHERE customer_id = ? ORDER BY created_at DESC, log_id DESC LIMIT 200',
        [_selectedId],
      );
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loadingEntries = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEntries = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedId == null) {
      return _customerPicker();
    }
    return Column(
      children: [
        _ledgerHeader(),
        Expanded(
          child: _loadingEntries
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? _noEntries()
                  : RefreshIndicator(
                      onRefresh: () async {
                        final c = _customer;
                        if (c != null) await _selectCustomer(c);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) => _entryTile(_entries[i], i),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _customerPicker() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionTitle(
          title: tr('اختر زبونًا'),
          subtitle: tr('لعرض سجل كل حركات رصيده زمنيًا — سبب كل تغيير ومقداره'),
          color: AppColors.primary,
          icon: Icons.person_search,
        ),
        const SizedBox(height: 10),
        ..._customers.map((c) {
          final bal = ((c['bal'] ?? 0) as num).toDouble();
          final label = bal > 0
              ? trf('له سلفة {0}', [money.format(bal)])
              : bal < 0
                  ? trf('عليه دين {0}', [money.format(bal.abs())])
                  : tr('لا ذمة');
          final color = bal > 0
              ? AppColors.info
              : bal < 0
                  ? AppColors.danger
                  : AppColors.textMuted;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectCustomer(c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      _initial(c['customer_name']),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (c['customer_name'] ?? tr('غير محدد')).toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Icon(Icons.arrow_back_ios_new,
                      size: 13, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _ledgerHeader() {
    final bal = ((_customer?['bal'] ?? 0) as num).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _selectedId = null;
              _customer = null;
              _entries = [];
            }),
            icon: const Icon(Icons.arrow_forward, size: 20),
            tooltip: tr('رجوع للقائمة'),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_customer?['customer_name'] ?? '').toString(),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  trf('{0} حركة مسجّلة', ['${_entries.length}']),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bal > 0
                    ? tr('سلفة')
                    : bal < 0
                        ? tr('دين')
                        : tr('متوازن'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10,
                  color: bal > 0
                      ? AppColors.info
                      : bal < 0
                          ? AppColors.danger
                          : AppColors.textMuted,
                ),
              ),
              Text(
                trf('{0} ر.س', [money.format(bal.abs())]),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: bal > 0
                      ? AppColors.info
                      : bal < 0
                          ? AppColors.danger
                          : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noEntries() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              tr('لا حركات مسجّلة لهذا الزبون'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('يُسجَّل الدفتر تلقائيًا عند كل دفعة أو إصدار فاتورة آجلة'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// حركة واحدة في الدفتر: المبلغ والتغيير والرصيد بعدها والسبب
  Widget _entryTile(Map<String, dynamic> e, int index) {
    final change = ((e['change_amount'] ?? 0) as num).toDouble();
    final after = ((e['balance_after'] ?? 0) as num).toDouble();
    final reason = (e['reason'] ?? '').toString();
    final meta = _reasonMeta(reason);
    final date = _parse(e['created_at']);
    final isDebtUp = change < 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // خط زمني رأسي يربط الحركات بصريًا
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(meta.icon, size: 15, color: meta.color),
            ),
            if (index != _entries.length - 1)
              Container(
                width: 1.5,
                height: 46,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta.label,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${isDebtUp ? '' : '+'}${money.format(change)}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDebtUp ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (date != null) ...[
                      const Icon(Icons.access_time,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(date),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      trf('الرصيد بعدها: {0}', [money.format(after)]),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (e['reference_id'] != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '#${e['reference_id']}',
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _initial(dynamic name) {
    final s = (name ?? '').toString().trim();
    return s.isEmpty ? L10n.pick('؟', '?') : s.characters.first;
  }

  /// ترجمة رمز السبب إلى نص عربي + أيقونة + لون
  static _ReasonMeta _reasonMeta(String reason) {
    switch (reason) {
      case 'invoice_create':
        return _ReasonMeta(
          tr('إصدار فاتورة آجلة'),
          Icons.receipt_long,
          AppColors.danger,
        );
      case 'invoice_credit_use':
        return _ReasonMeta(
          tr('استخدام رصيد على فاتورة'),
          Icons.swap_horiz,
          AppColors.warning,
        );
      case 'payment':
        return _ReasonMeta(
          tr('تسجيل دفعة'),
          Icons.payments,
          AppColors.success,
        );
      case 'invoice_delivered_with_payment':
        return _ReasonMeta(
          tr('سداد عند التسليم'),
          Icons.local_laundry_service,
          AppColors.success,
        );
      default:
        return _ReasonMeta(
          reason.isEmpty ? tr('حركة رصيد') : reason,
          Icons.sync_alt,
          AppColors.info,
        );
    }
  }

  static DateTime? _parse(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text) ??
        DateTime.tryParse(text.split(' ').first);
  }
}

class _ReasonMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _ReasonMeta(this.label, this.icon, this.color);
}

// ═══════════════════════ مكوّنات مشتركة ═══════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 9.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
