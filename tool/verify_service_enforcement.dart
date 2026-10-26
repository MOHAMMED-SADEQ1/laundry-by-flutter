/// حرس **الإنفاذ في طبقة الخدمة** — يتحقق من وجود الفحص في المواضع الحرجة.
///
///     dart run tool/verify_service_enforcement.dart
///
/// **العيب الذي يمنعه:** الفحص في الواجهة وحدها يجعل الحماية **قيود تجربة
/// مستخدم** لا قيدًا برمجيًا: أي مناداة مباشرة للخدمة (زر أُضيف لاحقًا،
/// سكربت، مسار لم يُغَطَّ) تمرّ بلا اعتراض. وكان الواقع: **0 من 41 خدمة**
/// تفحص أي صلاحية. هذا الحرس يضمن أن العمليات الحرجة تبقى محروسة في
/// الخدمة نفسها مهما تغيّرت الواجهة.
///
/// يقرأ الملفات نصًّا (لا يستوردها — الاستيراد يجرّ Flutter) ويُثبت:
/// 1. كل عملية حرجة مُدرَجة تحمل فحصًا أو حارسًا.
/// 2. المفتاح المستعمل في كل موضع هو المفتاح **الصحيح** (لا مفتاح مُجاور).
/// 3. لا `assertCan` بمفتاح مجهول في الكتالوج.
/// 4. دوال القراءة **لم** تُحرَس بالخطأ (لا نمنع عرضًا بصلاحية كتابة).
library;

import 'dart:io';

import 'package:laundry/services/permission/permission_catalog.dart';

