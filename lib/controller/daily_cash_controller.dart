import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/payment/payment_method.dart';

/// وضع عرض الصندوق: بالتاريخ (يوم عمل تشغيلي) أم بالوردية (عهدة درج واحدة).
///
/// كلاهما **نفس البيانات من نفس المصدر**: الحركات منسوبة بـ`shift_id`.
/// - `byShift`: `shift_id = ?` — تقرير وردية (Z-Report).
/// - `byDate`: ورديات اليوم التي فُتحت في ذلك التاريخ، ثم حركاتها بـ`shift_id`.
///   (X-Report: يوم عمل تشغيلي — تاريخ الصندوق = تاريخ **فتح** الوردية.)
enum CashViewMode { byDate, byShift }

class DailyCashController extends GetxController {
  final SqlDB _db = SqlDB();

  final Rxn<Map<String, dynamic>> shiftSummary = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> cashIn =
      <Map<String, dynamic>>[].obs; // فواتير كاش
  final RxList<Map<String, dynamic>> debtPayments =
      <Map<String, dynamic>>[].obs; // مدفوعات ديون الزبائن

  /// 💰 دفعات الاشتراكات الشهرية — كانت **غائبة تمامًا** عن الصندوق.
  /// اشتراك يُدفع نقدًا للكاشير لا يظهر في الدرج = عجز يومي وهمي في الإقفال.
  final RxList<Map<String, dynamic>> subscriptionPayments =
      <Map<String, dynamic>>[].obs;

  final RxList<Map<String, dynamic>> cashOut =
      <Map<String, dynamic>>[].obs; // مصروفات
  final RxBool isLoading = false.obs;
  final RxString selectedDate =
      DateFormat('yyyy-MM-dd').format(DateTime.now()).obs;

  // ────────────────────────────────────────────────────────────────
  // وضع العرض: بالتاريخ أم بالوردية
  //
  // **القاعدة المعمارية في هذا المشروع: «الوردية هي الصندوق».**
  // كل حركة مالية تُنسب إلى ورديتها بـ`shift_id` لا بالتخمين الزمني
  // (`datetime(x) >= shift_start` بلا حدّ أعلى كان يُدخل حركات حدثت
  // *بعد* إقفال الوردية ضمنها ⇒ تضخيم الإيداع). الأعمدة `shift_id`
  // موجودة في: invoices · customer_payments · subscription_payments · expenses.
  //
  // لذا وضع «بالوردية» يفلتر بـ`shift_id = ?` حصرًا، ولا يستخدم أي
  // مقارنة زمنية — تمامًا كما يفعل إقفال الوردية في `shift_controller`.
  //
  // ووضع «بالتاريخ» يبني يوم العمل من **ورديات فُتحت في ذلك التاريخ**
  // (كلها، مفتوحة ومقفَلة) ثم يجمع حركاتها بـ`shift_id`. فلا يُخلط
  // أساسان: تاريخ الحركة يبقى للضريبة/الفاتورة، وتاريخ فتح الوردية هو
  // تاريخ الصندوق.
  // ────────────────────────────────────────────────────────────────
  final Rx<CashViewMode> viewMode = CashViewMode.byDate.obs;

  /// الورديات المتاحة للاختيار (الأحدث أولًا) — تُحمَّل عند تبديل الوضع.
  final RxList<Map<String, dynamic>> shifts = <Map<String, dynamic>>[].obs;

  /// الوردية المختارة حاليًا في وضع «بالوردية».
  final RxnInt selectedShiftId = RxnInt();

  /// رصيد افتتاح الوردية المختارة — يُشتق من `shifts.opening_balance`،
  /// وإن كان صفرًا/فارغًا نرجع إلى الرصيد الختامي للوردية السابقة
  /// (`total_cash`) لأنه هو النقد الموجود فعلًا في الدرج عند فتحها.
  final RxDouble shiftOpeningBalance = 0.0.obs;

