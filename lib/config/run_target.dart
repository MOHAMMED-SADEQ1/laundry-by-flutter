/// ════════════════════════════════════════════════════════════════════
///  🔀  مفتاح التشغيل: ويندوز ⇄ أندرويد
/// ════════════════════════════════════════════════════════════════════
///
/// **هذا هو الملف الوحيد الذي تفتحه.** لا تعدّل أي ملف آخر في المشروع.
///
/// 🎚️ **التبديل بطريقتين — استخدم ما يريحك (وكلاهما ينتهي إلى نفس المفتاح):**
///   أ) **تعليق سطر وتشغيل سطر** (هي ما طلبته): في «قسم المفتاح» أدناه
///      **علّق** السطر ① بـ`//` في أوّله، و**أزل التعليق** عن ② أو ③.
///   ب) **تغيير قيمة سطر واحد**: بدّل قيمة `kRunTarget` بين
///      `RunTarget.auto` / `.android` / `.windows` بلا تعليق أي شيء.
///
/// ┌──────────────────────┬────────────────────────────────────────────┐
/// │ RunTarget.auto       │ ✅ الافتراضي — يكتشف النظام بنفسه، فلا      │
/// │                      │    تحتاج تعديل شيء أبدًا للتشغيل على       │
/// │                      │    ويندوز ولا على أندرويد.                 │
/// ├──────────────────────┼────────────────────────────────────────────┤
/// │ RunTarget.windows    │ يفرض مسار ويندوز/سطح المكتب.               │
/// │ RunTarget.android    │ يفرض مسار أندرويد.                         │
/// └──────────────────────┴────────────────────────────────────────────┘
///
/// **أوامر التشغيل (لا تتغيّر بتغيير المفتاح):**
///   ويندوز:  `flutter run -d windows`   ·  الإصدار: `flutter build windows`
///   أندرويد: `flutter run -d android`   ·  الإصدار: `flutter build apk`
///
/// ⚠️ **لماذا `auto` هو الأفضل؟** لأن المفتاح اليدوي لا يُغيّر ما يُبنى له
/// التطبيق (التطبيق يُبنى للأجهزة التي تطلبها بأمر `flutter run/build`)،
/// وإنما يُغيّر **مكان قاعدة البيانات ومحرّكها**. فلو فرضت `windows` وأنت
/// تشغّل على أندرويد فستُفتح قاعدة جديدة فارغة في مسار غير صالح — ولذلك
/// المفتاح **يرفض** الهدف المخالف للنظام الفعلي ويكتب تحذيرًا بدل أن يُتلف
/// البيانات. القيمة اليدوية مفيدة للتجارب والاختبار فقط.
///
/// **الفرق الوحيد بين النظامين في هذا التطبيق:**
///   • أندرويد: محرّك `sqflite` الأصلي + مسار النظام `/data/data/.../databases`.
///   • ويندوز: محرّك `sqflite_common_ffi` (لأن `sqflite` لا يعمل على سطح
///     المكتب) + مجلد دعم التطبيق `%APPDATA%` عبر `path_provider`، لأن
///     `getDatabasesPath()` في ffi تنفيذ رديء (موثّق رسميًا في الحزمة).
///
/// 🚨 **قاعدة لا تُخالَف:** مسار أندرويد يجب أن يبقى `getDatabasesPath()`
/// الأصلي كما هو بالحرف — أي تغيير فيه يعني أن كل تثبيت قائم يفقد قاعدة
/// بياناته ويبدأ من صفر.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

/// النظام الذي سيعمل عليه التطبيق.
enum RunTarget {
  /// يكتشف النظام تلقائيًا — يعمل على ويندوز وأندرويد بلا أي تعديل.
  auto,

  /// ويندوز (وسطح المكتب عمومًا: Linux و macOS).
  windows,

  /// أندرويد (والهاتف عمومًا).
  android,
}

// ╔═══════════════════════════════════════════════════════════════════╗
// ║                                                                   ║
// ║   🔀  قسـم المفـتاح — اختر سطرًا **واحدًا** غير معلَّق،             ║
// ║        وعلّق السطرين الباقيين (لا يبقى سطران بلا تعليق أبدًا).      ║
// ║                                                                   ║
// ╚═══════════════════════════════════════════════════════════════════╝

