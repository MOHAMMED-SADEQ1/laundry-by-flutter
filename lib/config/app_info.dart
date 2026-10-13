/// مصدر وحيد لبيانات الإصدار.
///
/// كان رقم الإصدار مكتوبًا يدويًا في الواجهة (`1.2.0`) ومختلفًا عن
/// `pubspec.yaml` (`1.1.2+1`) — فأصبح المستخدم يرى رقمًا لا يطابق النسخة
/// المبنية فعلًا. الآن يُقرأ الرقم من [PackageInfo] مرة واحدة عند بدء التطبيق.
class AppInfo {
  AppInfo._();

  static const String fallbackVersion = '1.2.0';

  // ─── حقوق المطوّر (مصدر وحيد يُستعمل في كل شاشات النظام والطباعة) ───
  /// الاسم كما يُعرَض في نافذة «مطوّر النظام»
  static const String developerName = 'مطوّر النظام — المهندس محمد صادق';

  /// جملة حقوق المطوّر التي تُعرض في شاشات النظام والفواتير
  static const String developerCredit = 'برمجة وتطوير المهندس محمد صادق';

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