  // ────────────────────────────────────────────────────────────────
  // وضع «بالتاريخ»: يوم العمل = الورديات التي فُتحت في ذلك التاريخ
  //
  // **تاريخ الصندوق = تاريخ فتح الوردية**، لا تاريخ الحركة. وردية تُفتح
  // 9 مساءً وتُغلق 1 صباحًا هي وردية اليوم الذي فُتحت فيه؛ نقدها دخل الدرج
  // مساءً. الاعتماد على `DATE(invoice_date)` كان **يُسقط** فاتورة الساعة
  // 00:30 من يوم ورديتها (تاريخ فاتورتها = اليوم التالي ≠ تاريخ فتح ورديتها)
  // ⇒ عجز/زيادة وهمية عند مقارنة يومين.
  // ────────────────────────────────────────────────────────────────

  /// ورديات اليوم المعروض — كل من `DATE(start_time) = ?` مهما كانت مفتوحة
  /// أو مقفَلة، مرتّبة تصاعديًا (الأقدم أولًا).
  final RxList<Map<String, dynamic>> dayShifts = <Map<String, dynamic>>[].obs;

  /// رصيد افتتاح يوم العمل = رصيد افتتاح **أول** وردية فُتحت في ذلك التاريخ.
  ///
  /// لا نجمع افتتاحيات الورديات: كل وردية لاحقة تُرحّل نقد سابقتها
  /// (`total_cash`)، فجمعها يعدّ نفس النقد مرتين.
  final RxDouble dayOpeningBalance = 0.0.obs;

  /// فروق الجرد **المخزَّنة** لورديات اليوم المُقفَلة — وضع «بالتاريخ».
  ///
  /// هذه هي الجزئية الوحيدة غير القابلة للاشتقاق من الحركات: ما عُدَّ نقدًا
  /// فعلًا، وما الفرق، وما سببه. تُعرض مجمّعة ليوم العمل.
  final RxDouble dayCountedCash = 0.0.obs;
  final RxDouble dayCashDifference = 0.0.obs;
  final RxInt dayStocktakeCount = 0.obs;
  final RxInt dayUnstockedCount = 0.obs;

  /// الوردية المختارة كصف كامل (للعرض: وقت الفتح/الإقفال، من فتحها...).
  Map<String, dynamic>? get selectedShift {
    final id = selectedShiftId.value;
    if (id == null) return null;
    for (final s in shifts) {
      if ((s['shift_id'] as num?)?.toInt() == id) return s;
    }
    return null;
  }

  /// وصف مختصر للوردية — يُستخدم في الواجهة.
  String get selectedShiftLabel {
    final s = selectedShift;
    if (s == null) return tr('لا توجد وردية محددة');
    final id = s['shift_id'];
    final start = _formatShiftTime(s['start_time']?.toString());
    final end = s['end_time'] == null
        ? tr('مفتوحة الآن')
        : trf('أُقفلت {0}', [_formatShiftTime(s['end_time']?.toString())]);
    return trf('وردية #{0} — {1} · {2}', [id, start, end]);
  }

  static String _formatShiftTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd/MM hh:mm a').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  /// تبديل وضع العرض وإعادة التحميل.
  Future<void> changeViewMode(CashViewMode mode) async {
    if (viewMode.value == mode) return;
    viewMode.value = mode;
    if (mode == CashViewMode.byShift) {
      await loadShifts();
    }
    await loadDailyCash();
  }

  /// اختيار وردية بعينها.
  Future<void> selectShift(int shiftId) async {
    selectedShiftId.value = shiftId;
    await loadDailyCash();
  }

  /// الانتقال للوردية الأحدث/الأقدم في القائمة.
  Future<void> stepShift(int delta) async {
    if (shifts.isEmpty) return;
    final id = selectedShiftId.value;
    final idx = shifts.indexWhere(
      (s) => (s['shift_id'] as num?)?.toInt() == id,
    );
    final next = (idx < 0 ? 0 : idx) + delta;
    if (next < 0 || next >= shifts.length) return;
    await selectShift((shifts[next]['shift_id'] as num).toInt());
  }

