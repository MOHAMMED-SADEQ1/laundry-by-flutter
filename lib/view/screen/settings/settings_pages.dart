/// **صفحات الإعدادات الفرعية** — صفحة مستقلة لكل جزء من الإعدادات.
///
/// ## الفكرة
/// كانت الإعدادات صفحة واحدة طويلة (كل الأقسام فوق بعضها). صارت الآن **فهرسًا**
/// (`settings_screen.dart`) يضمّ بطاقات مدخلات، وكل مدخل ينقل إلى صفحة خاصة
/// به هنا. الفائدة: المستخدم يجد ما يريده بلا تمرير طويل، وكل صفحة تحمل
/// عنوانها في الشريط العلوي وزرّ رجوع واضح.
///
/// ## البنية
///   • [SettingsPageShell] — الهيكل الموحّد (RTL · شريط رجوع · خلفية · قائمة).
///   • [SettingsGroupsPage] — صفحة عامة تعرض مجموعات خيارات مختارة (+ بطاقات
///     خاصة قبلها). كل الصفحات تقريبًا تُبنى منها.
///   • الصفحات المسمّاة في الأسفل: النشاط · المظهر · الفواتير · الطباعة ·
///     الذمم · العمليات · الضريبة · الاحتفاظ · الترخيص · النسخ · حول النظام.
///
/// **الخصومات** لا صفحة لها هنا: مدخلها في الفهرس ينقل مباشرةً إلى الشاشة
/// القائمة `AppRoute.discounts` — فلا نكرّر شاشة قائمة.
///
/// ## القاعدة الحاكمة
/// لا كتابة في القاعدة من هذا الملف: القراءة من [SettingsController] والكتابة
/// عبر `updateSetting` وحده (الودجات المشتركة في `settings_sections.dart`).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/settings/settings_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/view/screen/settings/print_font_picker.dart';
import 'package:laundry/view/screen/settings/settings_sections.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// الهيكل الموحّد لصفحة إعدادات فرعية.
///
/// يُوحّد: اتجاه RTL (التطبيق يعمل بلغة إنجليزية افتراضية في `MaterialApp`،
/// فالاتجاه يُضبط صراحةً كما في بقية الشاشات) · الشريط العلوي بزرّ الرجوع ·
/// الخلفية المتدرّجة · القائمة القابلة للتمرير.
class SettingsPageShell extends StatelessWidget {
  const SettingsPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        appBar: CustomAppbar(title: title, subtitle: subtitle),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFC), AppColors.background],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// صفحة إعدادات عامة: **بطاقات خاصة** (اختيارية) ثم **مجموعات خيارات** مختارة.
