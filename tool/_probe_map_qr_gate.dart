// مسبار: هل تُفتح **بوابة** رسم رمز الموقع بالقالب الحقيقي من قاعدة المستخدم؟
//
// يقرأ `doc_template_invoice` الفعلي من قاعدة البيانات الحيّة ويمرّره على
// `DocTemplateView.of` كما تفعل `PreparePDF.generatePdfData` تمامًا، ثم
// يفحص الشروط الثلاثة التي تحرس الرسم: التفعيل · الرابط · التسمية.
//
// التشغيل: dart run tool/_probe_map_qr_gate.dart
import 'dart:convert';
import 'dart:io';

import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/map_qr.dart';

const _db =
    r'C:/Users/MOHAMMED/AppData/Roaming/com.mohammadsadekaljafri/laundry/laundry_pos.db';

/// قراءة `settings` من SQLite بلا حزم إضافية — جدول بسيط مفتاح/قيمة.
String? _setting(String key) {
  final tmp = Directory.systemTemp.createTempSync('probe_gate');
  final copy = '${tmp.path}/copy.db';
  File(_db).copySync(copy);
  try {
    final out = Process.runSync('python', [
      '-c',
      'import sqlite3,sys,json;'
          'c=sqlite3.connect(r"$copy");'
          'r=c.execute("SELECT value FROM settings WHERE key=?",("$key",)).fetchone();'
          'print(json.dumps(r[0] if r else None))',
    ]);
    final raw = '${out.stdout}'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    return jsonDecode(raw) as String?;
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

void main() {
  final template = _setting('doc_template_invoice');
  final location = _setting('business_location') ?? '';
  print('business_location = ${jsonEncode(location)}');

  final decoded = template == null ? null : jsonDecode(template) as Map;
  // نفس الحمولة التي يبنيها `DocTemplateService.transport`.
  final data = <String, dynamic>{
    'docEnabled': decoded?['enabled'],
    'docTexts': decoded?['texts'],
    'docStyles': decoded?['styles'],
    'docLang': 'ar',
    'bizMapUrl': location,
  };

  final doc = DocTemplateView.of(data, DocKind.invoice);
  print('1) isOn(map_qr)      = ${doc.isOn(DocCatalog.kMapQr)}');
  print('2) MapQr.resolve     = ${jsonEncode(MapQr.resolve(location))}');
  print('3) caption           = ${jsonEncode(doc.text(DocCatalog.kMapQr, ''))}');

  final url = MapQr.resolve(location);
  final willPrint = doc.isOn(DocCatalog.kMapQr) && url.isNotEmpty;
  print('⇒ هل يُرسم الرمز؟    = $willPrint');

  // نفس الفحص برابط صحيح — لإثبات أن العائق هو القيمة لا الكود.
  final fixed = MapQr.repair(location);
  print('اقتراح الإصلاح        = ${jsonEncode(fixed)}');
  if (fixed.isNotEmpty) {
    final d2 = <String, dynamic>{...data, 'bizMapUrl': fixed};
    final doc2 = DocTemplateView.of(d2, DocKind.invoice);
    print('⇒ برابط مُصلَح        = '
        '${doc2.isOn(DocCatalog.kMapQr) && MapQr.resolve(fixed).isNotEmpty}');
  }
}
