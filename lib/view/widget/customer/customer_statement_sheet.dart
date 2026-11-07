import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/services/invoice_share_service.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/controller/customer/customer_statement_controller.dart';
import 'package:laundry/services/customer/customer_statement_service.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// كشف حساب الزبون — قائمة إجراءات واحدة تُستدعى من كل الشاشات.
///
/// **لماذا ملف مشترك؟** الكشف يُطلب من ثلاث شاشات (حساب الزبون، أعمار الديون،
/// قائمة الزبائن). تكرار بناء القائمة في كل شاشة هو نفس الخطأ الذي جعل منطق
/// FIFO يتفرّع سابقًا ويُضيع أرصدة العملاء صامتًا. فالمنطق هنا مرة واحدة.
///
/// **الفترة**: الإجراءات كلها تحترم الفترة المختارة في [CustomerStatementController]
/// (كل الفترة · هذا الشهر · الشهر الماضي · آخر ٣٠ يومًا · مدى مخصّص).
///
/// [onQuickView] اختياري: إجراء «عرض سريع على الشاشة» الذي توفّره بعض الشاشات
/// (قائمة الزبائن) لعرض الملخّص داخل التطبيق بلا طباعة.
Future<void> showCustomerStatementSheet(
  BuildContext context,
  int customerId, {
  String? customerName,
  VoidCallback? onQuickView,
}) async {
  final stmt = Get.put(CustomerStatementController(), permanent: false);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('كشف الحساب'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (customerName != null && customerName.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  customerName,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const Divider(height: 20),

            // ─── الفترة (تُطبَّق على الطباعة والمشاركة والملخّص) ───
            Obx(
              () => ListTile(
                leading: const Icon(Icons.date_range, color: AppColors.primary),
                title: Text(
                  tr('الفترة'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  stmt.rangeLabel,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                trailing: const Icon(Icons.tune, size: 18),
                onTap: () => _pickPeriod(ctx, stmt),
              ),
            ),
            const Divider(height: 12),

            if (onQuickView != null)
              ListTile(
                leading: const Icon(Icons.visibility, color: AppColors.warning),
                title: Text(
                  tr('عرض سريع على الشاشة'),
                  style: const TextStyle(fontFamily: 'cairo'),
                ),
                subtitle: Text(
                  tr('ملخّص فوري بلا طباعة'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onQuickView();
                },
              ),
            // ─── طباعة ───
            ListTile(
              leading: const Icon(Icons.print, color: AppColors.primary),
              title: Text(
                tr('طباعة كشف الحساب'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
              subtitle: Obx(
                () => Text(
                  stmt.rangeLabel,
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                stmt.export(customerId);
              },
            ),
            // ─── طباعة + حفظ PDF ───
            //
            // خيار مدمج كنمط الفاتورة: يطبع **و**يحفظ نسخة PDF في إجراء واحد.
            // الفصل بين «طباعة» و«حفظ» كان يجعل الكاشير يطبع ثم يعيد فتح
            // القائمة ليحفظ — بينما الفاتورة تفعل الأمرين معًا.
            ListTile(
              leading: const Icon(
                Icons.print_outlined,
                color: AppColors.violet,
              ),
              title: Text(
                tr('طباعة + حفظ PDF'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
              subtitle: Text(
                tr('يطبع الكشف ويحفظ نسخة PDF في المجلد'),
                style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                stmt.export(customerId, printAndSave: true);
              },
            ),
            // ─── إرسال PDF عبر واتساب ───
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: AppColors.danger,
              ),
              title: Text(
                tr('إرسال الكشف PDF (واتساب)'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
              subtitle: Obx(
                () => Text(
                  stmt.rangeLabel,
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                stmt.export(customerId, share: true);
              },
            ),
            // ─── حفظ الكشف كملف PDF ───
            //
            // كان الحفظ يحدث كأثر جانبي لفشل الطباعة فقط، وفي مجلد مؤقّت.
            // صار قرارًا صريحًا يكتب في مجلد المستندات الذي يختاره المستخدم.
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                tr('حفظ الكشف PDF'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
              subtitle: Text(
                tr('في مجلد حفظ المستندات — بلا طباعة'),
                style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                stmt.export(customerId, savePdfOnly: true);
              },
            ),
            // ─── إرسال ملخّص نصّي عبر واتساب ───
            ListTile(
              leading: const Icon(Icons.chat, color: AppColors.info),
              title: Text(
                tr('إرسال ملخّص نصّي (واتساب)'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
              subtitle: Text(
                tr('رسالة نصّية بلا ملف مرفق'),
                style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final r = stmt.selectedRange.value;
                final s = await CustomerStatementService.instance.build(
                  customerId,
                  from: r?.start,
                  to: r?.end,
                );
                if (s == null) return;
                await InvoiceShareService.openWhatsAppChat(
                  s.phone,
                  stmt.summaryText(s),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// اختيار الفترة: إعدادات جاهزة أو مدى مخصّص من منتقي التاريخ.
///
/// 🚨 **لا تُمرّر `locale: Locale('ar')` هنا — كان يُنهي التطبيق (أُصلح
/// 2026-10-03).** السبب الدقيق:
/// 1. `MaterialApp` في `main.dart` يضبط `locale: Locale('ar')` **بلا**
///    `localizationsDelegates` ولا `flutter_localizations` في `pubspec`، و
///    `supportedLocales` الافتراضية `[en_US]`. و`LocalizationsResolver.locale`
///    يحسم اللغة المطلوبة **مقابل `supportedLocales`** ⇒ يهبط إلى `en_US`.
///    لهذا يعمل التطبيق كله بالإنجليزية داخليًا بلا مشكلة.
/// 2. أما `showDateRangePicker(locale: ar)` فيلفّ الحوار بـ
///    `Localizations.override(locale: ar)` — انظر
///    `flutter/lib/src/material/date_picker.dart:1268` (Flutter 3.41.6) —
///    أي **يتجاوز** ذلك الحسم ويفرض `ar` على الشجرة.
/// 3. و`_MaterialLocalizationsDelegate.isSupported` في
///    `flutter/lib/src/material/material_localizations.dart:726` تقبل
///    الإنجليزية فقط: `locale.languageCode == 'en'` ⇒ لا يُحمَّل أي
///    `MaterialLocalizations` للعربية، فيرجع `MaterialLocalizations.of(context)`
///    قيمة `null` (`Localizations.of<...>(...)!`).
/// 4. النتيجة: في debug يُرمى `No MaterialLocalizations found …`
///    (أُثبت باختبار widget)، وفي **release** تُجرَّد الـasserts فيبقى
///    `!` على `null` ⇒ انهيار صريح يوقف التطبيق.
///
/// الحلّ الصحيح الكامل = إضافة `flutter_localizations` و
/// `GlobalMaterialLocalizations.delegate` + `supportedLocales: [ar, en]`
/// (تحسين منفصل لأنه يعكس اتجاه التطبيق كله إلى RTL). وترك `locale` بلا
/// تمرير يجعل المنتقي يرث لغة التطبيق فيعمل بلا انهيار.
Future<void> _pickPeriod(
  BuildContext ctx,
  CustomerStatementController stmt,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final firstThisMonth = DateTime(now.year, now.month, 1);
  final lastMonthEnd = firstThisMonth.subtract(const Duration(days: 1));

  final choice = await showModalBottomSheet<String>(
    context: ctx,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            tr('الفترة'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 20),
          _opt(c, 'all', tr('كل الفترة'), tr('بلا تقييد تاريخي')),
          _opt(c, 'thisMonth', tr('هذا الشهر'), tr('من أول الشهر إلى اليوم')),
          _opt(c, 'lastMonth', tr('الشهر الماضي'), tr('الشهر السابق كاملًا')),
          _opt(c, 'last30', tr('آخر ٣٠ يومًا'), tr('من اليوم رجوعًا')),
          _opt(c, 'custom', tr('من تاريخ إلى تاريخ'), tr('أحدّد البداية والنهاية')),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return;
  // الحوار الأول أُغلق ⇒ قد يصير `ctx` غير مثبَّت قبل فتح منتقي التاريخ.
  if (!ctx.mounted) return;

  switch (choice) {
    case 'all':
      stmt.setRange(null);
    case 'thisMonth':
      stmt.setRange(DateTimeRange(start: firstThisMonth, end: today));
    case 'lastMonth':
      stmt.setRange(
        DateTimeRange(
          start: DateTime(lastMonthEnd.year, lastMonthEnd.month, 1),
          end: lastMonthEnd,
        ),
      );
    case 'last30':
      stmt.setRange(
        DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today),
      );
    case 'custom':
      final picked = await showDateRangePicker(
        context: ctx,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: stmt.selectedRange.value,
        // ⚠️ لا `locale` — تمرير `ar` يُنهي التطبيق (السبب مفصّل في ترويسة
        // `_pickPeriod`). المنتقي يرث لغة التطبيق.
      );
      if (picked != null) stmt.setRange(picked);
  }
}

ListTile _opt(BuildContext ctx, String value, String title, String subtitle) =>
    ListTile(
      title: Text(title, style: const TextStyle(fontFamily: 'cairo')),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
      ),
      onTap: () => Navigator.pop(ctx, value),
    );