///
/// [leading] دالة لا قائمة: بطاقات مثل قائمة الطابعات وبطاقة الترخيص تحتاج
/// المتحكّم و`BuildContext`، فلا تُبنى إلا داخل `build`.
class SettingsGroupsPage extends StatelessWidget {
  const SettingsGroupsPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.groups = const <String>[],
    this.leading,
  });

  final String title;
  final String subtitle;

  /// مفاتيح مجموعات الخيارات المعروضة، بترتيب ظهورها في الصفحة.
  final List<String> groups;

  /// بطاقات تُعرض **قبل** مجموعات الخيارات.
  final List<Widget> Function(SettingsController controller, BuildContext ctx)?
  leading;

  @override
  Widget build(BuildContext context) {
    // `Get.put` لا يستبدل نسخة مسجَّلة (GetX يترك الموجود)، فالمتحكّم واحد
    // عبر الفهرس وكل الصفحات، وكاشه (`settings`) يبقى مشتركًا.
    final controller = Get.put(SettingsController());
    if (controller.settings.isEmpty) controller.loadSettings();

    // ⚠️ الصفحة كلها داخل `Obx` لأن الإعدادات تُقرأ **غير متزامنة**: بطاقات
    // مثل «معلومات النشاط» تُبنى من `controller.settings`، فبلا هذا اللفّ
    // تُبنى فارغة عند أول دخول ولا تُحدَّث عند وصول البيانات.
    // وقراءة `isLoading.value` أولًا ضرورية: `settings.isEmpty` على `RxMap`
    // لا تُبلِّغ عن قراءة، فهي وحدها لا تُسجّل التبعية.
    return Obx(() {
      if (controller.isLoading.value && controller.settings.isEmpty) {
        return SettingsPageShell(
          title: title,
          subtitle: subtitle,
          children: const [
            SizedBox(height: 60),
            Center(child: CircularProgressIndicator()),
          ],
        );
      }

      final head = leading?.call(controller, context) ?? const <Widget>[];

      return SettingsPageShell(
        title: title,
        subtitle: subtitle,
        children: [
          for (var i = 0; i < head.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            FadeInUp(delayMs: i * 60, child: head[i]),
          ],
          if (head.isNotEmpty) const SizedBox(height: 14),
          if (groups.isNotEmpty) ...[
            FadeInUp(delayMs: 120, child: optionsSearchField(controller)),
            const SizedBox(height: 14),
            optionsSection(controller, groups),
          ],
          const SizedBox(height: 20),
          const FadeInUp(
            delayMs: 200,
            child: DeveloperCredit(
              fontSize: 12,
              padding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          const SizedBox(height: 10),
        ],
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// النشاط والواجهة
// ═══════════════════════════════════════════════════════════════════════════

/// **معلومات النشاط التجاري** — ما يُطبع على الفاتورة وتقارير الهيئة.
class SettingsBusinessPage extends StatelessWidget {
  const SettingsBusinessPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('معلومات النشاط التجاري'),
    subtitle: tr('الاسم · الهاتف · العنوان · الرقم الضريبي · السجل التجاري'),
    leading: (c, ctx) => [businessInfoCard(c)],
  );
}

/// **المظهر** — حجم الخط في كل الشاشات.
class SettingsAppearancePage extends StatelessWidget {
  const SettingsAppearancePage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('المظهر'),
    subtitle: tr('حجم الخط والواجهة'),
    leading: (c, ctx) => [appearanceCard(c)],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// الفواتير والطباعة
// ═══════════════════════════════════════════════════════════════════════════

/// **الفواتير والترقيم** — المعاينة الحيّة + الترقيم + ما يظهر على الفاتورة.
///
/// المعاينة في الأعلى مقصودة: المستخدم يرى أثر كل خيار إظهار فورًا تحته.
class SettingsInvoicePage extends StatelessWidget {
  const SettingsInvoicePage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('الفواتير والترقيم'),
    subtitle: tr('معاينة الفاتورة · الترقيم · ما يظهر عليها'),
    groups: const <String>[
      SettingGroups.invoicing,
      SettingGroups.invoiceDisplay,
    ],
    leading:
        (c, ctx) => [
          invoicePreviewCard(c),
          // لغة الورق قرار مستقلّ عن لغة الشاشة — بطاقة صريحة لا سطر منسدل.
          docLanguageCard(c),
          // مقاسات الشعار ورمز QR مع حساب المساحة والتقييد — قيم تُرى لا تُكتب.
          printSizesCard(c),
        ],
  );
}

/// **الطباعة وإخراج الفاتورة** — الطابعة الافتراضية + خطّ الطباعة + مفتاحا
/// الطباعة/PDF ومجلد الحفظ (كلها في بطاقة واحدة) + مقاسات الطباعة.
class SettingsPrintingPage extends StatelessWidget {
  const SettingsPrintingPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('الطباعة وإخراج الفاتورة'),
    subtitle: tr(
      'لغة الطباعة · مقاسات الشعار ورمز QR · الطابعة الافتراضية · خطّ الطباعة · حفظ PDF',
    ),
    groups: const <String>[SettingGroups.printing],
    leading:
        (c, ctx) => [
          // اللغة أولًا: قرار يغيّر شكل كل ورق يخرج من الطابعة تحته.
          docLanguageCard(c),
          // مقاس الورق هو الذي يُقاس عليه الشعار والرمز — فالبطاقة بعده.
          printSizesCard(c),
          PrinterSection(controller: c),
          PrintFontCard(controller: c),
        ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// الحسابات والتشغيل
// ═══════════════════════════════════════════════════════════════════════════

/// **الذمم والاشتراكات** — سياسات الدين والائتمان والتغطية والولاء والزبائن.
class SettingsAccountsPage extends StatelessWidget {
  const SettingsAccountsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('الذمم والاشتراكات'),
    subtitle: tr('الذمم والائتمان · الاشتراكات · الزبائن · نقاط الولاء'),
    groups: const <String>[
      SettingGroups.receivables,
      SettingGroups.subscriptions,
      SettingGroups.customers,
      SettingGroups.loyalty,
    ],
  );
}

/// **العمليات والمصنعية** — تتبّع الغسيل وأجور العمال وسلوك نقطة البيع.
class SettingsOperationsPage extends StatelessWidget {
  const SettingsOperationsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('العمليات والمصنعية'),
    subtitle: tr('تتبّع الغسيل · مصنعية العمال · نقطة البيع'),
    groups: const <String>[
      SettingGroups.processing,
      SettingGroups.labor,
      SettingGroups.pos,
    ],
  );
}

/// **الضريبة** — ضريبة المخرجات (المبيعات) وضريبة المدخلات (المصروفات).
class SettingsTaxPage extends StatelessWidget {
  const SettingsTaxPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('الضريبة'),
    subtitle: tr('ضريبة القيمة المضافة · ضريبة المدخلات'),
    groups: const <String>[SettingGroups.tax, SettingGroups.expensesVat],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// النظام والصيانة
// ═══════════════════════════════════════════════════════════════════════════

/// **الاحتفاظ بالبيانات** — مدة الاحتفاظ والحذف التلقائي للفواتير القديمة.
///
/// ⚠️ الحذف التلقائي لا يمسّ فواتير السنة الجارية أبدًا (قاعدة حاكمة في
/// `SqlDB`) — والمدة الدنيا محميّة كذلك.
class SettingsRetentionPage extends StatelessWidget {
  const SettingsRetentionPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('الاحتفاظ بالبيانات'),
    subtitle: tr('مدة الاحتفاظ بالفواتير والحذف التلقائي'),
    groups: const <String>[SettingGroups.retention],
  );
}

/// **ترخيص النظام** — الحالة وتاريخ الانتهاء + خيارات فحص الترخيص.
/// (مدير النظام فقط — الحجب في فهرس الإعدادات.)
class SettingsLicensePage extends StatelessWidget {
  const SettingsLicensePage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('ترخيص النظام'),
    subtitle: tr('حالة الاشتراك · تاريخ الانتهاء · فحص الصلاحية'),
    groups: const <String>[SettingGroups.license],
    leading: (c, ctx) => [licenseCard(ctx)],
  );
}

/// **النسخ الاحتياطي** — إنشاء نسخة مباشرة + إدارة النسخ والاستعادة.
/// (مدير النظام فقط — الحجب في فهرس الإعدادات.)
class SettingsBackupPage extends StatelessWidget {
  const SettingsBackupPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('النسخ الاحتياطي'),
    subtitle: tr('إنشاء نسخة · قائمة النسخ · الاستعادة'),
    leading: (c, ctx) => [backupCard(c)],
  );
}

/// **حول النظام** — الشعار والإصدار وحقوق المطوّر.
class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroupsPage(
    title: tr('حول النظام'),
    subtitle: tr('الإصدار ومعلومات المطوّر'),
    leading: (c, ctx) => [aboutCard()],
  );
}
