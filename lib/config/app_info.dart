/// مصدر وحيد لبيانات الإصدار.
///
/// كان رقم الإصدار مكتوبًا يدويًا في الواجهة (`1.2.0`) ومختلفًا عن
/// `pubspec.yaml` (`1.1.2+1`) — فأصبح المستخدم يرى رقمًا لا يطابق النسخة
/// المبنية فعلًا. الآن يُقرأ الرقم من [PackageInfo] مرة واحدة عند بدء التطبيق.
library;

import 'package:laundry/services/i18n/l10n.dart';

class AppInfo {
  AppInfo._();

  static const String fallbackVersion = '1.2.0';

  // ─── حقوق المطوّر (مصدر وحيد يُستعمل في كل شاشات النظام والطباعة) ───
  //
  // 🚨 **النصّان يمرّان من `tr`**: كانا ثابتين عربيَّين (`const`) فلا
  // يترجمان أبدًا — فتبقى جملة الحقوق عربية في الواجهة الإنجليزية وحدها
  // بين كل النصوص. والثابت العربي هو **مفتاح** القاموس لا نصّ العرض.

  /// مفتاح القاموس: الاسم كما يُعرَض في نافذة «مطوّر النظام».
  static const String developerNameKey = 'مطوّر النظام — المهندس محمد صادق';

  /// مفتاح القاموس: جملة حقوق المطوّر التي تُعرض في الشاشات والفواتير.
  static const String developerCreditKey = 'برمجة وتطوير المهندس محمد صادق';

  /// الاسم بلغة الواجهة.
  static String get developerName => tr(developerNameKey);

  /// جملة الحقوق بلغة الواجهة.
  static String get developerCredit => tr(developerCreditKey);

  static const String developerEmail = 'mohammadsadekaljafri@gmail.com';
  static const String developerPhone = '0537498756';

  static String _version = fallbackVersion;
  static int _buildNumber = 0;

  /// رقم الإصدار كما هو في `pubspec.yaml` (مثال: `1.1.2`)
  static String get version => _version;

  /// رقم البناء (مثال: `1`)
  static int get buildNumber => _buildNumber;

  /// الإصدار مع رقم البناء (مثال: `1.1.2+1`)
  static String get full =>
      _buildNumber > 0 ? '$_version+$_buildNumber' : _version;

  /// يُحدَّث عند الإقلاع. يتجاهل الفشل بهدوء ويعود للقيمة الاحتياطية.
  static void set(String? version, [int? buildNumber]) {
    if (version != null && version.trim().isNotEmpty) {
      _version = version.trim();
    }
    if (buildNumber != null && buildNumber > 0) {
      _buildNumber = buildNumber;
    }
  }
}