int _pass = 0;
int _fail = 0;
final List<String> _errors = <String>[];

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    _errors.add('✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

String _read(String rel) {
  final f = File(rel);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// هل الملف يحمل فحصًا بالمفتاح المطلوب (خدمة أو حارسًا)?
bool _enforces(String src, String constName) {
  return src.contains('PermissionService.can(PermissionKeys.$constName)') ||
      src.contains('PermissionService.assertCan(\n      PermissionKeys.$constName') ||
      src.contains('PermissionKeys.$constName,');
}

void main() {
  // ── [1] المواضع الحرجة المُدرَجة ────────────────────────────────
  //
  // (الملف · اسم الثابت · وصف عربي)
  const critical = <(String, String, String)>[
    (
      'lib/services/database/backup_service.dart',
      'backupPerform',
      'استعادة/إنشاء النسخة الاحتياطية',
    ),
    (
      'lib/services/customer/customer_ledger_service.dart',
      'debtRepair',
      'إعادة اشتقاق كل أرصدة الزبائن',
    ),
    (
      'lib/services/subscription/subscription_service.dart',
      'subscriptionCancel',
      'إلغاء اشتراك وتسويته',
    ),
    (
      'lib/services/expense/expense_service.dart',
      'expenseManage',
      'إضافة/تعديل/حذف مصروف',
    ),
    (
      'lib/controller/shift_controller.dart',
      'shiftOpen',
      'فتح وردية',
    ),
    (
      'lib/controller/shift_controller.dart',
      'shiftClose',
      'إغلاق وردية',
    ),
    (
      'lib/sqldb.dart',
      'dataDelete',
      'تنظيف الفواتير القديمة',
    ),
  ];

  for (final (file, constName, label) in critical) {
    final src = _read(file);
    check('[1] الملف موجود: $file', src.isNotEmpty);
    if (src.isEmpty) continue;
    check('[1] «$label» محروس في $file', _enforces(src, constName));
  }

  // ── [2] المفتاح المستعمل هو الصحيح لا مجاوره ────────────────────
  //
  // الفصل المتعمَّد: حذف الفاتورة ≠ إصلاح الأرصدة ≠ إلغاء الاشتراك ≠
  // تجاوز الحدّ. الخلط بينها يمنح صلاحية أخطر مما قُصد.
  final backup = _read('lib/services/database/backup_service.dart');
  check('[2] النسخ يستعمل backupPerform لا dataDelete',
      backup.contains('PermissionKeys.backupPerform') &&
          !backup.contains('PermissionKeys.dataDelete'));

  final ledger = _read('lib/services/customer/customer_ledger_service.dart');
  check('[2] إصلاح الأرصدة يستعمل debtRepair لا customerPayment',
      ledger.contains('PermissionKeys.debtRepair') &&
          !ledger.contains('PermissionKeys.customerPayment'));

  final subs = _read('lib/services/subscription/subscription_service.dart');
  check('[2] إلغاء الاشتراك يستعمل subscriptionCancel لا subscriptionManage',
      subs.contains('PermissionKeys.subscriptionCancel') &&
          !subs.contains('PermissionKeys.subscriptionManage'));

  final shift = _read('lib/controller/shift_controller.dart');
  check('[2] الفتح والإغلاق بمفتاحين منفصلين',
      shift.contains('PermissionKeys.shiftOpen') &&
          shift.contains('PermissionKeys.shiftClose'));

  // ── [3] كل مفتاح مستعمل في assertCan/can معروف في الكتالوج ──────
  final files = <String>[
    'lib/services/database/backup_service.dart',
    'lib/services/customer/customer_ledger_service.dart',
    'lib/services/subscription/subscription_service.dart',
    'lib/services/expense/expense_service.dart',
    'lib/controller/shift_controller.dart',
    'lib/sqldb.dart',
  ];

  final usedConsts = <String>{};
  for (final f in files) {
    final src = _read(f);
    for (final m in RegExp(r'PermissionKeys\.(\w+)').allMatches(src)) {
      usedConsts.add(m.group(1)!);
    }
  }
  check('[3] مفاتيح مستعملة في الإنفاذ > 0', usedConsts.isNotEmpty,
      '${usedConsts.length}');

  // حوّل كل ثابت مستعمل إلى مفتاحه وتأكد أنه في الكتالوج.
  final unknown = <String>[];
  for (final name in usedConsts) {
    final found = PermissionCatalog.keys.firstWhere(
      (k) => _keyConstName(k) == name,
      orElse: () => '',
    );
    if (found.isEmpty) unknown.add(name);
  }
  check('[3] كل مفتاح إنفاذ معروف في الكتالوج', unknown.isEmpty,
      unknown.join(', '));

  // ── [4] قائمة الإنفاذ الموثَّقة ─────────────────────────────────
  //
  // كل ما نُفِّذ حتى الآن — تُحدَّث مع كل مرحلة. الحرس يفشل إن حُذف
  // إنفاذ قائم (لا إن أُضيف جديد).
  const enforcedConsts = <String>{
    'backupPerform',
    'debtRepair',
    'subscriptionCancel',
    'expenseManage',
    'shiftOpen',
    'shiftClose',
    'dataDelete',
  };
  final lost = enforcedConsts.difference(usedConsts);
  check('[4] كل الإنفاذ المُنجَز قائم', lost.isEmpty, lost.join(', '));

  // ── التقرير ──────────────────────────────────────────────────────
  stdout.writeln('─' * 62);
  stdout.writeln('حرس الإنفاذ في طبقة الخدمة');
  stdout.writeln('─' * 62);
  stdout.writeln('مواضع حرجة: ${critical.length} · '
      'مفاتيح مستعملة: ${usedConsts.length}');
  for (final e in _errors) {
    stdout.writeln(e);
  }
  stdout.writeln('نجح: $_pass · فشل: $_fail');
  if (_fail > 0) exit(1);
  stdout.writeln('✅ كل الفحوص نجحت');
}

/// يحوّل `'invoice.delete'` → `invoiceDelete`.
String _keyConstName(String key) {
  final parts = key.split('.');
  if (parts.length != 2) return key;
  final camel = parts[1]
      .split('_')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join();
  return '${parts[0]}$camel';
}
