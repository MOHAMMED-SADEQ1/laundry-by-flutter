/// قواعد تسمية ملفات فواتير PDF — **منطق خالص** (بلا Flutter وبلا قاعدة بيانات).
///
/// **لماذا ملف منفصل:** اسم الملف هو موضع الخطأ الفعلي — محرف ممنوع على
/// ويندوز يُفشل الحفظ، واسم مكرر يمحو فاتورة محفوظة. ولأن المنطق خالص فهو
/// قابل للاختبار بمشغّل Dart مباشر بلا قاعدة بيانات:
///
///     dart run tool/verify_invoice_pdf_naming.dart
library;

import 'package:laundry/services/database/backup_naming.dart';

class InvoicePdfNaming {
  InvoicePdfNaming._();

  /// امتداد ملف الفاتورة.
  static const String extension = 'pdf';

  /// بادئة اسم الملف.
  static const String prefix = 'فاتورة';

  /// الاسم القياسي: `فاتورة-1042_2026-10-13.pdf`.
  ///
  /// **بلا نقطتين:** تاريخ ISO (`toIso8601String`) يحوي `:` وهي **مرفوضة على
  /// ويندوز** ومحرفة بصريًا، فالتاريخ يُبنى يدويًا بأجزاء مرقّمة — نفس نهج
  /// [BackupNaming.buildBackupFileName]. ورقم الفاتورة فريد أصلًا، فالتاريخ
  /// هنا للترتيب الزمني في المجلد لا لتمييز الملف.
  static String buildFileName({
    required int invoiceNumber,
    required DateTime when,
  }) {
    // `toLocal` صريحة: الطوابع في المشروع محلية، ولا نريد أي تحويل منطقة
    // زمنية يزيح اليوم (نفس درس `DATE(x,'localtime')`).
    final d = when.toLocal();
    final date =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final stem = '$prefix-$invoiceNumber';
    return '${stem}_$date.$extension';
  }

  /// يمنع الكتابة فوق ملف قائم: `فاتورة-1042_2026-10-13_2.pdf` ثم `_3`…
  ///
  /// يعيد استخدام قاعدة [BackupNaming.dedupeName] نفسها (مقارنة بلا حساسية
  /// لحالة الأحرف، لأن ويندوز لا يفرّق بين `A.pdf` و`a.pdf`) — فلا تتفرّع
  /// قاعدتان لنفس المشكلة.
  static String dedupe(String name, Set<String> existing) =>
      BackupNaming.dedupeName(name, existing);

  /// يطهّر جذرًا حرًّا (بلا امتداد) إلى اسم صالح على كل الأنظمة.
  ///
  /// **لماذا لا نُعيد استخدام [BackupNaming.sanitizeBackupName]؟** لأنها
  /// تُلحق امتداد `.db` وتستبدل الاسم الفارغ باسم نسخة احتياطية — سلوك صحيح
  /// للنسخ وخاطئ لمستند PDF.
  ///
  /// تُنزع المسارات (لو لصق المستخدم مسارًا)، وتُستبدل المحارف الممنوعة
  /// و[\x00-\x1F] بـ`_`، وتُضغط المسافات والشرطات السفلية المتتالية، ويُقصّ
  /// الطول إلى 100 محرف. الفراغ يعود إلى `document` (اسم لاتيني محايد، لا
  /// نصّ واجهة يُترجم).
  static String sanitizeStem(String raw) {
    var name = raw.trim();
    final sep = name.lastIndexOf(RegExp(r'[\\/]'));
    if (sep >= 0) name = name.substring(sep + 1);

    final buffer = StringBuffer();
    for (final rune in name.runes) {
      final ch = String.fromCharCode(rune);
      if (rune < 32 || rune == 127 || BackupNaming.forbiddenChars.contains(ch)) {
        buffer.write('_');
      } else {
        buffer.write(ch);
      }
    }
    name = buffer.toString();
    name = name.replaceAll(RegExp(r'[\s_]+'), '_');
    name = name.replaceAll(RegExp(r'\.{2,}'), '.');
    name = name.replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '');
    if (name.isEmpty) return 'document';
    if (name.length > 100) name = name.substring(0, 100);
    return name;
  }

  /// اسم ملف أي مستند: `<الجذر المطهَّر>_<التاريخ>.pdf`.
  ///
  /// التاريخ ليس للتمييز (الجذر يحمل رقم الزبون أو الوردية) بل للترتيب
  /// الزمني في المجلد، وبدونه يمتلئ المجلد بأسماء متشابهة لا يُعرف أيّها
  /// الأحدث إلا بفتحها.
  static String buildDocumentFileName(String stem, {DateTime? when}) {
    final d = (when ?? DateTime.now()).toLocal();
    final date =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${sanitizeStem(stem)}_$date.$extension';
  }
}
