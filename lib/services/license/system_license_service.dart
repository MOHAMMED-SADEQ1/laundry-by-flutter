import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/license/license_status.dart';
import 'package:laundry/services/security/security_service.dart';
import 'package:laundry/services/security/session_manager.dart';
// قيم الترخيص القابلة للضبط (عتبة التحذير وفاصل الفحص) من الإعدادات.
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/sqldb.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إدارة ترخيص النظام (تاريخ انتهاء الاشتراك).
///
/// **القاعدة:** تاريخ الانتهاء **شامل ليومه**؛ وغياب التاريخ = غير محدود.
/// الفحص يحدث في ثلاثة مواضع:
///   1. عند الإقلاع (`start` يُستدعى من `main` قبل `runApp`).
///   2. **كل ساعة** خلال عمل النظام (`Timer.periodic`).
///   3. عند **رجوع التطبيق للمقدمة** من الخلفية — مؤقّتات Dart تتوقف أثناء
///      تعليق التطبيق، فبلا هذا الفحص قد يبقى نظام منتهٍ مفتوحًا ساعات.
///
/// **لماذا في متحكّم GetX:** القفل يجب أن يكون تفاعليًا يغطي كل الشاشات لحظيًا
/// (انظر بوابة `MyApp.builder`)، وGetX هو نظام إدارة الحالة المعتمد في المشروع.
class SystemLicenseController extends GetxController
    with WidgetsBindingObserver {
  final SqlDB _db = SqlDB();

  /// آخر نتيجة تقييم. `null` = لم يُحمَّل بعد ⇒ **لا قفل** (كي لا يُقفل النظام
  /// خطأً قبل اكتمال القراءة الأولى من القاعدة).
  final Rx<LicenseStatus?> status = Rx<LicenseStatus?>(null);

  /// التاريخ المقروء حاليًا (يُعاد استخدامه في كل تقييم).
  DateTime? _expiry;

  Timer? _timer;
  bool _observing = false;

  bool get isLoaded => status.value != null;
  bool get isLocked => status.value?.isExpired ?? false;
  bool get isExpiringSoon => status.value?.isExpiringSoon ?? false;
  bool get isUnlimited => status.value?.isUnlimited ?? false;
  bool get clockTampered => status.value?.clockTampered ?? false;
  DateTime? get expiryDate => status.value?.expiry ?? _expiry;
  int? get daysRemaining => status.value?.daysRemaining;

  /// تشغيل الخدمة: قراءة أولى + مؤقّت الساعة + مراقبة دورة حياة التطبيق.
  Future<void> start() async {
    await load();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer?.cancel();
    _timer = Timer.periodic(
      AppSettingsService.instance.licenseCheckInterval,
      (_) => refreshNow(),
    );
  }

  /// يعيد ضبط مؤقّت الفحص على القيمة الحالية للإعداد — بلا انتظار الدورة
  /// القادمة، فتكفي ثانية واحدة لتطبيق الفاصل الجديد بعد تغييره في الإعدادات.
  ///
  /// لا يُشغّل مؤقّتًا إن لم تكن الخدمة قد بدأت (`_timer == null`) — فلا
  /// يُنشئ الحارسُ مؤقّتًا قبل أوانه.
  void applyIntervalFromSettings() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = Timer.periodic(
      AppSettingsService.instance.licenseCheckInterval,
      (_) => refreshNow(),
    );
  }

  /// قراءة تاريخ الانتهاء من القاعدة، مع الكاش كبديل عند تعذّر القاعدة.
  ///
  /// وتبدأ العمل ببذر **تاريخ الكود الافتراضي** إن انطبق شرطُه
  /// (`_applyCodeDefaultSeed`)، فيسري تاريخ الإصدار الجديد عند أول تشغيل له.
  Future<void> load() async {
    String? raw;
    try {
      raw = await _db.getSetting(AppConstants.settingSystemExpiryDate);
      raw = await _applyCodeDefaultSeed(raw);
      await _cacheRaw(raw);
    } catch (e) {
      debugPrint('SystemLicenseController.load error: $e');
      raw = await _cachedRaw();
    }
    _expiry = parseDate(raw);
    await _evaluate();
  }

  /// بذر تاريخ الانتهاء المضمَّن في الكود (إن انطبق شرطه).
  ///
  /// **قرار واحد مركزي** في [LicenseStatus.shouldSeed] (قابل للاختبار)، وهذا
  /// التابع ينفّذه فقط: يقرأ حارس «القيمة المطبَّقة» ثم يقرّر، وإن لزم يكتب
  /// التاريخ + الكاش + سجل التدقيق، ويسجّل الحارس.
  ///
  /// **الحارس يُكتب عند التطبيق الفعلي فقط** — لا عند التخلّف لأن المخزَّن
  /// أبعد. ولو كتبناه حينها لأغلقنا الباب أمام تمديد مشروع لاحق (مثلًا لو
  /// عدّل المدير التاريخ إلى أقرب ثم صدرت نسخة أبعد).
  ///
  /// أي فشل داخلي يُلتقط بهدوء ويُعاد المخزَّن كما هو، فلا يُسقط `load()`.
  Future<String?> _applyCodeDefaultSeed(String? storedRaw) async {
    try {
      final codeRaw = AppConstants.defaultLicenseExpiryDate.trim();
      if (codeRaw.isEmpty) return storedRaw; // البذر متوقف من الكود

      final codeDate = parseDate(codeRaw);
      if (codeDate == null) {
        debugPrint('تاريخ الكود غير صالح: $codeRaw');
        return storedRaw;
      }

      final appliedRaw = await _db.getSetting(
        AppConstants.settingLicenseSeedApplied,
      );
      final stored = parseDate(storedRaw);

      if (!LicenseStatus.shouldSeed(
        codeRaw: codeRaw,
        appliedRaw: appliedRaw,
        stored: stored,
        codeDate: codeDate,
      )) {
        return storedRaw;
      }

      await _db.updateSetting(AppConstants.settingSystemExpiryDate, codeRaw);
      await _db.updateSetting(AppConstants.settingLicenseSeedApplied, codeRaw);
      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'license_seed',
        tableName: 'settings',
        oldValues: '{"system_expiry_date":"${storedRaw ?? ''}"}',
        newValues: '{"system_expiry_date":"$codeRaw"}',
      );
      debugPrint('طُبِّق تاريخ الترخيص المضمَّن في الكود: $codeRaw');
      return codeRaw;
    } catch (e) {
      debugPrint('license seed skipped: $e');
      return storedRaw;
    }
  }

  /// تاريخ محلي بلا وقت — يُخزَّن ويُعرض بهذا الشكل.
  ///
  /// (الحسابات الداخلية في [LicenseStatus] تُجرّد الأيام إلى UTC بنفسها،
  /// فلا يتأثر فرق الأيام بإزاحة الجهاز.)
  static DateTime plainDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// إعادة التقييم الآن (يُستدعى عند العودة للمقدمة ويُتاح يدويًا).
  /// آخر إعادة تقييم — لخنق الطوفان (انظر [refreshNow]).
  DateTime? _lastRefresh;

  /// يعيد التقييم الآن.
  ///
  /// 🚨 **خانق ٥ ثوانٍ** (2026-11-07): على ويندوز يُطلق كل تغيّر تركيز للنافذة
  /// `AppLifecycleState.resumed`، وهذا المستمع يستدعي هذا التابع. ولوحة
  /// المفاتيح اللمسية تسرق التركيز مرارًا ⇒ استعلام قاعدة بيانات لكل نقرة،
  /// فيُستنزف المعالج ويصير اللمس بطيئًا. الخانق يُبقي السلوك (فحص عند العودة)
  /// ويُزيل الطوفان.
  Future<void> refreshNow() async {
    final now = DateTime.now();
    final last = _lastRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastRefresh = now;
    await _evaluate();
  }

  /// تعيين تاريخ الانتهاء (أو تمرير `null` لجعله غير محدود).
  ///
  /// يُسجَّل التغيير في `audit_log` لأنه قرار تجاري حسّاس يُدَفَع مقابله.
  Future<void> setExpiry(DateTime? date) async {
    final oldValue = _expiry == null ? '' : formatDate(_expiry!);
    final normalized = date == null ? null : plainDate(date);
    final value = normalized == null ? '' : formatDate(normalized);

    await _db.updateSetting(AppConstants.settingSystemExpiryDate, value);
    await _cacheRaw(value);
    _expiry = normalized;

    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: 'license_update',
      tableName: 'settings',
      oldValues: '{"system_expiry_date":"$oldValue"}',
      newValues: '{"system_expiry_date":"$value"}',
    );

    // إعادة ضبط «آخر مشاهدة» إلى الآن: التجديد يتطلب بيانات مدير النظام،
    // فهو الطريق المشروع للخروج من حالة «تعذّر التحقق من التاريخ» (مثلًا لو
    // كان تاريخ الجهاز مقدَّمًا بالخطأ). بلا هذا السطر يصبح القفل نهائيًا ولا
    // سبيل للعميل للعودة حتى بعد التجديد.
    await _writeLastSeenValue(plainDate(DateTime.now()));

    await _evaluate();
  }

  /// إلغاء التاريخ ⇒ غير محدود.
  Future<void> clearExpiry() => setExpiry(null);

  /// التحقق من بيانات حساب **admin نشِط** — لمسار التجديد من شاشة القفل.
  ///
  /// يعيد استخدام [SecurityService.verifyPassword] نفسه المستخدم في تسجيل
  /// الدخول، فلا تُكرَّر صيغة التشفير في مكانين.
  Future<bool> verifyAdminCredentials(String username, String password) async {
    final user = username.trim();
    if (user.isEmpty || password.isEmpty) return false;
    try {
      final rows = await _db.safeRead(
        'users',
        where: "username = ? AND role = 'admin' AND is_active = 1",
        whereArgs: [user],
      );
      if (rows.isEmpty) return false;
      final hash = rows.first['password_hash']?.toString() ?? '';
      if (hash.isEmpty) return false;
      return SecurityService.verifyPassword(password, hash);
    } catch (e) {
      debugPrint('verifyAdminCredentials error: $e');
      return false;
    }
  }

  /// وصف عربي مختصر للحالة — للعرض في الإعدادات وشاشة القفل.
  String get statusLabel {
    final s = status.value;
    if (s == null) return tr('جارٍ التحقق…');
    if (s.isUnlimited) return tr('غير محدود (بلا تاريخ انتهاء)');
    if (s.clockTampered) return tr('تعذّر التحقق من صحة التاريخ');
    if (s.isExpired) {
      final overdue = s.daysRemaining == null ? 0 : s.daysRemaining!.abs();
      return overdue <= 0
          ? tr('منتهٍ')
          : trf('منتهٍ منذ {0} يوم', ['$overdue']);
    }
    final d = s.daysRemaining ?? 0;
    if (d == 0) return tr('ينتهي اليوم');
    return d == 1
        ? tr('يتبقى يوم واحد')
        : trf('يتبقى {0} يومًا', ['$d']);
  }

  /// صيغة التخزين: `yyyy-MM-dd` محلية (بلا وقت) — يطابق نمط باقي الإعدادات.
  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// قراءة تاريخ مُخزَّن. يتسامح مع قيمة فارغة (غير محدود) ومع طابع ISO كامل
  /// (يأخذ أول 10 أحرف) لأن قواعد قديمة قد تخزّن الوقت معه.
  static DateTime? parseDate(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final candidate = s.length >= 10 ? s.substring(0, 10) : s;
    final parts = candidate.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    // نتحقق أن التاريخ حقيقي (يرفض 2026-02-30)
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    return plainDate(parsed);
  }

  Future<void> _evaluate() async {
    final lastSeen = await _readLastSeen();
    final now = DateTime.now();
    status.value = LicenseStatus.evaluate(
      _expiry,
      now,
      // عتبة التحذير من الإعدادات (افتراضيًا `AppConstants.licenseWarnDays`).
      warnDays: AppSettingsService.instance.licenseWarnDays,
      lastSeen: lastSeen,
    );
    // تقدّم فقط ولا رجوع — وإلا فقد الإرجاعُ أثرَه: حين تُرجَع ساعة الجهاز
    // للخلف، كتابةُ التاريخ الحالي (الأقدم) تمحو الدليل فيُفتح النظام بعد
    // ساعة. الإبقاء على الأبعد يجعل كشف التلاعب مستقرًا.
    final today = plainDate(now);
    if (lastSeen == null || today.isAfter(lastSeen)) {
      await _writeLastSeenValue(today);
    }
  }

  Future<DateTime?> _readLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return parseDate(prefs.getString(AppConstants.spLicenseLastSeen));
    } catch (e) {
      debugPrint('readLastSeen error: $e');
      return null;
    }
  }

  Future<void> _writeLastSeenValue(DateTime value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.spLicenseLastSeen, formatDate(value));
    } catch (e) {
      debugPrint('writeLastSeen error: $e');
    }
  }

  Future<void> _cacheRaw(String? raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.spSystemExpiryDate, raw ?? '');
    } catch (e) {
      debugPrint('cache system expiry error: $e');
    }
  }

  Future<String?> _cachedRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.spSystemExpiryDate);
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // مؤقّتات Dart تُعلَّق مع التطبيق، فالفحص عند العودة ضروري.
    if (state == AppLifecycleState.resumed) {
      refreshNow();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.onClose();
  }
}