  /// تحميل الورديات المتاحة: المفتوحة أولًا، ثم الأحدث إقفالًا.
  Future<void> loadShifts() async {
    try {
      final rows = await _db.readData(
        'SELECT * FROM shifts ORDER BY shift_id DESC LIMIT 60',
      );
      shifts.assignAll(rows);
      // إن لم تكن هناك وردية مختارة، اختر المفتوحة وإلا الأحدث.
      final current = selectedShiftId.value;
      final stillExists =
          current != null && rows.any((r) => r['shift_id'] == current);
      if (!stillExists) {
        Map<String, dynamic>? open;
        for (final r in rows) {
          if (r['end_time'] == null) {
            open = r;
            break;
          }
        }
        final chosen = open ?? (rows.isNotEmpty ? rows.first : null);
        selectedShiftId.value = (chosen?['shift_id'] as num?)?.toInt();
      }
    } catch (e) {
      debugPrint('loadShifts error: $e');
    }
  }

  /// إجمالي الدخل الكلي = فواتير كاش + مدفوعات الديون **النقدية**
  /// + دفعات الاشتراكات **النقدية**.
  ///
  /// نستثني مصدر `credit_use`: استهلاك السلفة ليس نقدية دخلت الصندوق، بل
  /// تسوية محاسبية بين رصيد الزبون الدائن وذمته. إدراجه كان يضخّم الإيداع
  /// الفعلي ويجعل الإقفال لا يطابق النقد الموجود في الدرج.
  ///
  /// ونستثني كذلك دفعات الاشتراك بمصدر `cancel_refund` وطريقة `رصيد`:
  /// الاسترداد كسلفة تسوية لا نقدية، والاسترداد النقدي يُسجَّل في المصروفات
  /// لا في الدخل (وإلا حُسب مرتين بالإشارة المعاكسة).
  double get totalCashIn =>
      cashIn.fold(0.0, (sum, e) => sum + _num(e['paid_amount'])) +
      debtPayments
          .where((e) => (e['source'] ?? 'manual') != 'credit_use')
          .fold(0.0, (sum, e) => sum + _num(e['amount'])) +
      subscriptionPayments.where(_isCashSubscriptionPayment).fold(
        0.0,
        (sum, e) => sum + _num(e['amount']),
      );

  /// دفعة اشتراك نقدية فعلية؟ (ليست استردادًا ولا تسوية رصيد)
  static bool _isCashSubscriptionPayment(Map<String, dynamic> p) {
    if ('${p['source']}' == 'cancel_refund') return false;
    final method = '${p['method'] ?? ''}'.trim();
    if (PaymentMethods.tryParse(method) == PaymentMethod.balance) return false;
    return true;
  }

  /// مجموع دفعات الاشتراكات النقدية لليوم — للعرض المنفصل في الكشف.
  double get subscriptionCashTotal => subscriptionPayments
      .where(_isCashSubscriptionPayment)
      .fold(0.0, (sum, e) => sum + _num(e['amount']));

  /// مجموع الاستردادات **النقدية** للاشتراكات (تظهر في المصروفات).
  ///
  /// نستثني طريقة `رصيد`: الاسترداد كسلفة تسوية دفاتر لا يخرج نقدية من
  /// الدرج، فإدراجه هنا كان يجعل الكشف يوهم بخروج مبلغ لم يُدفع.
  double get subscriptionRefundTotal => subscriptionPayments
      .where(
        (e) =>
            '${e['source']}' == 'cancel_refund' &&
            PaymentMethods.tryParse('${e['method'] ?? ''}') !=
                PaymentMethod.balance,
      )
      .fold(0.0, (sum, e) => sum + _num(e['amount']));

  /// المصروفات الخارجة **نقدًا من الدرج** فقط.
  ///
  /// **إصلاح:** كان يجمع كل صفوف `expenses` بلا تمييز طريقة الدفع. مصروف
  /// مدفوع بالشبكة أو كتسوية دفاتر **لا يخرج من الدرج**، فإدراجه كان يجعل
  /// `closingBalance` أقل من النقد الفعلي (عجز وهمي في الإقفال) — وهو نفس
  /// الخطأ الذي أُصلح في الاستردادات القائمة على الرصيد.
  double get totalCashOut => cashOut
      .where(
        (e) =>
            PaymentMethods.keyOf('${e['payment_method'] ?? ''}') ==
            PaymentMethod.cash.key,
      )
      .fold(0.0, (sum, e) => sum + _num(e['amount']));

