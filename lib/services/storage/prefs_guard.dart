// إصلاح ملفّ `shared_preferences` التالف — **حرس إقلاع** لا ميزة.
//
// ═══════════════════════════════════════════════════════════════════════════
// العَرَض الذي بُني هذا الملفّ لأجله (حادثة حقيقية 2026-10-24)
// ═══════════════════════════════════════════════════════════════════════════
// بعد انطفاء الجهاز فجأةً، صار ملفّ التفضيلات على القرص
// `%APPDATA%\com.mohammadsadekaljafri\laundry\shared_preferences.json`
// **8836 بايت كلها أصفار** (NTFS يحفظ الحجم، والبيانات لم تُكتب قطّ).
//
// فشل الإقلاع بـ:
//     FormatException: Unexpected character (at character 1)
// من `lib/core/services/invoicecounterservice.dart` — لأن أوّل من يقرأ
// التفضيلات في `main` هو عدّاد الفواتير.
//
// **السبب الجذري في الحزمة لا في الكود:** `shared_preferences_windows` تقرأ
// الملفّ ثم `json.decode` **بلا أي try/catch**
// (`shared_preferences_windows-2.3.2/lib/shared_preferences_windows.dart:69`)،
// فأي ملفّ غير صالح **يُقفل التطبيق نهائيًا** — كل إقلاع، إلى الأبد، بلا
// وسيلة إصلاح من داخل التطبيق.
//
// **الحلّ:** فحص الملفّ قبل أوّل قراءة، وإن كان تالفًا:
//   1. يُنسخ إلى `shared_preferences.corrupt-<تاريخ>.json` — **لا حذف أبدًا**؛
//      فلو كان نصفه صالحًا يستطيع المبرمج استخراج ما فيه.
//   2. يُكتب مكانه `{}` صالح.
// ولا شيء غير ذلك: كل ما في التفضيلات قابل للاستعادة من قاعدة البيانات
// (الجلسة تُستعاد بتسجيل دخول، والعدّاد يُشتقّ من `MAX(invoices_id)`،
// وخيارات النظام وكاش النشاط يُقرآن من جدولَي `settings` و`business_info`).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:laundry/config/run_target.dart';
import 'package:laundry/services/storage/prefs_health.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

export 'package:laundry/services/storage/prefs_health.dart'
    show PrefsHealth, PrefsHealthCheck;

class PrefsGuard {
  PrefsGuard._();

  /// اسم الملفّ نفسه الذي تستخدمه `shared_preferences` على سطح المكتب.
  static const String fileName = PrefsHealthCheck.fileName;

  /// آخر نتيجة فحص — تقرأها `main` لعرض تنبيه واحد.
  static PrefsHealth lastResult = PrefsHealth.ok;

  /// مسار النسخة الاحتياطية إن أُصلح الملفّ.
  static String? lastBackupPath;

  /// الحكم نفسه منقول إلى [PrefsHealthCheck] (منطق خالص قابل للاختبار
  /// بـ`dart run`). هذا مجرّد اسم مختصر للاستخدام الداخلي.
  static bool isUsable(String raw) => PrefsHealthCheck.isUsable(raw);

  /// يفحص ملفّ التفضيلات ويُصلحه إن كان تالفًا. **لا يرمي أبدًا** — يُستدعى
  /// في `main` قبل أي شيء، فأي استثناء هنا يعني تطبيقًا لا يفتح.
  static Future<PrefsHealth> repairIfCorrupt() async {
    lastResult = PrefsHealth.ok;
    lastBackupPath = null;

    // أندرويد/iOS: لا ملفّ JSON أصلًا ⇒ لا شيء نفحصه.
    if (!AppPlatform.isDesktop) return PrefsHealth.ok;

    File? file;
    try {
      final dir = await getApplicationSupportDirectory();
      file = File(p.join(dir.path, fileName));
      if (!file.existsSync()) return PrefsHealth.ok; // أول تشغيل
    } catch (e) {
      debugPrint('PrefsGuard: تعذّر تحديد مسار التفضيلات: $e');
      return PrefsHealth.unrepaired;
    }

    String raw;
    try {
      final bytes = file.readAsBytesSync();
      // `allowMalformed` لأن ملفًّا نصف تالف قد يحوي بايتات ليست UTF-8 صحيحة.
      raw = bytes.isEmpty ? '' : utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('PrefsGuard: تعذّرت قراءة التفضيلات: $e');
      return PrefsHealth.unrepaired;
    }

    if (isUsable(raw)) return PrefsHealth.ok;

    // ─── تالف: نُبقي نسخة ثم نُفرغه ───
    try {
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final backup = File(p.join(p.dirname(file.path), 'shared_preferences.corrupt-$stamp.json'));
      file.copySync(backup.path);
      lastBackupPath = backup.path;
    } catch (e) {
      // النسخة الاحتياطية رفاهية: فشلها لا يمنع الإصلاح.
      debugPrint('PrefsGuard: تعذّر نسخ الملفّ التالف: $e');
    }

    try {
      file.writeAsStringSync('{}');
      lastResult = PrefsHealth.repaired;
      debugPrint(
        'PrefsGuard: أُصلح ملفّ التفضيلات التالف (كان ${raw.length} محرفًا غير صالح)',
      );
      return PrefsHealth.repaired;
    } catch (e) {
      debugPrint('PrefsGuard: تعذّر إصلاح التفضيلات: $e');
      return PrefsHealth.unrepaired;
    }
  }
}
