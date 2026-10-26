// حرس طبقة الطباعة — يمنع رجوع **الفشل الصامت** وضياع المقاس.
//
// لماذا هذا الحرس؟ لأن عطلًا حقيقيًا وقع ولم يمسكه أي حارس: كانت الطباعة
// تُقبل وتُسلَّم **بلا ورق** (تعريف نصّي على ويندوز) والتطبيق يبلّغ بالنجاح،
// ثم كان المقاس لا يُمرَّر فيُستخدم A4 لإيصال 80 مم.
//
// التشغيل: dart run tool/verify_printer_service.dart
// (تحليل نصّي بلا Flutter — يعمل في هذه البيئة التي يتعذّر فيها flutter analyze)
import 'dart:io';

int _pass = 0;
int _fail = 0;
final List<String> _errors = <String>[];

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    _errors.add('  ✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

/// يزيل تعليقات `//` كي لا يُحسب كودٌ موثَّق كأنه منفَّذ.
String stripComments(String src) {
  final out = <String>[];
  for (final line in src.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('//') || t.startsWith('///')) continue;
    out.add(line);
  }
  return out.join('\n');
}

String read(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  final service = read('lib/services/printer/printer_service.dart');
  final output = read('lib/services/invoice/invoice_output_service.dart');
  final settings = read('lib/view/screen/settings/settings_sections.dart');
  final shift = read('lib/controller/shift_controller.dart');
  final statement = read('lib/controller/customer/customer_statement_controller.dart');
  final previous = read('lib/controller/previousinvoicecontroller.dart');

  final svc = stripComments(service);

  // ── [1] الملفات موجودة ───────────────────────────────────────────
  check('[1] printer_service.dart موجود', service.isNotEmpty);
  check('[1] invoice_output_service.dart موجود', output.isNotEmpty);

  // ── [2] توقيع printPdf يقبل المقاس ──────────────────────────────
  check('[2] printPdf تقبل `PaperSize? paper`', svc.contains('PaperSize? paper'),
      'بدونها يُرسَل إيصال 80 مم بقياس A4');
  check('[2] formatFor تُمرَّر إلى format:',
      svc.contains('format: formatFor(paper)'));
  check('[2] formatFor تبني PdfPageFormat من mm',
      svc.contains('PaperSizes.mmToPoints(paper.widthMm)'));

  // ── [3] إعدادات التعريف على ويندوز ──────────────────────────────
  check('[3] usePrinterSettings مُمرَّرة', svc.contains('usePrinterSettings:'),
      'غيابها يبني DEVMODE مخصّصًا ترفضه بعض التعريفات');
  check('[3] usePrinterSettings تُمرَّر من المحاولة (لا قيمة ثابتة)',
      svc.contains('usePrinterSettings: usePrinterSettings'),
      'تثبيتها على false تُفشل CreateDC عند بعض التعريفات');
  check('[3] dynamicLayout: false (مستند جاهز)',
      svc.contains('dynamicLayout: false'));

  // ── [4] محاولتان لكل تعريف (لا حجب مسبق) ───────────────────────
  //
  // كان في نسخة سابقة حجب مسبق لأي تعريف اسمه «Text Only» — وكان **خطأً**:
  // المستخدم يطبع PDF بنجاح على نفس الجهاز من برامج أخرى. الحجب منع أي
  // محاولة. الصواب: **جرّب** ثم أبلِغ.
  check('[4] لا حجب مسبق باسم التعريف',
      !svc.contains('isTextOnlyDriver'),
      'الحجب المسبق يمنع طباعة تعمل فعلًا');
  check('[4] محاولتان: إعدادات التعريف ثم مقاس المستند',
      RegExp(r'_attempt\(bytes, target, jobName, paper, true\)')
              .hasMatch(svc) &&
          RegExp(r'_attempt\(bytes, target, jobName, paper, false\)')
              .hasMatch(svc),
      'تعريف يرفض DEVMODE يحتاج المحاولة الثانية');

  // ── [5] لا فشل صامت: lastIssue مضبوطة في كل مسار ────────────────
  check('[5] حقل lastIssue موجود', svc.contains('String? lastIssue'));
  check('[5] يُصفَّر في بداية كل محاولة',
      svc.contains('lastIssue = null;'));
  final issueSets = RegExp(r'lastIssue\s*=').allMatches(svc).length;
  check('[5] lastIssue تُضبط في مسارات الفشل (≥6)',
      issueSets >= 6, 'وجدنا $issueSets');
  check('[5] مهلة زمنية على كل محاولة',
      svc.contains('.timeout(') && svc.contains('TimeoutException'));
  // 🚨 `directPrintPdf` ترجع `FutureOr<bool>` لا `Future<bool>` ⇒ لا تملك
  // `.timeout`. كُتبت أولًا `Printing.directPrintPdf(...).timeout(...)` فسقط
  // البناء كله. الحل: تُغلَّف في `Future<bool>.value` ثم تُسقَط المهلة.
  check('[5] directPrintPdf مُغلَّفة في Future<bool>.value (FutureOr لا يملك timeout)',
      svc.contains('Future<bool>.value('),
      'FutureOr<bool> لا يملك .timeout — البناء يفشل');
  check('[5] المهلة على المتغيّر لا على النداء',
      svc.contains('pending.timeout('));
  check('[5] فحص availability',
      svc.contains('target.isAvailable'));

  // ── [6] مسار البيع يقرأ المقاس ويُبلّغ ──────────────────────────
  check('[6] deliver يقرأ invoicePaperSize',
      output.contains('invoicePaperSize'));
  check('[6] deliver يمرّر paper:',
      output.contains('paper: paper'));
  check('[6] deliver يقرأ lastIssue',
      output.contains('PrinterService.instance.lastIssue'));

  // ── [7] كل نداء printPdf يمرّر المقاس ──────────────────────────
  for (final entry in <String, String>{
    'shift_controller': shift,
    'customer_statement_controller': statement,
    'previousinvoicecontroller': previous,
    'invoice_output_service': output,
  }.entries) {
    check('[7] ${entry.key} يمرّر paper:',
        entry.value.contains('paper: '),
        'المقاس الافتراضي A4 سيُستخدم خطأً');
  }

  // ── [8] الطباعة لا تتجاوز الطبقة الواحدة ────────────────────────
  final direct = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('printer_service.dart')) continue;
    final s = stripComments(f.readAsStringSync());
    if (s.contains('Printing.layoutPdf') ||
        s.contains('Printing.directPrintPdf')) {
      direct.add(f.path.replaceAll('\\', '/'));
    }
  }
  check('[8] لا نداء مباشر لـPrinting خارج PrinterService',
      direct.isEmpty, direct.join(', '));

  // ── [9] لا إنذار كاذب في الإعدادات ─────────────────────────────
  check('[9] الإعدادات بلا لافتة «تعريف لا يطبع PDF»',
      !settings.contains('_driverWarning('),
      'إنذار كاذب يمنع الثقة في بقية الرسائل');

  stdout.writeln('─' * 62);
  stdout.writeln('حرس طبقة الطباعة');
  stdout.writeln('─' * 62);
  for (final e in _errors) {
    stdout.writeln(e);
  }
  stdout.writeln('نجح: $_pass · فشل: $_fail');
  if (_fail > 0) exit(1);
  stdout.writeln('✅ كل الفحوص نجحت');
}