  /// إجمالي المصروفات لليوم بكل طرق الدفع — للإفصاح في الكشف.
  double get totalExpensesAllMethods =>
      cashOut.fold(0.0, (sum, e) => sum + _num(e['amount']));

  /// مصروفات اليوم غير النقدية (شبكة / تسوية) — لا تُخصم من الدرج.
  double get nonCashExpenseTotal =>
      totalExpensesAllMethods - totalCashOut;

  /// رصيد افتتاح الصندوق المعروض.
  ///
  /// - وضع **بالوردية**: `shifts.opening_balance` للوردية المختارة (المبلغ
  ///   الذي عُدَّ فعلًا عند فتحها)، وإن كان صفرًا نرجع للرصيد الختامي
  ///   (`total_cash`) للوردية السابقة — وهو النقد الموجود فعلًا في الدرج.
  /// - وضع **بالتاريخ**: رصيد افتتاح **أول وردية فُتحت في ذلك التاريخ**
  ///   (تاريخ فتح الوردية هو تاريخ الصندوق).
  double get openingBalance => viewMode.value == CashViewMode.byShift
      ? shiftOpeningBalance.value
      : dayOpeningBalance.value;

  double get closingBalance => openingBalance + totalCashIn - totalCashOut;

  /// هل نعرض بيانات وردية بعينها؟
  bool get isShiftMode => viewMode.value == CashViewMode.byShift;

  /// تسمية «الصافي» حسب الوضع — «اليوم» في وضع التاريخ و«الوردية» في وضعها.
  String get netLabel => isShiftMode ? 'صافي الوردية' : 'صافي اليوم';

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  @override
  void onInit() {
    super.onInit();
    loadDailyCash();
  }

  void changeDate(String date) {
    selectedDate.value = date;
    loadDailyCash();
  }

