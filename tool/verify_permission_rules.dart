/// حرس منطق **القرار الفعلي** للصلاحيات — بلا قاعدة بيانات وبلا Flutter.
///
///     dart run tool/verify_permission_rules.dart
///
/// القرار الحقيقي في `PermissionService._compose` يقرأ من القاعدة، فيصعب
/// اختباره بلا SQLite. لكن **الخوارزمية** نفسها خالصة: (دور ← إسنادات) ثم
/// (تجاوزات فردية تُطبَّق فوقها بالترتيب). هذا الملف يعكسها حرفيًا ويُثبت:
///
/// 1. التجاوز الفردي **يعلو** الدور (منحًا ومنعًا).
/// 2. المنع الفردي يمحو صلاحية يملكها الدور.
/// 3. المنح الفردي يضيف صلاحية لا يملكها الدور.
/// 4. آخر تجاوزٍ فائز إن تكرّر المفتاح (لا تراكم).
/// 5. المفتاح المجهول في القاعدة **يُهمَل** (لا يُمنح ولا يُمنع).
/// 6. غياب المُدخل ⇒ ممنوع (فشل مُغلَق).
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

/// مرآة `PermissionService._compose` — الدور ثم التجاوز الفردي.
///
/// [roleKeys]: مفاتيح الدور كما قُرئت من `role_permissions`.
/// [overrides]: قائمة `(key, allow)` بترتيب القراءة من القاعدة.
Set<String> compose({
  required Iterable<String> roleKeys,
  required Iterable<({String key, bool allow})> overrides,
}) {
  final out = <String>{};

  for (final k in roleKeys) {
    if (PermissionCatalog.isKnown(k)) out.add(k);
  }
  for (final ov in overrides) {
    if (!PermissionCatalog.isKnown(ov.key)) continue;
    if (ov.allow) {
      out.add(ov.key);
    } else {
      out.remove(ov.key);
    }
  }
  return out;
}