// ① تلقائي (الافتراضي): يعمل على أندرويد وويندوز معًا بلا أي تعليق.
//    هذا السطر الآن **غير معلَّق**. للتبديل: ضع // في أوّله أولًا.
const RunTarget kRunTarget = RunTarget.auto;

// ② أندرويد فقط — علّق السطر ① ثم أزل التعليق عن السطر التالي:
// const RunTarget kRunTarget = RunTarget.android;

// ③ ويندوز / سطح المكتب فقط — علّق السطر ① ثم أزل التعليق عن السطر التالي:
// const RunTarget kRunTarget = RunTarget.windows;

// ⚠️ لا تُبقِ أكثر من سطر واحد غير معلَّق — تكرار الاسم يُفشل البناء فورًا.

// ╔═══════════════════════════════════════════════════════════════════╗
// ║   لا شيء آخر في هذا الملف يحتاج تعديلك.                           ║
// ╚═══════════════════════════════════════════════════════════════════╝

/// منطق النظام — كله في هذا الملف، فلا يتفرّق شرط `Platform` في المشروع.
class AppPlatform {
  AppPlatform._();

  static RunTarget? _resolved;

  /// الهدف الفعلي بعد الحلّ (مخزَّن مؤقتًا).
  static RunTarget get target => _resolved ??= _resolve();

  /// هل نعمل على سطح المكتب؟ (ويندوز/Linux/macOS)
  static bool get isDesktop => target == RunTarget.windows;

  /// اسم مختصر للعرض في الإعدادات/التشخيص.
  static String get label => isDesktop ? 'ويندوز (سطح المكتب)' : 'أندرويد';

  static RunTarget _resolve() {
    final real = _realOs();

    switch (kRunTarget) {
      case RunTarget.auto:
        return real;

      case RunTarget.windows:
      case RunTarget.android:
        // حماية: هدف مفروض يخالف النظام الفعلي ⇒ **لا نُنفّذه**. تنفيذه
        // يعني فتح قاعدة بيانات في مسار غير موجود على هذا النظام (تطبيق
        // يبدو فارغًا، أو فشل عند الإقلاع). التحذير يكفي ليُصلح المفتاح.
        if (kRunTarget != real) {
          debugPrint(
            '⚠️ RunTarget: مطلوب «${kRunTarget.name}» والنظام الفعلي «${real.name}» ⇒ يُستخدم الفعلي. عدّل kRunTarget في lib/config/run_target.dart.',
          );
          return real;
        }
        return real;
    }
  }

  /// النظام الفعلي من نظام التشغيل نفسه — لا علاقة له بالمفتاح.
  static RunTarget _realOs() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return RunTarget.windows;
    }
    return RunTarget.android;
  }

  /// تهيئة محرّك قاعدة البيانات. **تُنادى مرة واحدة في `main()` قبل أي
  /// لمس للقاعدة** (وقبل `runPendingMigrations` وقراءة الجلسة والترخيص).
  ///
  /// على أندرويد لا تفعل شيئًا عن قصد: يبقى محرّك `sqflite` الأصلي كما هو
  /// بالحرف، فلا يتغيّر سلوك أي تثبيت قائم.
  static void prepareDatabaseEngine() {
    if (!isDesktop) return;

    // على سطح المكتب لا يوجد تنفيذ `sqflite` أصلي، فنحوّل المصنع العام إلى
    // تنفيذ ffi. `sqfliteFfiInit` تُحمّل مكتبة sqlite3 المشتركة.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    debugPrint('قاعدة البيانات: محرّك ffi ($label).');
  }

  /// مجلد قاعدة البيانات — المسار الوحيد المختلف بين النظامين.
  static Future<String> resolveDatabaseDirectory() async {
    if (!isDesktop) {
      // أندرويد: مسار النظام الأصلي **كما هو**. لا تُغيّره.
      return getDatabasesPath();
    }

    // ويندوز: مجلد دعم التطبيق (`%APPDATA%\<الشركة>\<التطبيق>`).
    // لا نستخدم Documents: هو مجلد المستخدم الشخصي، والنسخ الاحتياطي يذهب
    // إليه بالفعل — فلا نخلط ملف قاعدة البيانات بملفات المستخدم.
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// المسار الكامل لملف قاعدة البيانات (يستخدمه النسخ الاحتياطي والاستعادة).
  static Future<String> resolveDatabaseFile(String fileName) async {
    return p.join(await resolveDatabaseDirectory(), fileName);
  }
}