  /// رصيد افتتاح الوردية: `opening_balance` المُخزَّن (ما عُدَّ فعلًا عند
  /// الفتح)، وإن كان صفرًا/فارغًا فالرصيد الختامي (`total_cash`) للوردية
  /// السابقة مباشرةً — وهو النقد الموجود فعلًا في الدرج لحظة الفتح.
  Future<double> _resolveShiftOpening(int shiftId) async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(opening_balance, 0) as ob FROM shifts WHERE shift_id = ?',
        [shiftId],
      );
      final ob = rows.isEmpty ? 0.0 : _num(rows.first['ob']);
      if (ob > 0) return ob;

      final prev = await _db.readData(
        'SELECT COALESCE(total_cash, 0) as tc FROM shifts WHERE shift_id < ? ORDER BY shift_id DESC LIMIT 1',
        [shiftId],
      );
      return prev.isEmpty ? 0.0 : _num(prev.first['tc']);
    } catch (e) {
      debugPrint('_resolveShiftOpening error: $e');
      return 0.0;
    }
  }

  void _resetDayStocktake() {
    dayCountedCash.value = 0;
    dayCashDifference.value = 0;
    dayStocktakeCount.value = 0;
    dayUnstockedCount.value = 0;
  }

  /// تجميع الجرد **المخزَّن** لورديات يوم العمل.
  ///
  /// الوردية المفتوحة لم تُجرَّد بعد فلا تُحتسب. والفرق بين «أُقفلت بلا جرد»
  /// (عدّاد منفصل) و«جُرِدت وطابقت» (فرق = 0) معلومة محاسبية حقيقية لا
  /// يجوز محوها بدمجهما.
  void _summarizeDayStocktake(List<Map<String, dynamic>> dayShiftsRows) {
    var counted = 0.0;
    var difference = 0.0;
    var stocked = 0;
    var unstocked = 0;
    for (final s in dayShiftsRows) {
      if (s['end_time'] == null) continue; // مفتوحة — لم يُجرَد درجها بعد
      final c = s['counted_cash'];
      if (c == null) {
        unstocked++;
        continue;
      }
      counted += _num(c);
      difference += _num(s['cash_difference']);
      stocked++;
    }
    dayCountedCash.value = counted;
    dayCashDifference.value = difference;
    dayStocktakeCount.value = stocked;
    dayUnstockedCount.value = unstocked;
  }

  /// هل ليوم العمل جرد مخزَّن يُعرض؟
  bool get hasDayStocktake =>
      dayStocktakeCount.value > 0 || dayUnstockedCount.value > 0;

  Future<void> loadDailyCash() async {
    isLoading.value = true;
    try {
      final date = selectedDate.value;
      final byShift = viewMode.value == CashViewMode.byShift;
      final shiftId = selectedShiftId.value;

      // ─── ملخص الصندوق ورصيد الافتتاح ───
      //
      // «بالتاريخ» هنا **يوم عمل** لا مجموعة طوابع زمنية: كل وردية فُتحت في
      // ذلك التاريخ. ولهذا نجمع معرّفات ورديات اليوم **قبل** أي استعلام عن
      // الحركات، ثم نفلتر كل الحركات بـ`shift_id IN (…)`.
      final List<int> dayShiftIds = <int>[];
      if (byShift) {
        if (shiftId == null) {
          shiftSummary.value = null;
          shiftOpeningBalance.value = 0;
          dayShifts.clear();
          dayOpeningBalance.value = 0;
          _resetDayStocktake();
          cashIn.clear();
          debtPayments.clear();
          subscriptionPayments.clear();
          cashOut.clear();
          return;
        }
        final rows = await _db.readData(
          'SELECT * FROM shifts WHERE shift_id = ?',
          [shiftId],
        );
        shiftSummary.value = rows.isNotEmpty ? rows.first : null;
        shiftOpeningBalance.value = await _resolveShiftOpening(shiftId);
        dayShifts.clear();
        dayOpeningBalance.value = 0;
        _resetDayStocktake();
      } else {
        final shiftRows = await _db.readData(
          'SELECT * FROM shifts WHERE DATE(start_time) = ? ORDER BY shift_id ASC',
          [date],
        );
        dayShifts.assignAll(shiftRows);
        shiftSummary.value = shiftRows.isEmpty ? null : shiftRows.first;
        for (final s in shiftRows) {
          dayShiftIds.add((s['shift_id'] as num).toInt());
        }
        dayOpeningBalance.value = dayShiftIds.isEmpty
            ? 0.0
            : await _resolveShiftOpening(dayShiftIds.first);
        _summarizeDayStocktake(shiftRows);
      }

      // قائمة رموز لشرط IN. القيمة `-1` مستحيلة ⇒ لا تُطابق شيئًا (وضع
      // الوردية لا يحتاج هذا الشرط أصلًا، لكنه يُبنى دائمًا للتوحيد).
      final inList = dayShiftIds.isEmpty
          ? '-1'
          : List.filled(dayShiftIds.length, '?').join(',');

      // ─── إيداعات (فواتير كاش) — بلا فواتير الاشتراكات ───
      // فاتورة الاشتراك مدفوعة أصلًا عند تسجيل الدفعة؛ إدراجها هنا كان
      // يُدخل نفس المال مرتين في الدرج (مرة كدفعة ومرة كفاتورة).
      final invoices = byShift
          ? await _db.readData(
              'SELECT i.*, u.full_name as user_name FROM invoices i LEFT JOIN users u ON i.created_by = u.user_id WHERE i.shift_id = ? AND i.payment_method = ?   AND i.subscription_id IS NULL ORDER BY i.invoice_date ASC',
              [shiftId, PaymentMethod.cash.key],
            )
          : await _db.readData(
              'SELECT i.*, u.full_name as user_name FROM invoices i LEFT JOIN users u ON i.created_by = u.user_id WHERE (i.shift_id IN ($inList)   OR (i.shift_id IS NULL AND DATE(i.invoice_date) = ?))   AND i.payment_method = ?   AND i.subscription_id IS NULL ORDER BY i.invoice_date ASC',
              [...dayShiftIds, date, PaymentMethod.cash.key],
            );
      cashIn.assignAll(invoices);

      // ─── مدفوعات ديون الزبائن (من جدول customer_payments) ───
      final payments = byShift
          ? await _db.readData(
              'SELECT cp.*, u.full_name as user_name, c.customer_name FROM customer_payments cp LEFT JOIN users u ON cp.recorded_by = u.user_id LEFT JOIN customers c ON cp.customer_id = c.customer_id WHERE cp.shift_id = ? ORDER BY cp.payment_date ASC',
              [shiftId],
            )
          : await _db.readData(
              'SELECT cp.*, u.full_name as user_name, c.customer_name FROM customer_payments cp LEFT JOIN users u ON cp.recorded_by = u.user_id LEFT JOIN customers c ON cp.customer_id = c.customer_id WHERE (cp.shift_id IN ($inList)   OR (cp.shift_id IS NULL AND DATE(cp.payment_date) = ?)) ORDER BY cp.payment_date ASC',
              [...dayShiftIds, date],
            );
      debtPayments.assignAll(payments);

      // ─── 💰 دفعات الاشتراكات الشهرية ───
      final subPays = byShift
          ? await _db.readData(
              'SELECT sp.*, u.full_name as user_name,   COALESCE(s.customer_name, c.customer_name) as customer_name FROM subscription_payments sp LEFT JOIN users u ON sp.recorded_by = u.user_id LEFT JOIN subscriptions s ON s.subscription_id = sp.subscription_id LEFT JOIN customers c ON c.customer_id = s.customer_id WHERE sp.shift_id = ? ORDER BY sp.paid_date ASC',
              [shiftId],
            )
          : await _db.readData(
              'SELECT sp.*, u.full_name as user_name,   COALESCE(s.customer_name, c.customer_name) as customer_name FROM subscription_payments sp LEFT JOIN users u ON sp.recorded_by = u.user_id LEFT JOIN subscriptions s ON s.subscription_id = sp.subscription_id LEFT JOIN customers c ON c.customer_id = s.customer_id WHERE (sp.shift_id IN ($inList)   OR (sp.shift_id IS NULL AND DATE(sp.paid_date) = ?)) ORDER BY sp.paid_date ASC',
              [...dayShiftIds, date],
            );
      subscriptionPayments.assignAll(subPays);

      // ─── سحوبات (مصروفات) ───
      //
      // **إصلاح (2026-09-18):** كان هنا `DATE(e.date, 'localtime')` بينما
      // المصادر الثلاثة الأخرى تستخدم `DATE(...)` مجرّدة ⇒ نافذة يومية
      // **غير متسقة داخل نفس الشاشة**.
      //
      // و`'localtime'` في SQLite تعني «التاريخ مخزَّن UTC فحوّله للتوقيت
      // المحلي». لكن لا يوجد `toUtc()` في المشروع كله — كل الطوابع تُكتب
      // بـ`DateTime.now().toIso8601String()` أي **محلية بلا لاحقة منطقة**.
      // فتطبيق `'localtime'` على محلي = **تحويل مزدوج** يُزيح النافذة
      // بمقدار إزاحة الجهاز (+3 ساعات للسعودية): مصروف الساعة 22:30 يوم
      // 17 يُحتسب في صندوق يوم **18**، بينما فاتورة نفس اللحظة في يوم 17.
      // النتيجة: رصيد ختامي خاطئ عند حدود اليوم. أُثبت عمليًا في
      // `tool/verify_cash_view_modes.py`.
      final expenses = byShift
          ? await _db.readData(
              'SELECT e.*, u.full_name as user_name FROM expenses e LEFT JOIN users u ON e.recorded_by = u.user_id WHERE e.shift_id = ? ORDER BY e.date ASC',
              [shiftId],
            )
          : await _db.readData(
              'SELECT e.*, u.full_name as user_name FROM expenses e LEFT JOIN users u ON e.recorded_by = u.user_id WHERE (e.shift_id IN ($inList)   OR (e.shift_id IS NULL AND DATE(e.date) = ?)) ORDER BY e.date ASC',
              [...dayShiftIds, date],
            );
      cashOut.assignAll(expenses);
    } catch (e) {
      debugPrint('loadDailyCash error: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