void main() {
  // مفتاح فحص حقيقي: الكاشير لا يملكه والمدير يملكه — و`invoice.delete`
  // أُزيل من الكتالوج (لا حذف فاتورة صادرة) فلم يبقَ صالحًا كعيّنة.
  const sellOnCredit = PermissionKeys.invoiceSellOnCredit;
  const discountApply = PermissionKeys.invoiceDiscountApply;
  const reportsProfit = PermissionKeys.reportsProfit;

  // ── [1] التجاوز يعلو الدور ───────────────────────────────────────
  final base = compose(
    roleKeys: PermissionCatalog.cashierBundle,
    overrides: const [],
  );
  check('[1] الكاشير بلا تجاوز: لا بيع آجل', !base.contains(sellOnCredit));

  final withGrant = compose(
    roleKeys: PermissionCatalog.cashierBundle,
    overrides: const [(key: sellOnCredit, allow: true)],
  );
  check('[1] منح فردي يضيف ما لا يملكه الدور',
      withGrant.contains(sellOnCredit));

  final withDeny = compose(
    roleKeys: PermissionCatalog.managerBundle,
    overrides: const [(key: sellOnCredit, allow: false)],
  );
  check('[1] منع فردي يمحو ما يملكه الدور', !withDeny.contains(sellOnCredit));
  check('[1] المنع لا يمحو غير المستهدف',
      withDeny.contains(PermissionKeys.invoiceCreate) &&
          withDeny.contains(discountApply));

  // ── [2] المنع الفردي على صلاحية قراءة ────────────────────────────
  final managerProfit = compose(
    roleKeys: PermissionCatalog.managerBundle,
    overrides: const [],
  );
  check('[2] المدير يرى الأرباح بلا تجاوز', managerProfit.contains(reportsProfit));
  final managerNoProfit = compose(
    roleKeys: PermissionCatalog.managerBundle,
    overrides: const [(key: reportsProfit, allow: false)],
  );
  check('[2] المنع الفردي يُخفى الأرباح', !managerNoProfit.contains(reportsProfit));

  // ── [3] آخر تجاوز فائز ──────────────────────────────────────────
  final lastWins = compose(
    roleKeys: PermissionCatalog.cashierBundle,
    overrides: const [
      (key: sellOnCredit, allow: true),
      (key: sellOnCredit, allow: false),
    ],
  );
  check('[3] آخر تجاوز فائز (منح ثم منع)', !lastWins.contains(sellOnCredit));

  final lastWins2 = compose(
    roleKeys: PermissionCatalog.cashierBundle,
    overrides: const [
      (key: sellOnCredit, allow: false),
      (key: sellOnCredit, allow: true),
    ],
  );
  check('[3] آخر تجاوز فائز (منع ثم منح)', lastWins2.contains(sellOnCredit));

  // ── [4] المفتاح المجهول يُهمَل ──────────────────────────────────
  final unknownRoleKey = compose(
    roleKeys: [...PermissionCatalog.cashierBundle, 'ghost.permission'],
    overrides: const [],
  );
  check('[4] مفتاح دور مجهول لا يُمنح',
      !unknownRoleKey.contains('ghost.permission'));
  check('[4] المفتاح المجهول لا يُفسد الباقي',
      unknownRoleKey.contains(PermissionKeys.invoiceCreate));

  final unknownGrant = compose(
    roleKeys: PermissionCatalog.cashierBundle,
    overrides: const [(key: 'ghost.permission', allow: true)],
  );
  check('[4] تجاوز بمفتاح مجهول لا يُمنح',
      !unknownGrant.contains('ghost.permission'));

  final unknownDeny = compose(
    roleKeys: PermissionCatalog.adminBundle,
    overrides: const [(key: 'ghost.permission', allow: false)],
  );
  check('[4] تجاوز منع بمفتاح مجهول لا يُفسد الكل',
      unknownDeny.length == PermissionCatalog.count);

  // ── [5] فشل مُغلَق: لا قائمة ⇒ لا صلاحيات ───────────────────────
  final empty = compose(roleKeys: const [], overrides: const []);
  check('[5] لا إسنادات ⇒ مجموعة فارغة (فشل مُغلَق)', empty.isEmpty);

  // ── [6] admin = كل شيء، والقرار على الكتالوج كامل ───────────────
  final admin = compose(
    roleKeys: PermissionCatalog.adminBundle,
    overrides: const [],
  );
  check('[6] admin يملك كل المفاتيح',
      admin.length == PermissionCatalog.count,
      '${admin.length} مقابل ${PermissionCatalog.count}');

  // ── [7] الأدوار متدرّجة كما صُمّمت ──────────────────────────────
  Map<String, Set<String>> bundleMap() => {
        'admin': compose(roleKeys: PermissionCatalog.adminBundle, overrides: []),
        'manager':
            compose(roleKeys: PermissionCatalog.managerBundle, overrides: []),
        'cashier':
            compose(roleKeys: PermissionCatalog.cashierBundle, overrides: []),
        'accountant':
            compose(roleKeys: PermissionCatalog.accountantBundle, overrides: []),
        'worker':
            compose(roleKeys: PermissionCatalog.workerBundle, overrides: []),
      };
  final b = bundleMap();
  check('[7] admin ⊃ manager', b['admin']!.containsAll(b['manager']!));
  check('[7] العامل (${b['worker']!.length}) أضيق من الكاشير (${b['cashier']!.length})',
      b['worker']!.length < b['cashier']!.length);
  check('[7] المدير ⊃ الكاشير', b['manager']!.containsAll(b['cashier']!));

  // المحاسب **دور أصغر** لا نسخة من المدير: كله قراءة + قيود محاسبية،
  // ومجموعته **مجموعة جزئية** من المدير عمدًا (كل ما يملكه المدير يملكه
  // المحاسب؟ لا — بل كل ما يملكه المحاسب يملكه المدير). والفرق الجوهري أن
  // السلطة التصحيحية للمدير **حصرًا**.
  final managerOnly = b['manager']!.difference(b['accountant']!);
  final accountantOnly = b['accountant']!.difference(b['manager']!);
  check('[7] للمدير صلاحيات تصحيحية لا يملكها المحاسب',
      managerOnly.contains(PermissionKeys.customerCreditOverride) &&
          managerOnly.contains(PermissionKeys.debtRepair) &&
          managerOnly.contains(PermissionKeys.invoiceSellOnCredit));
  check('[7] المحاسب ⊆ المدير (لا يملك ما لا يملكه المدير)',
      accountantOnly.isEmpty, accountantOnly.join(', '));
  check('[7] المحاسب يقرأ الدفاتر (تقارير + ربح + ضريبة + تدقيق)',
      b['accountant']!.contains(PermissionKeys.reportsView) &&
          b['accountant']!.contains(PermissionKeys.reportsProfit) &&
          b['accountant']!.contains(PermissionKeys.reportsTax) &&
          b['accountant']!.contains(PermissionKeys.auditView));
  check('[7] المحاسب ممنوع من السلطة التصحيحية',
      !b['accountant']!.contains(PermissionKeys.customerCreditOverride) &&
          !b['accountant']!.contains(PermissionKeys.debtRepair) &&
          !b['accountant']!.contains(PermissionKeys.settingsManage) &&
          !b['accountant']!.contains(PermissionKeys.usersManage));
  check('[7] المحاسب يختلف عن الكاشير (ليس نسخة منه)',
      b['accountant']!.difference(b['cashier']!).isNotEmpty ||
          b['cashier']!.difference(b['accountant']!).isNotEmpty);

  // ── [8] readWith لا تُوسّع الإنفاذ ──────────────────────────────
  //
  // `readWith` قرينة **عرض** لا إنفاذ: صلاحية بـ`readWith` لا يجوز أن
  // تُضيف مفاتيح إلى أي دور تلقائيًا.
  var readWithUsed = false;
  for (final item in PermissionCatalog.all) {
    if (item.readWith.isNotEmpty) readWithUsed = true;
  }
  check('[8] readWith موجودة في الكتالوج (للواجهة)', readWithUsed);

  // ── التقرير ──────────────────────────────────────────────────────
  stdout.writeln('─' * 62);
  stdout.writeln('حرس قواعد قرار الصلاحيات');
  stdout.writeln('─' * 62);
  for (final e in _errors) {
    stdout.writeln(e);
  }
  stdout.writeln('نجح: $_pass · فشل: $_fail');
  if (_fail > 0) exit(1);
  stdout.writeln('✅ كل الفحوص نجحت');
}
