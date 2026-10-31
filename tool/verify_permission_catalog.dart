/// حرس كتالوج الصلاحيات — منطق خالص، بلا قاعدة بيانات.
///
///     dart run tool/verify_permission_catalog.dart
///
/// **ما يحرسه:**
/// 1. تفرد المفاتيح وصحّة صيغتها (`group.action`).
/// 2. أن كل مجموعة مستعملة معرَّفة في [PermissionGroups] والمرجعية صحيحة.
/// 3. أن كل مفتاح في حِزم الزرع موجود في الكتالوج (لا مفتاح شبح).
/// 4. أن `admin` يملك **كل** الصلاحيات بلا استثناء (سلطة عليا دائمة).
/// 5. ألّا يملك أي دور حوكمةً عليا لم تُقصد (مثل `roles.manage` لغير
///    المدير النظام) — وهو تحقّق يمنع تسريب السلطة بالخطأ عند التعديل.
/// 6. الفصل المتعمَّد: `invoice.delete` ليست في حزمة الكاشير، و
///    `debt.repair` ليست في حزمة المحاسب، و`reports.profit` ليست للكاشير.
/// 7. أن `readWith` تشير إلى مفاتيح موجودة.
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

void main() {
  final all = PermissionCatalog.all;
  final keys = PermissionCatalog.keys;

  // ── [1] تفرد المفاتيح ────────────────────────────────────────────
  final seen = <String>{};
  final dupes = <String>[];
  for (final k in keys) {
    if (!seen.add(k)) dupes.add(k);
  }
  check('[1] لا مفتاح مكرَّر', dupes.isEmpty, dupes.join(', '));
  check('[1] العدد المعلن = العدد الفعلي',
      PermissionCatalog.count == all.length && all.length == keys.length);

  // ── [2] صيغة المفتاح والوسوم ─────────────────────────────────────
  final badFormat = <String>[];
  final emptyLabel = <String>[];
  final emptyDesc = <String>[];
  for (final item in all) {
    if (!RegExp(r'^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$').hasMatch(item.key)) {
      badFormat.add(item.key);
    }
    if (item.label.trim().isEmpty) emptyLabel.add(item.key);
    if (item.description.trim().length < 10) emptyDesc.add(item.key);
  }
  check('[2] صيغة المفاتيح group.action', badFormat.isEmpty,
      badFormat.join(', '));
  check('[2] كل صلاحية لها اسم', emptyLabel.isEmpty, emptyLabel.join(', '));
  check('[2] كل صلاحية لها شرح كافٍ', emptyDesc.isEmpty, emptyDesc.join(', '));

  // ── [3] المجموعات ────────────────────────────────────────────────
  final unknownGroup = <String>[];
  for (final item in all) {
    if (!PermissionGroups.ordered.contains(item.group)) {
      unknownGroup.add('${item.key} → ${item.group}');
    }
  }
  check('[3] كل مجموعة معرَّفة ومرتَّبة', unknownGroup.isEmpty,
      unknownGroup.join(', '));

  final coveredGroups = all.map((i) => i.group).toSet();
  final emptyGroups =
      PermissionGroups.ordered.where((g) => !coveredGroups.contains(g)).toList();
  check('[3] لا مجموعة مرتَّبة فارغة', emptyGroups.isEmpty,
      emptyGroups.join(', '));

  check(
      '[3] لكل مجموعة اسم عربي',
      PermissionGroups.ordered
          .every((g) => (PermissionGroups.labels[g] ?? '').trim().isNotEmpty));

  // ── [4] grouped يطابق ofGroup ────────────────────────────────────
  final grouped = PermissionCatalog.grouped;
  var groupedTotal = 0;
  var groupedOk = true;
  for (final entry in grouped.entries) {
    groupedTotal += entry.value.length;
    if (entry.value.length != PermissionCatalog.ofGroup(entry.key).length) {
      groupedOk = false;
    }
  }
  check('[4] grouped يغطّي كل الصلاحيات', groupedTotal == all.length,
      '$groupedTotal مقابل ${all.length}');
  check('[4] grouped مطابق لـofGroup', groupedOk);

  // ── [5] readWith ─────────────────────────────────────────────────
  final badReadWith = <String>[];
  for (final item in all) {
    for (final r in item.readWith) {
      if (!PermissionCatalog.isKnown(r)) badReadWith.add('${item.key} → $r');
      if (r == item.key) badReadWith.add('${item.key} → نفسه');
    }
  }
  check('[5] readWith تشير لمفاتيح معروفة', badReadWith.isEmpty,
      badReadWith.join(', '));

  // ── [6] حِزم الزرع: لا مفتاح شبح ─────────────────────────────────
  final bundles = <String, List<String>>{
    'admin': PermissionCatalog.adminBundle,
    'manager': PermissionCatalog.managerBundle,
    'cashier': PermissionCatalog.cashierBundle,
    'accountant': PermissionCatalog.accountantBundle,
    'worker': PermissionCatalog.workerBundle,
  };
  final ghost = <String>[];
  for (final entry in bundles.entries) {
    for (final k in entry.value) {
      if (!PermissionCatalog.isKnown(k)) ghost.add('${entry.key} → $k');
    }
  }
  check('[6] لا مفتاح شبح في أي حزمة', ghost.isEmpty, ghost.join(', '));

  // ── [7] admin = كل الصلاحيات ─────────────────────────────────────
  final adminSet = PermissionCatalog.adminBundle.toSet();
  final missingFromAdmin =
      keys.where((k) => !adminSet.contains(k)).toList(growable: false);
  check('[7] admin يملك كل الصلاحيات', missingFromAdmin.isEmpty,
      missingFromAdmin.join(', '));
  check('[7] admin هو الدور الجذر الوحيد',
      PermissionCatalog.isRootRole('admin') &&
          !PermissionCatalog.isRootRole('manager') &&
          !PermissionCatalog.isRootRole('cashier') &&
          !PermissionCatalog.isRootRole('accountant') &&
          !PermissionCatalog.isRootRole('worker'));

  // ── [8] لا تكرار داخل أي حزمة ────────────────────────────────────
  final dupInBundle = <String>[];
  for (final entry in bundles.entries) {
    final s = <String>{};
    for (final k in entry.value) {
      if (!s.add(k)) dupInBundle.add('${entry.key} → $k');
    }
  }
  check('[8] لا تكرار داخل الحزم', dupInBundle.isEmpty, dupInBundle.join(', '));

  // ── [9] الفصل المتعمَّد (القرارات التصميمية) ─────────────────────
  final manager = PermissionCatalog.managerBundle.toSet();
  final cashier = PermissionCatalog.cashierBundle.toSet();
  final accountant = PermissionCatalog.accountantBundle.toSet();
  final worker = PermissionCatalog.workerBundle.toSet();

  check('[9] المدير لا يملك إدارة الأدوار', !manager.contains('roles.manage'));
  check('[9] المدير لا يملك استعادة النسخة', !manager.contains('backup.perform'));
  check('[9] المدير لا يملك إدارة المستخدمين',
      !manager.contains('users.manage'));
  check('[9] المدير لا يملك تنظيف البيانات', !manager.contains('data.delete'));
  check('[9] المدير لا يملك إعدادات الترخيص',
      !manager.contains('settings.license'));
  check('[9] الكاشير لا يحذف فاتورة', !cashier.contains('invoice.delete'));
  check('[9] الكاشير لا يخصم', !cashier.contains('invoice.discount_apply'));
  check('[9] الكاشير لا يبيع آجلًا', !cashier.contains('invoice.sell_on_credit'));
  check('[9] الكاشير لا يرى الأرباح', !cashier.contains('reports.profit'));
  check('[9] الكاشير لا يصلح الأرصدة', !cashier.contains('debt.repair'));
  check('[9] الكاشير لا يدير الاشتراكات',
      !cashier.contains('subscription.manage'));
  check('[9] الكاشير لا يلمس الأصناف', !cashier.contains('category.manage'));
  check('[9] المحاسب لا يحذف فاتورة', !accountant.contains('invoice.delete'));
  check('[9] المحاسب لا يصلح الأرصدة', !accountant.contains('debt.repair'));
  check('[9] المحاسب لا يضبط حدّ ائتمان',
      !accountant.contains('customer.credit_limit'));
  check('[9] المحاسب لا يتجاوز حدّ ائتمان',
      !accountant.contains('customer.credit_limit_override'));
  check('[9] المحاسب لا يبيع آجلًا',
      !accountant.contains('invoice.sell_on_credit'));
  check('[9] المحاسب لا يدير الإعدادات', !accountant.contains('settings.manage'));
  check('[9] المحاسب يقرأ التقارير', accountant.contains('reports.view'));
  check('[9] المحاسب يرى الأرباح (قراءة)', accountant.contains('reports.profit'));
  check('[9] المحاسب يقرأ سجل التدقيق', accountant.contains('audit.view'));
  check('[9] العامل لا يلمس الصندوق', !worker.contains('shift.open'));
  check('[9] العامل يحدّث المصنعية', worker.contains('processing.update'));
  check('[9] العامل لا يرى التقارير', !worker.contains('reports.view'));

  // ── [10] الأدوار المزروعة ────────────────────────────────────────
  final roleNames = PermissionCatalog.seedRoles.map((r) => r.name).toList();
  check('[10] الأدوار الخمسة مزروعة',
      roleNames.length == 5 &&
          roleNames.contains('admin') &&
          roleNames.contains('manager') &&
          roleNames.contains('cashier') &&
          roleNames.contains('accountant') &&
          roleNames.contains('worker'));
  final noBundle = roleNames
      .where((r) => PermissionCatalog.defaultBundleOf(r) == null)
      .toList();
  check('[10] لكل دور مزروع حزمة', noBundle.isEmpty, noBundle.join(', '));
  check('[10] كل الأدوار المزروعة نظامية',
      PermissionCatalog.seedRoles.every((r) => r.isSystem));
  check('[10] labelOf يعرف الأدوار المزروعة',
      roleNames.every((r) => PermissionCatalog.roleLabelOf(r) != 'مستخدم' ||
          r == 'cashier'));
  check('[10] الدور المجهول يظهر «مستخدم»',
      PermissionCatalog.roleLabelOf('ghost') == 'مستخدم' &&
          PermissionCatalog.roleLabelOf(null) == 'مستخدم');

  // ── [11] الثوابت المشتقّة ────────────────────────────────────────
  check('[11] find/isKnown متسقان',
      keys.every((k) => PermissionCatalog.find(k) != null) &&
          PermissionCatalog.find('nope.nope') == null &&
          !PermissionCatalog.isKnown('nope.nope'));
  check('[11] byKey يغطّي الكل',
      PermissionCatalog.byKey.length == all.length);

  // ── [12] الخطر موسوم منطقيًا ─────────────────────────────────────
  // `invoice.delete` و`invoice.edit_issued` أُزيلا من الكتالوج (لا حذف فاتورة
  // صادرة ولا تحرير بعد الإصدار — التصحيح بإشعار دائن)، فلا يُدرَجان هنا.
  const mustBeDestructive = <String>[
    'customer.delete',
    'debt.repair',
    'subscription.cancel',
    'backup.perform',
    'data.delete',
  ];
  final notDestructive = mustBeDestructive
      .where((k) => PermissionCatalog.find(k)?.isDestructive != true)
      .toList();
  check('[12] العمليات الماحية موسومة', notDestructive.isEmpty,
      notDestructive.join(', '));

  check('[12] عمليات المال موسومة',
      PermissionCatalog.find('invoice.sell_on_credit')?.touchesMoney == true &&
          PermissionCatalog.find('invoice.discount_apply')?.touchesMoney ==
              true &&
          PermissionCatalog.find('expense.manage')?.touchesMoney == true);

  check('[12] صلاحيات الأمن موسومة',
      PermissionCatalog.find('users.manage')?.isSecurity == true &&
          PermissionCatalog.find('roles.manage')?.isSecurity == true &&
          PermissionCatalog.find('settings.manage')?.isSecurity == true);

  // ── [13] PermissionKeys تطابق الكتالوج ───────────────────────────
  //
  // الثوابت المُسمّاة تُستعمل في كل نداء `can`، فأي صلاحية في الكتالوج بلا
  // ثابت تعني أن المنادي سيُجبَر على كتابة نص حرّ (وهو مصدر الخطأ). وأي ثابت
  // بلا صلاحية هو مفتاح ميّت يمنع الجميع بصمت.
  const namedKeys = <String>[
    PermissionKeys.invoiceCreate,
    PermissionKeys.invoiceDiscountApply,
    PermissionKeys.invoiceSellOnCredit,
    PermissionKeys.invoiceDraft,
    PermissionKeys.invoicePrint,
    PermissionKeys.invoiceReprint,
    PermissionKeys.invoiceReturn,
    PermissionKeys.shiftOpen,
    PermissionKeys.shiftClose,
    PermissionKeys.cashView,
    PermissionKeys.expenseManage,
    PermissionKeys.customerView,
    PermissionKeys.customerManage,
    PermissionKeys.customerDelete,
    PermissionKeys.customerPayment,
    PermissionKeys.customerCreditLimit,
    PermissionKeys.customerCreditOverride,
    PermissionKeys.debtView,
    PermissionKeys.debtRepair,
    PermissionKeys.dashboardView,
    PermissionKeys.reportsView,
    PermissionKeys.reportsProfit,
    PermissionKeys.reportsTax,
    PermissionKeys.auditView,
    PermissionKeys.processingView,
    PermissionKeys.processingUpdate,
    PermissionKeys.subscriptionManage,
    PermissionKeys.subscriptionCancel,
    PermissionKeys.subscriptionUsageOverride,
    PermissionKeys.categoryManage,
    PermissionKeys.discountManage,
    PermissionKeys.settingsManage,
    PermissionKeys.settingsLicense,
    PermissionKeys.usersView,
    PermissionKeys.usersManage,
    PermissionKeys.rolesManage,
    PermissionKeys.backupPerform,
    PermissionKeys.dataDelete,
  ];
  check('[13] عدد ثوابت PermissionKeys يطابق الكتالوج',
      namedKeys.length == all.length,
      '${namedKeys.length} مقابل ${all.length}');
  final unnamed = keys.where((k) => !namedKeys.contains(k)).toList();
  final ghostConsts = namedKeys.where((k) => !keys.contains(k)).toList();
  check('[13] كل مفتاح في الكتالوج له ثابت', unnamed.isEmpty, unnamed.join(', '));
  check('[13] لا ثابت بلا صلاحية', ghostConsts.isEmpty, ghostConsts.join(', '));
  check('[13] لا ثابت مكرَّر',
      namedKeys.toSet().length == namedKeys.length);

  // ── التقرير ──────────────────────────────────────────────────────
  stdout.writeln('─' * 62);
  stdout.writeln('حرس كتالوج الصلاحيات');
  stdout.writeln('─' * 62);
  stdout.writeln('الصلاحيات: ${all.length} · المجموعات: ${grouped.length}');
  for (final entry in grouped.entries) {
    stdout.writeln(
        '  ${PermissionGroups.labelOf(entry.key)} (${entry.key}): '
        '${entry.value.length}');
  }
  stdout.writeln('─' * 62);
  for (final e in _errors) {
    stdout.writeln(e);
  }
  stdout.writeln('نجح: $_pass · فشل: $_fail');
  if (_fail > 0) {
    exit(1);
  }
  stdout.writeln('✅ كل الفحوص نجحت');
}
