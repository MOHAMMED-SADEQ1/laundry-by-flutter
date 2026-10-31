/// **أقسام الإعدادات** — الودجات المشتركة التي تُبنى منها صفحات الإعدادات.
///
/// ## لماذا ملف مستقلّ؟
/// كانت كل الأقسام دوالًّ خاصة داخل [SettingsScreen]، وكانت الصفحة تُعرض
/// كقائمة طويلة واحدة. وبعد تقسيم الإعدادات إلى **فهرس + صفحة لكل قسم**
/// (`settings_screen.dart` للفهرس، `settings_pages.dart` للصفحات الفرعية)
/// احتاج أكثر من ملف إلى نفس الأقسام — فنُقلت هنا مرّة واحدة.
///
/// ## القاعدة
/// هذا الملف **واجهة فقط**: لا يكتب في القاعدة ولا يعدّل `settings` إلا عبر
/// [SettingsController.updateSetting] (المسار الواحد: تطبيع + upsert + كاش +
/// سجل تدقيق). والمنطق الخالص (التطبيع والحدود والقيم الافتراضية) يبقى في
/// `lib/services/settings/setting_option.dart` بلا Flutter.
///
/// ## الأقسام
///   • [SettingTile] — صفّ إدخال في الفهرس (أيقونة · عنوان · وصف · سهم).
///   • [groupMeta] — وصف عرض كل مجموعة خيارات (عنوان · أيقونة · لون · ملاحظة).
///   • [optionsSearchField] + [optionsSection] — محرّك عرض مجموعات الخيارات.
///   • بطاقات الأقسام: النشاط · المظهر · النسخ الاحتياطي · الخصومات · حول النظام ·
///     معاينة الفاتورة · الترخيص.
///   • [PrinterSection] + [InvoiceOutputBlock] — الطابعة وإخراج الفاتورة.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/config/run_target.dart';
import 'package:laundry/controller/settings/locale_controller.dart';
import 'package:laundry/controller/settings/settings_controller.dart';
import 'package:laundry/controller/settings/theme_controller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/database/backup_naming.dart';
import 'package:laundry/services/invoice/invoice_output_service.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/map_qr.dart';
import 'package:laundry/services/pdf/print_visual_size.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/printer/printer_service.dart';
import 'package:laundry/services/i18n/app_language.dart';
import 'package:laundry/services/i18n/doc_language.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/translations_en.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/common/map_link_status.dart';
import 'package:printing/printing.dart';
import 'package:laundry/services/permission/permission_catalog.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. صفّ إدخال في فهرس الإعدادات
// ═══════════════════════════════════════════════════════════════════════════

/// صفّ إدخال داخل بطاقة: أيقونة ملوّنة · عنوان · وصف · سهم يشير إلى صفحة.
///
/// يُستعمل في **فهرس الإعدادات** (`settings_screen.dart`) لكل مدخل ينقل إلى
/// صفحة فرعية، ويُستعمل داخل البطاقات للانتقال إلى شاشة قائمة مستقلّة
/// (النسخ الاحتياطي · سجل الترخيص · أكواد الخصم).
class SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const SettingTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(Icons.chevron_left, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. وصف عرض مجموعات الخيارات
// ═══════════════════════════════════════════════════════════════════════════

/// وصف عرض المجموعة: العنوان · الأيقونة · اللون · ملاحظة أسفل البطاقة.
///
/// الأيقونات والألوان خاصة بالواجهة، فلا تُوضع في ملف المنطق الخالص
/// (`lib/services/settings/setting_option.dart`) — الربط بالمفتاح هنا.
class GroupMeta {
  final String title;
  final IconData icon;
  final Color color;
  final String? note;

  const GroupMeta(this.title, this.icon, this.color, [this.note]);
}

/// مجموعات خيارات النظام كما تُعرض (بالترتيب في `SettingGroups.ordered`).
///
/// **ملاحظة:** لا مدخل لـ`SettingGroups.invoiceOutput` — خياراتها تُبنى داخل
/// [InvoiceOutputBlock] في صفحة الطباعة، لا كبطاقة خيارات.
const Map<String, GroupMeta> groupMeta = <String, GroupMeta>{
  SettingGroups.invoicing: GroupMeta(
    'الفوترة والترقيم',
    Icons.receipt_long_outlined,
    AppColors.primary,
    'الترقيم لا يتراجع: لا يقلّ رقم الفاتورة الجديدة عن أعلى رقم مسجَّل.',
  ),
  SettingGroups.invoiceDisplay: GroupMeta(
    'ما يظهر على الفاتورة',
    Icons.visibility_outlined,
    AppColors.secondary,
    'اختصارات سريعة لإظهار/إخفاء حقول الفاتورة. للتحكّم الكامل — نصّ كل عنصر وتفعيله وتصميم كشف الحساب أيضًا — استخدم «قوالب الطباعة». ⚠️ بعد أول تعديل من هناك يصبح القالب هو المرجع، وهذه المفاتيح تزامنه ولا تُلغيه.',
  ),
  SettingGroups.printing: GroupMeta(
    'الطباعة بكل المقاسات',
    Icons.print_outlined,
    AppColors.slate,
    'A4 · A5 · A6 · حراري 80/58 مم · ملصقات. التفعيل لا يغيّر سلوك أي تثبيت قائم حتى تختار المقاس.',
  ),
  SettingGroups.tax: GroupMeta(
    'الضريبة',
    Icons.percent,
    AppColors.indigo,
    'النسبة تُخزَّن وتُضبط من هنا، ولم تُضَف بعد إلى حساب الفاتورة.',
  ),
  SettingGroups.expensesVat: GroupMeta(
    'ضريبة المدخلات (المصروفات)',
    Icons.receipt_rounded,
    AppColors.warning,
    'ضريبة المشتريات القابلة للخصم — تدخل في تقرير الإقرار الضريبي.',
  ),
  SettingGroups.receivables: GroupMeta(
    'الذمم والائتمان',
    Icons.account_balance_wallet_outlined,
    AppColors.info,
    'هذه القيم كانت تُقرأ مباشرةً؛ صارت هنا مصدرًا واحدًا يظهر ويُدقَّق.',
  ),
  SettingGroups.subscriptions: GroupMeta(
    'الاشتراكات',
    Icons.card_membership_outlined,
    AppColors.violet,
    'تحكم سلوك التغطية والسقوف والدفعات.',
  ),
  SettingGroups.processing: GroupMeta(
    'المصنعية',
    Icons.local_laundry_service_outlined,
    AppColors.info,
    'تتبّع الغسيل من الاستلام للتسليم: المخطط · العامل · المهلة · الملصقات.',
  ),
  SettingGroups.labor: GroupMeta(
    'مصنعية العمال',
    Icons.engineering_outlined,
    AppColors.success,
    'أجر القطعة وحوافز الإنتاج وتقرير الإنتاجية.',
  ),
  SettingGroups.pos: GroupMeta(
    'نقطة البيع',
    Icons.point_of_sale_outlined,
    AppColors.primary,
    'سلوك شاشة الكاشير: الطباعة التلقائية · التأكيد · طريقة الدفع الافتراضية.',
  ),
  SettingGroups.customers: GroupMeta(
    'الزبائن',
    Icons.people_outline,
    AppColors.secondary,
    'سياسات تسجيل الزبون الافتراضية.',
  ),
  SettingGroups.loyalty: GroupMeta(
    'نقاط الولاء',
    Icons.stars_outlined,
    AppColors.violet,
    'التعطيل يوقف احتساب النقاط وترقيات الشرائح تمامًا عند إصدار الفواتير.',
  ),
  SettingGroups.retention: GroupMeta(
    'الاحتفاظ بالبيانات',
    Icons.auto_delete_outlined,
    AppColors.warning,
    'تنبيه: التقارير السنوية تعتمد على الفواتير المحفوظة. لا تُقلّل المدة ولا تُفعّل الحذف دون أخذ نسخة احتياطية.',
  ),
  SettingGroups.license: GroupMeta(
    'خيارات الترخيص',
    Icons.verified_user_outlined,
    AppColors.violet,
    'القيم تسري فورًا على فحص صلاحية النظام أثناء العمل.',
  ),
};

// ═══════════════════════════════════════════════════════════════════════════
// 3. محرّك عرض مجموعات الخيارات
// ═══════════════════════════════════════════════════════════════════════════

/// حقل البحث في خيارات **الصفحة الحالية** — تصفية فورية بلا حفظ.
///
/// يوضع في أعلى كل صفحة تعرض مجموعات خيارات (لا في الفهرس: الفهرس صار
/// صغيرًا وواضحًا فلا يحتاج بحثًا).
///
/// ⚠️ `suffixIcon` ملفوف بـ`Obx` وحده: زرّ المسح يظهر ويختفي مع الكتابة،
/// ولو لففنا الـ`TextField` نفسه لأُعيد بناؤه مع كل حرف.
Widget optionsSearchField(SettingsController controller) {
  return SoftCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: TextField(
      onChanged: (v) => controller.optionSearch.value = v.trim(),
      decoration: InputDecoration(
        border: InputBorder.none,
        icon: const Icon(Icons.search, color: AppColors.primary),
        hintText: tr('ابحث في خيارات هذه الصفحة...'),
        suffixIcon: Obx(
          () => controller.optionSearch.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.optionSearch.value = '';
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
        ),
      ),
    ),
  );
}

/// بطاقات **خيارات النظام** لمجموعات محدَّدة، مبنية من السجل الواحد
/// [SettingOptions.all].
///
/// كل قيمة كانت ثابتًا في `config/constants.dart` (ترقيم الفواتير · الاحتفاظ
/// بالبيانات · الولاء · الضريبة · الترخيص · العملة) صارت خيارًا: مفتاح
/// تفعيل/تعطيل + حقل لتحديد القيمة. وإضافة خيار جديد إلى السجل تُظهره في
/// صفحته تلقائيًا بلا أي تعديل في الواجهة.
///
/// [groups] مفاتيح المجموعات المعروضة في الصفحة — رتّبها كما تريد ظهورها
/// (وهو الترتيب المنطقي للصفحة، لا ترتيب `SettingGroups.ordered`).
Widget optionsSection(SettingsController controller, List<String> groups) {
  return Obx(() {
    final query = controller.optionSearch.value.trim().toLowerCase();
    final widgets = <Widget>[];
    var delayMs = 0;
    for (final group in groups) {
      final meta = groupMeta[group];
      var options = SettingOptions.ofGroup(group);
      // خطّ الطباعة له بطاقة معاينة خاصّة (`PrintFontCard`) تُظهر الخطّ نفسه —
      // لا يُعرض هنا كقائمة منسدلة، وإلا ظهر الإعداد مرّتين.
      //
      // و«لغة الطباعة» كذلك: لها بطاقة صريحة ([docLanguageCard]) في صفحتي
      // «الفواتير» و«الطباعة» — فإبقاء سطرها المنسدل هنا يعني **تحكّمين
      // لنفس المفتاح** في الصفحة الواحدة، وهو لبس لا ميزة.
      // ومقاسات الشعار ورمز QR: بطاقة [printSizesCard] تحملها مع الحساب
      // والتحذير — فسطرها هنا يعني تحكّمين لنفس المفتاح بقيمتين مختلفتين.
      options = options
          .where(
            (o) =>
                o.key != AppConstants.settingPrintFont &&
                o.key != AppConstants.settingDocLanguage &&
                o.key != AppConstants.settingInvoiceLogoWidth &&
                o.key != AppConstants.settingInvoiceLogoHeight &&
                o.key != AppConstants.settingMapQrSize,
          )
          .toList(growable: false);
      if (meta == null || options.isEmpty) continue;
      // خيارات الترخيص لمدير النظام وحده — كبطاقة «ترخيص النظام» في الصفحة.
      final adminOnly =
          group == SettingGroups.license &&
          !PermissionService.can(PermissionKeys.settingsManage);
      if (adminOnly) continue;
      // تصفية البحث: بالعنوان أو الوصف أو المفتاح.
      if (query.isNotEmpty) {
        options = options
            .where(
              (o) =>
                  tr(o.label).toLowerCase().contains(query) ||
                  tr(o.description).toLowerCase().contains(query) ||
                  o.key.toLowerCase().contains(query),
            )
            .toList(growable: false);
        if (options.isEmpty) continue;
      }
      widgets
        ..add(
          FadeInUp(
            delayMs: delayMs,
            child: _optionsCard(controller, meta, options),
          ),
        )
        ..add(const SizedBox(height: 14));
      delayMs += 40;
    }
    if (widgets.isEmpty) {
      // البحث قد يطابق خيارات «إخراج الفاتورة» وحدها — وهي لا تُبنى هنا،
      // فنوجّه المستخدم إلى موضعها بدل رسالة «لا يوجد خيار مطابق» المضلِّلة.
      if (query.isNotEmpty && _matchesInvoiceOutput(query)) {
        return const SoftCard(
          padding: EdgeInsets.all(16),
          child: Text(
            'خيارات إخراج الفاتورة (طباعة / PDF) في صفحة «الطباعة وإخراج الفاتورة» — بطاقة «الطابعة الافتراضية».',
            style: TextStyle(fontFamily: 'cairo', fontSize: 13),
            textAlign: TextAlign.center,
          ),
        );
      }
      if (query.isEmpty) return const SizedBox.shrink();
      return SoftCard(
        padding: EdgeInsets.all(16),
        child: Text(
          tr('لا يوجد خيار مطابق للبحث.'),
          style: TextStyle(fontFamily: 'cairo', fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(children: widgets);
  });
}

/// هل يطابق نصّ البحث أيًّا من خيارات مجموعة «إخراج الفاتورة»؟
///
/// تُستعمل فقط في رسالة «لا نتائج» — فالخيارات نفسها تُبنى في بطاقة الطابعة
/// لا هنا، فلا بدّ من توجيه المستخدم إليها.
bool _matchesInvoiceOutput(String query) {
  return SettingOptions.ofGroup(SettingGroups.invoiceOutput).any(
    (o) =>
        tr(o.label).toLowerCase().contains(query) ||
        tr(o.description).toLowerCase().contains(query) ||
        o.key.toLowerCase().contains(query),
  );
}

Widget _optionsCard(
  SettingsController controller,
  GroupMeta meta,
  List<SettingOption> options,
) {
  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr(meta.title),
          icon: meta.icon,
          color: meta.color,
        ),
        const SizedBox(height: 6),
        Obx(() {
          final rows = <Widget>[];
          for (final option in options) {
            // الخيار التابع لا يظهر إلا عند تفعيل مفتاحه — فلا يُضبط خيار
            // مُعطَّل يوهم المستخدم بأنه نافذ.
            final parent = option.enabledBy;
            if (parent != null && !_isOn(controller, parent)) continue;
            if (rows.isNotEmpty) rows.add(const Divider(height: 18));
            rows.add(_optionRow(controller, option));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          );
        }),
        if (meta.note != null) ...[
          const SizedBox(height: 8),
          Text(
            tr(meta.note!),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: meta.color,
            ),
          ),
        ],
      ],
    ),
  );
}

/// صفّ خيار واحد: مفتاح لمنطقي، وحقل قيمة لما عداه.
Widget _optionRow(SettingsController controller, SettingOption option) {
  if (option.isBoolean) {
    final on = _isOn(controller, option.key);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: on,
      activeThumbColor: AppColors.primary,
      title: Text(
        tr(option.label),
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${tr(option.description)}\n${on ? tr('مُفعَّل') : tr('معطَّل')}',
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
      onChanged: (val) => controller.updateSetting(option.key, val ? '1' : '0'),
    );
  }

  if (option.isChoice) {
    final value = _valueOf(controller, option);
    final choices = option.choices ?? const <String>[];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(option.label),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(option.description),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 132,
          child: DropdownButtonFormField<String>(
            key: ValueKey('${option.key}:$value'),
            initialValue: choices.contains(value) ? value : null,
            isExpanded: true,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
            ),
            items: choices
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c,
                    child: Text(
                      tr(option.labelOfChoice(c)),
                      style: const TextStyle(fontFamily: 'cairo'),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) =>
                val == null ? null : controller.updateSetting(option.key, val),
          ),
        ),
      ],
    );
  }

  final value = _valueOf(controller, option);
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(option.label),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tr(option.description),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: option.kind == SettingKind.text ? 110 : 86,
        child: TextFormField(
          // المفتاح مربوط بالقيمة: تغييرها من أي موضع يعيد بناء الحقل بها،
          // وإلا بقي `initialValue` القديم معروضًا.
          key: ValueKey('${option.key}:$value'),
          initialValue: value,
          keyboardType: _keyboardFor(option),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          // الحفظ عند تأكيد الحقل فقط — لا مع كل حرف، فلا تُخزَّن قيم ناقصة
          // أثناء الكتابة (مثل "1" من "15").
          onFieldSubmitted: (val) => controller.updateSetting(option.key, val),
        ),
      ),
    ],
  );
}

TextInputType _keyboardFor(SettingOption option) {
  switch (option.kind) {
    case SettingKind.integer:
      return TextInputType.number;
    case SettingKind.decimal:
      return const TextInputType.numberWithOptions(decimal: true);
    case SettingKind.text:
    case SettingKind.boolean:
    case SettingKind.choice:
      return TextInputType.text;
  }
}

/// هل الخيار مُفعَّل حسب القيمة المعروضة (أو الافتراضية عند غياب المفتاح)؟
bool _isOn(SettingsController controller, String key) {
  final option = SettingOptions.byKey(key);
  final raw = controller.settings[key] ?? option?.defaultValue ?? '0';
  return isTruthy(raw);
}

/// هل الخيار مُفعَّل فعلًا (نفسه وكل أسلافه)؟
bool _effOn(SettingsController controller, String key) {
  final option = SettingOptions.byKey(key);
  if (option == null) return _isOn(controller, key);
  return isEffectivelyOn(option, (k) => controller.settings[k]);
}

/// القيمة المطبَّعة المعروضة في الحقل (بحسب نوع الخيار وحدوده).
String _valueOf(SettingsController controller, SettingOption option) =>
    normalizeValue(option, controller.settings[option.key]);

// ═══════════════════════════════════════════════════════════════════════════
// 4. بطاقات الأقسام
// ═══════════════════════════════════════════════════════════════════════════

/// **معلومات النشاط التجاري** — تُطبع على الفاتورة وعلى تقارير الهيئة.
Widget businessInfoCard(SettingsController controller) {
  final nameCtrl = TextEditingController(
    text: controller.settings['business_name'] ?? '',
  );
  final phoneCtrl = TextEditingController(
    text: controller.settings['business_phone'] ?? '',
  );
  final addressCtrl = TextEditingController(
    text: controller.settings['business_address'] ?? '',
  );
  final locationCtrl = TextEditingController(
    text: controller.settings['business_location'] ?? '',
  );
  final taxNumberCtrl = TextEditingController(
    text: controller.settings['business_tax_number'] ?? '',
  );
  final crCtrl = TextEditingController(
    text: controller.settings['business_cr_number'] ?? '',
  );
  final shortAddressCtrl = TextEditingController(
    text: controller.settings['business_short_address'] ?? '',
  );

  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('معلومات النشاط التجاري'),
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: tr('اسم النشاط'),
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: tr('رقم الهاتف'),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: addressCtrl,
          decoration: InputDecoration(
            labelText: tr('العنوان'),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: locationCtrl,
          decoration: InputDecoration(
            labelText: tr('رابط الموقع (Google Maps)'),
            hintText: tr('اختياري — يُطبع كرمز QR أسفل الفاتورة'),
            prefixIcon: Icon(Icons.map_outlined),
          ),
        ),
        // حكم حيّ: هل سيُطبع رمز QR فعلًا؟ بلا هذا السطر يبقى الرابط الفاسد
        // صامتًا فلا يعرف صاحب النشاط سبب اختفاء الرمز من ورقته.
        MapLinkStatus(controller: locationCtrl),
        const SizedBox(height: 10),
        TextField(
          controller: taxNumberCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('الرقم الضريبي (VAT)'),
            hintText: tr('اختياري — 15 رقمًا، يظهر على الفاتورة وQR الهيئة'),
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: crCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('السجل التجاري'),
            hintText: tr('اختياري — يظهر على الفاتورة عند تفعيل خياره'),
            prefixIcon: Icon(Icons.business_center_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: shortAddressCtrl,
          decoration: InputDecoration(
            labelText: tr('العنوان الوطني المختصر'),
            hintText: tr('اختياري — يظهر على الفاتورة عند تفعيل خياره'),
            prefixIcon: Icon(Icons.pin_drop_outlined),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await controller.updateSetting('business_name', nameCtrl.text);
              await controller.updateSetting(
                'business_phone',
                phoneCtrl.text,
              );
              await controller.updateSetting(
                'business_address',
                addressCtrl.text,
              );
              await controller.updateSetting(
                'business_location',
                locationCtrl.text,
              );
              await controller.updateSetting(
                'business_tax_number',
                taxNumberCtrl.text,
              );
              await controller.updateSetting(
                'business_cr_number',
                crCtrl.text,
              );
              await controller.updateSetting(
                'business_short_address',
                shortAddressCtrl.text,
              );
              // تحديث الخدمة المركزية
              await BusinessInfoService.instance.load();
              // الرابط غير الصالح لا يُطبع رمزًا له بلا كلمة — كان سيُحفظ
              // ويبقى صامتًا فلا يعرف صاحب النشاط أن رمزه لن يظهر أصلًا.
              final verdict = MapLinkVerdict.of(locationCtrl.text);
              if (verdict.state == MapLinkState.invalid) {
                Get.snackbar(
                  tr('تنبيه'),
                  verdict.canRepair
                      ? trf(
                        'رابط الموقع بلا نطاق — لن يُطبع رمز QR. اضغط زرّ الإصلاح تحت الحقل، أو استخدم: {0}',
                        [verdict.suggestion],
                      )
                      : verdict.message,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 8),
                );
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: Text(
              tr('حفظ المعلومات'),
              style: TextStyle(fontFamily: 'cairo'),
            ),
          ),
        ),
      ],
    ),
  );
}

/// **المظهر** — حجم الخط وحده حاليًا (يُحفظ في `ThemeController`).
Widget appearanceCard(SettingsController controller) {
  final theme = ThemeController.instance;

  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: tr('المظهر'), icon: Icons.brush_outlined),
        const SizedBox(height: 10),
        // 🌐 اللغة أولًا: قرار يغيّر كل نصّ في البطاقة تحته.
        const _LanguageRow(),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Obx(() {
          final fontSize = theme.fontScale.value * ThemeController.baseFontSize;
          return Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.text_fields, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Text(
                    tr('حجم الخط'),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      fontSize.toStringAsFixed(0),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: fontSize,
                min: 10,
                max: 24,
                divisions: 14,
                label: fontSize.toStringAsFixed(0),
                activeColor: AppColors.secondary,
                onChanged: (val) {
                  theme.setFontSize(val);
                },
              ),
            ],
          );
        }),
      ],
    ),
  );
}

/// **النسخ الاحتياطي** — إنشاء نسخة مباشرة + الدخول إلى إدارة النسخ.
///
/// الإدارة الكاملة (التسمية والاستعادة والقائمة) في شاشة `/backup`؛ والإنشاء
/// هنا اختصار للعملية الأكثر تكرارًا بلا مغادرة الصفحة.
Widget backupCard(SettingsController controller) {
  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('النسخ الاحتياطي'),
          icon: Icons.backup_outlined,
        ),
        const SizedBox(height: 10),
        SettingTile(
          icon: Icons.backup,
          iconColor: AppColors.success,
          title: tr('إنشاء نسخة احتياطية'),
          subtitle: tr('نسخة SQLite خام (‎.db‎) باسم ومكان تختارهما'),
          onTap: () async {
            final result = await controller.exportData();
            if (result.success) {
              final where = result.cancelled
                  ? tr('حُفظت داخل التطبيق فقط')
                  : trf('حُفظت في: {0}', ['${result.savedPath}']);
              Get.snackbar(
                tr('تم إنشاء النسخة'),
                '$where\n${BackupNaming.formatSize(result.sizeBytes)}',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.success,
                colorText: Colors.white,
                duration: const Duration(seconds: 5),
              );
            } else {
              Get.snackbar(
                tr('فشل في إنشاء النسخة'),
                result.error ?? tr('سبب غير معروف'),
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.danger,
                colorText: Colors.white,
              );
            }
          },
        ),
        const Divider(height: 20),
        SettingTile(
          icon: Icons.restore,
          iconColor: AppColors.warning,
          title: tr('إدارة النسخ والاستعادة'),
          subtitle: tr('قائمة النسخ المحفوظة · استعادة من أي ملف على الجهاز'),
          onTap: () => Get.toNamed(AppRoute.backup),
        ),
      ],
    ),
  );
}

/// **الخصومات** — مدخل شاشة إدارة أكواد الخصم.
Widget discountsCard() {
  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('الخصومات'),
          icon: Icons.local_offer_outlined,
        ),
        const SizedBox(height: 10),
        SettingTile(
          icon: Icons.confirmation_number_outlined,
          iconColor: AppColors.success,
          title: tr('إدارة أكواد الخصم'),
          subtitle: tr('نسبة أو مبلغ ثابت · تاريخ سريان · حدّ استخدام'),
          onTap: () => Get.toNamed(AppRoute.discounts),
        ),
      ],
    ),
  );
}

/// **حول النظام** — الشعار والإصدار وحقوق المطوّر.
Widget aboutCard() {
  return SoftCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppColors.softShadow(blur: 14, y: 5),
          ),
          child: const Icon(
            Icons.local_laundry_service,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          BusinessInfoService.instance.name.isNotEmpty
              ? BusinessInfoService.instance.name
              : tr('نظام إدارة المغاسل'),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          trf('الإصدار {0}', [AppInfo.version]),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('نظام إدارة المغاسل الشامل — تصميم عصري وتجربة سلسة'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // حقوق المطوّر داخل بطاقة «حول النظام»
        const DeveloperCredit(fontSize: 12),
      ],
    ),
  );
}

/// **معاينة حيّة لشكل الفاتورة** وفق خيارات الإظهار الحالية.
///
/// ليست الحساب الفعلي (ذاك في ترقيم الفاتورة)، بل عرض تمثيلي يبيّن للمستخدم
/// أثر كل خيار قبل الطباعة.
Widget invoicePreviewCard(SettingsController controller) {
  final biz = BusinessInfoService.instance;
  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('معاينة الفاتورة'),
          icon: Icons.receipt_outlined,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Obx(() {
            // 🚨 المعاينة تُعرض **بلغة الطباعة** لا بلغة الواجهة: البطاقة
            // تسمى «معاينة الفاتورة»، فلو أظهرت العربية في واجهة إنجليزية
            // (أو العكس) لَظنّ المستخدم أن إعداد اللغة لا يعمل. والنصّ يمرّ
            // من نفس قاموس المستندات (`kEnglish`) الذي يمرّ منه الـPDF.
            final docLang = DocLanguage.byCode(
              controller.settings[AppConstants.settingDocLanguage] ??
                  SettingOptions.docLanguage.defaultValue,
            );
            String doc(String arabic) =>
                docLang.isEnglish ? (kEnglish[arabic] ?? arabic) : arabic;
            String docf(String arabic, List<String> args) {
              var out = doc(arabic);
              for (var i = 0; i < args.length; i++) {
                out = out.replaceAll('{$i}', args[i]);
              }
              return out;
            }

            final lines = <Widget>[];
            void add(String text, {bool bold = false, double size = 12}) {
              lines.add(
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: size,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }

            if (_effOn(controller, AppConstants.settingInvoiceShowLogo)) {
              lines.add(
                const Icon(
                  Icons.storefront,
                  size: 26,
                  color: AppColors.primary,
                ),
              );
            }
            add(
              biz.name.isEmpty ? doc('اسم النشاط') : biz.name,
              bold: true,
              size: 13,
            );
            if (_effOn(
              controller,
              AppConstants.settingInvoiceShowShortAddress,
            )) {
              add(doc('العنوان الوطني: 1234 الرياض'), size: 11);
            }
            add(
              controller.settings[AppConstants.settingInvoiceTitleText] ??
                  AppConstants.invoiceTitleTextDefault,
              bold: true,
            );
            if (_effOn(controller, AppConstants.settingInvoiceShowTaxNumber)) {
              final tn = biz.taxNumber.isEmpty
                  ? '300000000000003'
                  : biz.taxNumber;
              add(docf('الرقم الضريبي: {0}', [tn]), size: 11);
            }
            if (_effOn(controller, AppConstants.settingInvoiceShowCrNumber)) {
              add(doc('السجل التجاري: 1010000000'), size: 11);
            }
            if (_effOn(controller, AppConstants.settingInvoiceShowDatetime)) {
              add(doc('التاريخ: 2026-10-06 10:30 ص'), size: 11);
            }
            if (_effOn(controller, AppConstants.settingInvoiceShowCashier)) {
              add(doc('صدر بواسطة: مدير النظام'), size: 11);
            }
            if (_effOn(controller, AppConstants.settingInvoiceShowPickupCode)) {
              add(doc('رمز الاستلام: 1234'), size: 11);
            }
            add(doc('— قميص ×1 = 10.00 —'), size: 11);
            if (_effOn(
              controller,
              AppConstants.settingInvoiceShowDiscountLine,
            )) {
              add(doc('الخصم: 2.00'), size: 11);
            }
            if (_effOn(controller, AppConstants.settingTaxEnabled) &&
                _effOn(controller, AppConstants.settingInvoiceShowTaxLine)) {
              add(doc('ضريبة القيمة المضافة 15%: 1.04'), size: 11);
            }
            add(doc('المستحق: 8.00 ر.س'), bold: true, size: 13);
            if (_effOn(controller, AppConstants.settingInvoiceShowPaid)) {
              add(doc('المدفوع: 8.00'), size: 11);
            }
            if (_effOn(controller, AppConstants.settingInvoiceShowRemaining)) {
              add(doc('المتبقي: 0.00'), size: 11);
            }
            final footer =
                controller.settings[AppConstants.settingInvoiceFooterNote] ??
                '';
            if (footer.trim().isNotEmpty) {
              add(footer.trim(), size: 10);
            }
            final showQr =
                _effOn(controller, AppConstants.settingInvoiceShowQr) &&
                _effOn(controller, AppConstants.settingInvoiceShowTaxNumber);
            if (showQr) {
              lines.add(
                const Icon(Icons.qr_code_2, size: 34, color: AppColors.indigo),
              );
            }
            // رمز الموقع يُعرض في المعاينة **فقط إن كان سيُطبع فعلًا** —
            // فالمعاينة لا تُظهر وعدًا لا يُنفَّذ. وسببه (إن لم يُطبع) مكتوب
            // في سطر الحالة أسفل البطاقة.
            final mapRaw =
                (controller.settings['business_location'] ?? '').trim();
            if (MapQr.isValid(mapRaw)) {
              lines.add(const SizedBox(height: 4));
              lines.add(
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      size: 26,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      doc('رمز QR للموقع'),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(children: lines);
          }),
        ),
        const SizedBox(height: 8),
        // الحكم على رابط الموقع في مكان المعاينة نفسه: من ينظر هنا ليعرف
        // «ماذا سيُطبع» يجب أن يجد الجواب لا أن يجرّب الطباعة.
        Obx(
          () => MapLinkStatusText(
            raw: controller.settings['business_location'] ?? '',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'معاينة تمثيلية بلغة الطباعة المختارة — تتغير مع كل خيار إظهار، ولا تُحفظ ولا تُطبع.',
          ),
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 10.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

/// **ترخيص النظام** — عرض الحالة وتعديل تاريخ انتهاء الاشتراك.
///
/// التعديل هنا يظهر بأثر فوري على البوابة العامة (`MyApp.builder`)، فلو
/// عُيّن تاريخ ماضٍ يُقفل النظام لحظيًا — وهذا مقصود. وكل تغيير يُسجَّل في
/// `audit_log` من المتحكّم نفسه.
Widget licenseCard(BuildContext context) {
  final license = Get.find<SystemLicenseController>();
  return SoftCard(
    padding: const EdgeInsets.all(16),
    child: Obx(() {
      final expiry = license.expiryDate;
      final color = license.isLocked
          ? AppColors.danger
          : license.isExpiringSoon
          ? AppColors.warning
          : license.isUnlimited
          ? AppColors.textMuted
          : AppColors.success;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: tr('ترخيص النظام'),
            icon: Icons.verified_user_outlined,
            color: AppColors.violet,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  license.isLocked
                      ? Icons.lock_clock
                      : Icons.event_available_outlined,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        license.statusLabel,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expiry == null
                            ? tr('لا يوجد تاريخ انتهاء')
                            : trf('تاريخ الانتهاء: {0}', [
                                SystemLicenseController.formatDate(expiry),
                              ]),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickExpiry(context, license, expiry),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: Text(
                    tr('تعيين تاريخ الانتهاء'),
                    style: TextStyle(fontFamily: 'cairo', fontSize: 13),
                  ),
                ),
              ),
              if (!license.isUnlimited) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => license.clearExpiry(),
                  child: Text(
                    tr('بلا تاريخ'),
                    style: TextStyle(fontFamily: 'cairo', fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // الدخول لسجل التغييرات: من مدّد ومتى وإلى أي تاريخ.
          SettingTile(
            icon: Icons.history,
            iconColor: AppColors.violet,
            title: tr('سجل الترخيص'),
            subtitle: tr('حالة الاشتراك والأيام المتبقية وسجل كل تغيير'),
            onTap: () => Get.toNamed(AppRoute.licenseLog),
          ),
          const SizedBox(height: 4),
          const Text(
            'غياب التاريخ يعني نظامًا غير محدود. ويُسجَّل كل تغيير في سجل التدقيق باسم محدّثه.',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
    }),
  );
}

Future<void> _pickExpiry(
  BuildContext context,
  SystemLicenseController license,
  DateTime? current,
) async {
  final now = SystemLicenseController.plainDate(DateTime.now());
  // لا `locale:` هنا — تمريره يُنهي التطبيق (انظر قاعدة موثّقة في MEMORY.md).
  final picked = await showDatePicker(
    context: context,
    initialDate: current != null && current.isAfter(now) ? current : now,
    firstDate: now,
    lastDate: DateTime(now.year + 30),
    helpText: tr('اختر تاريخ انتهاء اشتراك النظام'),
  );
  if (picked != null) {
    await license.setExpiry(picked);
    Get.snackbar(
      tr('تم الحفظ'),
      trf('تاريخ انتهاء الاشتراك: {0}', [
        SystemLicenseController.formatDate(
          SystemLicenseController.plainDate(picked),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. الطابعة وإخراج الفاتورة
// ═══════════════════════════════════════════════════════════════════════════

/// كتلة **إخراج الفاتورة (طباعة / PDF)** — تُعرض في آخر بطاقة «الطابعة
/// الافتراضية» مباشرةً تحت قائمة الطابعات.
///
/// ## لماذا كتلة داخل بطاقة الطابعة لا بطاقة مستقلّة؟
/// المستخدم يختار الطابعة ثم يتوقّع أن يرى فورًا خيار إخراج الفاتورة ومسار
/// حفظها في المكان نفسه. فالمفتاحان ([SettingOptions.invoicePrintOnSale] و
/// [SettingOptions.invoicePdfExport]) والمسار `invoice_pdf_directory` تُبنى
/// هنا، والمجموعة `invoiceOutput` **مستثناة** من [optionsSection] كي لا تظهر
/// الخيارات في موضعين.
///
/// ## الكتابة
/// كل كتابة تمرّ عبر [SettingsController.updateSetting] لا عبر الخدمة، فيبقى
/// كاش الإعدادات وقاعدة البيانات متزامنين. المفتاحان يُكتبان بـ`notify`
/// الافتراضي (رسالة «تم تحديث الإعداد»)، أما اختيار المجلد فيُكتب بـ
/// `notify: false` لأن للزرّ رسالته الأخصّ التي تُظهر المسار المختار.
class InvoiceOutputBlock extends StatefulWidget {
  const InvoiceOutputBlock({super.key, required this.controller});

  /// متحكّم الإعدادات — مصدر القراءة (الكاش) والكتابة (المسار الواحد).
  final SettingsController controller;

  @override
  State<InvoiceOutputBlock> createState() => _InvoiceOutputBlockState();
}

class _InvoiceOutputBlockState extends State<InvoiceOutputBlock> {
  final InvoiceOutputService _service = InvoiceOutputService.instance;

  bool _loading = true;
  String _chosen = '';
  String _effective = '';
  bool _exists = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chosen = await _service.chosenDirectory();
    final effective = await _service.effectiveDirectory();
    final exists = await _service.directoryExists();
    if (!mounted) return;
    setState(() {
      _chosen = chosen;
      _effective = effective;
      _exists = exists;
      _loading = false;
    });
  }

  Future<void> _pick() async {
    final picked = await _service.pickDirectory();
    if (picked == null || picked.trim().isEmpty) return;
    await _writeDirectory(picked.trim());
    await _load();
    Get.snackbar(
      tr('مجلد الحفظ'),
      trf('ستُحفظ نسخ الفواتير في: {0}', [picked.trim()]),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _clear() async {
    await _writeDirectory('');
    await _load();
    Get.snackbar(
      'مجلد الحفظ',
      'رجعنا إلى المجلد الافتراضي.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// الكتابة عبر المتحكّم (المسار خيار مسجَّل) — `notify: false` لأن لكل زرّ
  /// رسالته الأخصّ هنا.
  Future<void> _writeDirectory(String path) => widget.controller.updateSetting(
    AppConstants.settingInvoicePdfDirectory,
    path,
    notify: false,
  );

  Future<void> _open() async {
    final ok = await _service.openDirectory();
    if (ok) return;
    Get.snackbar(
      tr('تعذّر فتح المجلد'),
      trf('افتحه يدويًا: {0}', [_effective]),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: tr('إخراج الفاتورة (طباعة / PDF)'),
          icon: Icons.picture_as_pdf_outlined,
          color: AppColors.indigo,
          action: _loading
              ? null
              : IconButton(
                  tooltip: tr('فتح مجلد الحفظ'),
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: _open,
                ),
        ),
        // المفتاحان مستقلّان: طباعة وحدها · PDF وحده · الاثنان معًا (أرشيف).
        // لكلٍّ `Obx` خاصّ ليُعاد بناء مفتاحه وحده عند تغييره.
        Obx(
          () => _switch(widget.controller, SettingOptions.invoicePrintOnSale),
        ),
        const Divider(height: 18),
        // ورقة المغسلة تتبع مقاس الفاتورة نفسه، ولا تُطبَع إلا مع الطباعة،
        // فتوضع مستقلة بعد مفتاح الطباعة وقبل مفتاح PDF.
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _switch(
                widget.controller,
                SettingOptions.invoicePrintLaundrySlip,
              ),
              // الوصول المباشر إلى محرّر قالب الورقة من صفحة الطباعة نفسها:
              // «ماذا يظهر على نسخة المحل؟» سؤال طباعة لا سؤال تصميم فاتورة.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => Get.toNamed(
                    AppRoute.settingsDocTemplate,
                    arguments: DocKind.laundrySlip,
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(
                    tr('تحرير قالب ورقة المغسلة'),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 18),
        Obx(() => _switch(widget.controller, SettingOptions.invoicePdfExport)),
        const SizedBox(height: 12),
        Text(
          tr('مجلد حفظ نسخ PDF'),
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ..._body(),
      ],
    );
  }

  /// مفتاح إعداد منطقي — بنفس شكل صفوف خيارات النظام في الصفحة.
  Widget _switch(SettingsController controller, SettingOption option) {
    final on = isTruthy(controller.settings[option.key] ?? option.defaultValue);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: on,
      activeThumbColor: AppColors.primary,
      title: Text(
        tr(option.label),
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${tr(option.description)}\n${on ? tr('مُفعَّل') : tr('معطَّل')}',
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
      onChanged: (val) => controller.updateSetting(option.key, val ? '1' : '0'),
    );
  }

  List<Widget> _body() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ];
    }

    return [
      // المسار الفعلي — بخط ثابت لتفادي التباس الأحرف المتشابهة في المسارات.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _effective,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _chosen.isEmpty
            ? tr('لم يُختَر مجلد بعد — يُستخدم المجلد الافتراضي داخل «المستندات».')
            : (_exists
                  ? tr('مجلد مخصَّص وموجود.')
                  : tr('مجلد مخصَّص (سيُنشأ عند أول حفظ).')),
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          if (AppPlatform.isDesktop)
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(
                tr('اختيار المجلد'),
                style: TextStyle(fontFamily: 'cairo'),
              ),
            ),
          if (_chosen.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              label: Text(
                tr('إلغاء التخصيص'),
                style: TextStyle(fontFamily: 'cairo', color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
      if (!AppPlatform.isDesktop) ...[
        const SizedBox(height: 6),
        Text(
          tr(
            'اختيار المجلد متاح على ويندوز (سطح المكتب) فقط؛ على أندرويد تُحفظ النسخ داخل مجلد التطبيق.',
          ),
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ];
  }
}

/// قسم «الطابعة الافتراضية» — اختيار طابعة الجهاز **وإخراج الفاتورة**.
///
/// ## لماذا واجهة منفصلة عن بقية الخيارات؟
/// بقية الخيارات قيم نصّية/منطقية في جدول `settings` تُبنى آليًا من سجل
/// [SettingOptions]. أما الطابعة فتتطلّب **قراءة غير متزامنة** لقائمة طابعات
/// النظام من حزمة `printing` — وهي حالة عرض لا تنتمي لسجل الخيارات.
///
/// ## السلوك
///   • **سطح المكتب**: تُسرد طابعات الجهاز، ويُختار واحدة فتُحفظ في `settings`
///     (`printer_selected_url` / `printer_selected_name`)، **ويُفعَّل معها**
///     خيار «الطباعة على الطابعة المختارة تلقائيًا» — فالاختيار مرة واحدة
///     يكفي لطباعة الفواتير مباشرةً بلا حوار.
///   • **أندرويد**: لا تدعم الحزمة سرد الطابعات، فيُشرح البديل (حوار النظام أو
///     تطبيق وسيط مثل RawBT للطابعات الحرارية عبر البلوتوث).
///   • **آخر خيار في البطاقة** — [InvoiceOutputBlock]: مفتاحا الطباعة عند
///     البيع وحفظ نسخة PDF، ومسار مجلد الحفظ. يجمع كل ما يتعلق بمخرَج
///     الفاتورة في موضع واحد تحت قائمة الطابعات (ويظهر على أندرويد أيضًا).
///
/// ## الحذر
/// إن حُذفت الطابعة المختارة من الجهاز لاحقًا، يرجع [PrinterService] تلقائيًا
/// إلى حوار النظام — فلا يتوقّف الطباعة ولا يفقد المستخدم عمله.
class PrinterSection extends StatefulWidget {
  const PrinterSection({super.key, required this.controller});

  /// متحكّم الإعدادات — لتفعيل خيار «الطباعة التلقائية» عند اختيار طابعة،
  /// فيتزامن مفتاحه في مجموعة «الطباعة» فورًا.
  final SettingsController controller;

  @override
  State<PrinterSection> createState() => _PrinterSectionState();
}

class _PrinterSectionState extends State<PrinterSection> {
  final PrinterService _service = PrinterService.instance;

  bool _loading = true;
  bool _supported = false;
  List<Printer> _printers = const <Printer>[];
  String _selectedUrl = '';
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supported = await _service.canListPrinters();
    final printers = supported
        ? await _service.listPrinters()
        : const <Printer>[];
    final url = await _service.selectedUrl();
    final name = await _service.selectedName();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _printers = printers;
      _selectedUrl = url;
      _selectedName = name;
      _loading = false;
    });
  }

  /// زر التحديث: يُظهر مؤشّر تحميل ثم يعيد قراءة القائمة.
  void _refresh() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _pick(Printer printer) async {
    await _service.setDefault(printer);
    // اختيار الطابعة يعني «اطبع عليها تلقائيًا» — نُفعِّل الخيار معها حتى لا
    // يختار المستخدم طابعة ثم ينتظر حوار طباعة في كل فاتورة.
    if (!_autoPrintOn) {
      await widget.controller.updateSetting(
        AppConstants.settingPrintUseDefaultPrinter,
        '1',
        notify: false,
      );
    }
    if (!mounted) return;
    setState(() {
      _selectedUrl = printer.url;
      _selectedName = printer.name;
    });
    Get.snackbar(
      tr('الطابعة'),
      trf('تم اختيار «{0}» — ستُطبَع الفواتير عليها تلقائيًا.', [
        printer.name,
      ]),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// هل خيار الطباعة التلقائية مُفعَّل حاليًا؟
  bool get _autoPrintOn => isTruthy(
    widget.controller.settings[AppConstants.settingPrintUseDefaultPrinter] ??
        '0',
  );

  Future<void> _clear() async {
    await _service.clearDefault();
    if (!mounted) return;
    setState(() {
      _selectedUrl = '';
      _selectedName = '';
    });
    Get.snackbar(
      tr('الطابعة'),
      tr('أُلغي الاختيار — سيظهر حوار الطباعة في كل مرة.'),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: tr('الطابعة الافتراضية'),
            icon: Icons.print_outlined,
            color: AppColors.slate,
            action: (_supported && !_loading)
                ? IconButton(
                    tooltip: tr('تحديث قائمة الطابعات'),
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _refresh,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          ..._body(),
          // ─── آخر خيار في البطاقة: إخراج الفاتورة (طباعة / PDF) ───
          // يلي قائمة الطابعات مباشرةً: يختار المستخدم طابعته ثم يرى تحته
          // فورًا مفتاحَي الطباعة/PDF ومسار حفظ النسخ.
          const SizedBox(height: 4),
          const Divider(height: 26),
          InvoiceOutputBlock(controller: widget.controller),
        ],
      ),
    );
  }

  /// محتوى البطاقة بحسب النظام والحالة.
  List<Widget> _body() {
    if (!AppPlatform.isDesktop) return _androidNote();
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ];
    }
    if (!_supported) {
      return _hint('تعذّر سرد طابعات النظام على هذا الجهاز.');
    }
    if (_printers.isEmpty) {
      return _hint(
        'لا توجد طابعات مثبَّتة على الجهاز. أضِف طابعة من إعدادات ويندوز ثم اضغط زر التحديث.',
      );
    }
    return [
      Text(
        _selectedUrl.isEmpty
            ? tr('لم تُختَر طابعة — سيظهر حوار الطباعة في كل مرة.')
            : trf('المختارة: {0}', [_selectedName]),
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),
      for (final printer in _printers) _tile(printer),
      if (_selectedUrl.isNotEmpty) ...[
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            label: Text(
              tr('إلغاء الاختيار'),
              style: TextStyle(fontFamily: 'cairo', color: AppColors.danger),
            ),
          ),
        ),
      ],
    ];
  }

  /// صفّ طابعة واحدة — نقرة كاملة لاختيارها.
  Widget _tile(Printer printer) {
    final selected = printer.url == _selectedUrl;
    final subtitle = printer.isDefault
        ? 'الافتراضية في النظام'
        : (printer.isAvailable ? '' : 'غير متصلة');
    return InkWell(
      onTap: () => _pick(printer),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    printer.name,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      tr(subtitle),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: printer.isDefault
                            ? AppColors.info
                            : AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.success,
              ),
          ],
        ),
      ),
    );
  }

  /// سطر تلميح بسيط (فشل السرد أو لا طابعات).
  List<Widget> _hint(String text) => [
    Text(
      tr(text),
      style: const TextStyle(
        fontFamily: 'cairo',
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    ),
  ];

  /// ملاحظة أندرويد: لا سرد طابعات، مع شرح البدائل.
  List<Widget> _androidNote() => [
    Text(
      tr('اختيار الطابعة الافتراضية متاح على ويندوز (سطح المكتب) فقط.'),
      style: TextStyle(
        fontFamily: 'cairo',
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(height: 4),
    Text(
      tr(
        'على أندرويد يُفتح حوار الطباعة في كل مرة (سلوك النظام). وللطابعات الحرارية عبر البلوتوث يُستخدم تطبيق وسيط مثل RawBT.',
      ),
      style: TextStyle(
        fontFamily: 'cairo',
        fontSize: 11.5,
        color: AppColors.textSecondary,
      ),
    ),
  ];
}

/// 🌐 اختيار لغة النظام — يغيّر كل نصّ واتجاه في التطبيق **فورًا**.
///
/// ثلاث خيارات: العربية · English · لغة الجهاز. و«لغة الجهاز» ليست لغة
/// ثالثة بل **قاعدة حسم**: النظام يقرأ لغة النظام التشغيلي ويختار (عربي ⇒
/// عربي، غير ذلك ⇒ إنجليزي) — فالعميل على جهاز إنجليزي يجد واجهة إنجليزية
/// بلا إعداد.
/// **لغة الطباعة** — التحكّم الوحيد في لغة **كل** مستند يخرج من النظام.
///
/// ## القرار
/// `settings.doc_language` يحكم: الفاتورة · كشف الحساب · ملخص الوردية · ورقة
/// المغسلة · المشاركة على واتساب. وهو **مستقلّ تمامًا** عن لغة الواجهة
/// (`settings.language`): واجهة عربية وورق إنجليزي، أو العكس، بلا تعارض.
/// ولا يُشتقّ من `L10n` إطلاقًا لأن الرسم يحدث داخل `compute` (عزل لا يرى
/// الحالة العامة للترجمة).
///
/// ## لماذا بطاقة مستقلّة لا سطرًا في مجموعة؟
/// لأن الخيار كان سطرًا منسدلًا مدفونًا بين خمسة عشر سطرًا تحت «ما يظهر على
/// الفاتورة» — فيظنّ من رآه أنه يخصّ الفاتورة وحدها، أو لا يجده أصلًا. وهو
/// ليس خيار «إظهار» بل **قرار لغة المستند**، فاستحقّ بطاقة صريحة.
///
/// ## صادق لا مُجمَّل
/// اللغة **غير مخزَّنة في صفّ الفاتورة**: إعادة طباعة فاتورة قديمة تستخدم
/// اللغة المختارة **الآن**. لذلك تُكتب هذه الحقيقة في البطاقة نفسها بدل أن
/// يكتشفها المستخدم بعد سنة.
Widget docLanguageCard(SettingsController controller) {
  return Obx(() {
    final raw =
        controller.settings[AppConstants.settingDocLanguage] ??
        SettingOptions.docLanguage.defaultValue;
    final current = DocLanguage.byCode(raw);
    final uiLang =
        L10n.isEnglish ? L10n.language.labelEn : L10n.language.label;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: tr('لغة الطباعة'), icon: Icons.translate),
          const SizedBox(height: 6),
          Text(
            tr(
              'لغة كل مستند يخرج من النظام: الفاتورة · كشف الحساب · ملخص الوردية · ورقة المغسلة. لا تتبع لغة النظام.',
            ),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lang in DocLanguage.values)
                _DocLanguageChip(
                  lang: lang,
                  active: lang == current,
                  onTap: () {
                    if (lang == current) return;
                    // المسار الواحد للكتابة: تطبيع + upsert + كاش + تدقيق.
                    controller.updateSetting(
                      AppConstants.settingDocLanguage,
                      lang.code,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _DocLanguageNote(
            icon: Icons.language,
            text: trf('لغة النظام الآن: {0} — تغييرها لا يغيّر لغة الطباعة.', [
              uiLang,
            ]),
          ),
          const SizedBox(height: 6),
          _DocLanguageNote(
            icon: Icons.history,
            color: AppColors.warning,
            text: tr(
              'تُطبَّق اللغة عند كل طباعة — إعادة طباعة فاتورة قديمة تستخدم اللغة المختارة الآن.',
            ),
          ),
        ],
      ),
    );
  });
}

/// **مقاسات العناصر المطبوعة** — الشعار ورمز QR: عرض × ارتفاع × مساحة.
///
/// ## لماذا بطاقة مستقلة؟
/// كانت هذه القيم أسطرًا داخل مجموعة «ما يظهر على الفاتورة» (١٥ سطرًا)،
/// والقيمة الواحدة تُغيّر شكل الورق كلّه. والأهمّ أن المستخدم كان يضبط رقمًا
/// **ولا يعرف ما سيُطبع فعلًا**: العرض يُقصّ على الورق، والارتفاع الكبير يدفع
/// الأصناف إلى صفحة ثانية — كلاهما بلا أي إعلان.
///
/// فالبطاقة تفعل ثلاثة أشياء معًا: تضبط، **تحسب** (مساحة ونسبة من الورق)،
/// و**تعلن** التقييد («طُلب ٨٠ مم وسيُطبع ٤٨»). لا رقم بلا أثره.
Widget printSizesCard(SettingsController controller) {
  return Obx(() {
    final paper = PaperSizes.resolve(
      controller.settings[AppConstants.settingInvoicePaperSize],
    );
    final page = PrintVisualSize.pageOf(paper);

    // الحساب بنفس الدالة التي يرسم بها المولّد — لا معادلة ثانية في الواجهة
    // قد تنحرف عن الورق الحقيقي.
    final logoBox = PrintVisualSize.logo(
      widthMm: controller.settings[AppConstants.settingInvoiceLogoWidth],
      heightMm: controller.settings[AppConstants.settingInvoiceLogoHeight],
      maxWidth: page.widthPoints,
      maxHeight: page.heightPoints,
    );
    final qrBox = PrintVisualSize.qr(
      sizeMm: controller.settings[AppConstants.settingMapQrSize],
      maxWidth: page.widthPoints,
      maxHeight: page.heightPoints,
    );

    final logoShare = PrintVisualSize.shareOfPage(logoBox, page);
    final qrShare = PrintVisualSize.shareOfPage(qrBox, page);
    final budget = PrintVisualSize.verticalBudget(logoBox, qrBox, page);
    final tight = budget > PrintVisualSize.verticalBudgetWarn;
    final logoOn = _effOn(controller, AppConstants.settingInvoiceShowLogo);
    final mapUrl = MapQr.resolve(controller.settings['business_location']);

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: tr('مقاسات الطباعة'), icon: Icons.straighten),
          const SizedBox(height: 6),
          Text(
            tr(
              'عرض وارتفاع الشعار ورمز QR بالمليمتر — وتُحسب مساحتهما ونسبتهما من الورق، وتُقصّ القيم تلقائيًّا على مقاس الورق المختار.',
            ),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _optionRow(controller, SettingOptions.invoiceLogoWidth),
          const Divider(height: 18),
          _optionRow(controller, SettingOptions.invoiceLogoHeight),
          const Divider(height: 18),
          _optionRow(controller, SettingOptions.mapQrSize),

          // ─── أزرار سريعة ───
          const SizedBox(height: 4),
          // الحقول تحفظ عند تأكيدها فقط (سلوك كل خيارات الإعدادات: لا تُخزَّن
          // قيمة نصف مكتوبة). فمن كتب رقمًا وانتقل بلا Enter يظنّ أنه حُفظ.
          Text(
            tr('اكتب الرقم ثم اضغط Enter لتطبيقه.'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  // شعار مربّع بضغطة: نسخ العرض إلى الارتفاع.
                  final w =
                      controller.settings[AppConstants.settingInvoiceLogoWidth] ??
                      '${AppConstants.invoiceLogoWidthDefaultMm}';
                  controller.updateSetting(
                    AppConstants.settingInvoiceLogoHeight,
                    w,
                  );
                },
                icon: const Icon(Icons.crop_square, size: 16),
                label: Text(
                  tr('اجعل الشعار مربّعًا'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 11.5),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  controller.updateSetting(
                    AppConstants.settingInvoiceLogoWidth,
                    '${AppConstants.invoiceLogoWidthDefaultMm}',
                  );
                  controller.updateSetting(
                    AppConstants.settingInvoiceLogoHeight,
                    '${AppConstants.invoiceLogoHeightDefaultMm}',
                  );
                  controller.updateSetting(
                    AppConstants.settingMapQrSize,
                    '${AppConstants.mapQrSizeDefaultMm}',
                  );
                },
                icon: const Icon(Icons.restart_alt, size: 16),
                label: Text(
                  tr('القيم الافتراضية'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 11.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          _SizeReadout(
            icon: Icons.image_outlined,
            title: trf('الشعار على الورق: {0} × {1} مم', [
              _mmText(logoBox.widthMm),
              _mmText(logoBox.heightMm),
            ]),
            detail: trf('المساحة القصوى {0} مم² — {1}% من الورق', [
              _areaText(logoBox.areaMm2),
              _pctText(logoShare),
            ]),
            muted: !logoOn,
          ),
          const SizedBox(height: 6),
          _SizeReadout(
            icon: Icons.qr_code_2,
            title: trf('رمز QR: {0} × {1} مم', [
              _mmText(qrBox.widthMm),
              _mmText(qrBox.heightMm),
            ]),
            detail: mapUrl.isEmpty
                ? tr('لا يُطبع: لم يُسجَّل رابط موقع النشاط بعد.')
                : trf('المساحة القصوى {0} مم² — {1}% من الورق', [
                    _areaText(qrBox.areaMm2),
                    _pctText(qrShare),
                  ]),
            muted: mapUrl.isEmpty,
          ),
          const SizedBox(height: 6),
          _SizeReadout(
            icon: tight ? Icons.warning_amber_rounded : Icons.space_bar,
            title: trf('مجموع ارتفاعهما {0}% من ارتفاع الورق', [
              _pctText(budget),
            ]),
            detail: tight
                ? tr(
                    'النسبة كبيرة: الرأس والتذييل يأكلان أغلب الورقة. صغّر الشعار أو الرمز كي لا يتزاحم النصّ أو يُدفع إلى صفحة ثانية.',
                  )
                : trf('الورق المختار: {0} — والمتاح للطباعة {1} مم عرضًا.', [
                    paper.label,
                    _mmText(page.widthMm),
                  ]),
            danger: tight,
          ),

          if (logoBox.clamped) ...[
            const SizedBox(height: 6),
            _SizeReadout(
              icon: Icons.content_cut,
              title: trf('الشعار سيُقصّ: طُلب أكبر من الورق ({0} مم عرضًا).', [
                _mmText(page.widthMm),
              ]),
              detail: trf('سيُطبع {0} × {1} مم بدل المقاس المطلوب.', [
                _mmText(logoBox.widthMm),
                _mmText(logoBox.heightMm),
              ]),
              danger: true,
            ),
          ],
          if (qrBox.clamped) ...[
            const SizedBox(height: 6),
            _SizeReadout(
              icon: Icons.content_cut,
              title: trf('رمز QR سيُقصّ إلى {0} مم لأن الورق لا يتّسع أكثر.', [
                _mmText(qrBox.widthMm),
              ]),
              detail: tr('الأفضل اختيار مقاس أقلّ من ذلك صراحةً لتعرف ما سيُطبع.'),
              danger: true,
            ),
          ],
        ],
      ),
    );
  });
}

/// سطر حساب مقروء: عنوان + تفصيل + أيقونة حالة.
class _SizeReadout extends StatelessWidget {
  const _SizeReadout({
    required this.icon,
    required this.title,
    required this.detail,
    this.danger = false,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool danger;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color =
        danger
            ? AppColors.danger
            : muted
            ? AppColors.textSecondary
            : AppColors.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// مليمتر بلا كسور — المستخدم يضبط أعدادًا صحيحة.
String _mmText(double value) => value.toStringAsFixed(0);

/// نسبة مئوية بخانة واحدة (٤٫٦٪).
String _pctText(double ratio) => (ratio * 100).toStringAsFixed(1);

/// مساحة بفاصل آلاف — 2,809 مم² تُقرأ أسرع من 2809.
String _areaText(double value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// زرّ لغة واحدة في بطاقة «لغة الطباعة» — بنفس شكل أزرار «لغة النظام».
class _DocLanguageChip extends StatelessWidget {
  const _DocLanguageChip({
    required this.lang,
    required this.active,
    required this.onTap,
  });

  final DocLanguage lang;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('doc-language-${lang.code}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              active
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(
                Icons.check_circle,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              lang == DocLanguage.arabic ? lang.label : lang.labelEn,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر توضيحي صغير داخل بطاقة لغة الطباعة.
class _DocLanguageNote extends StatelessWidget {
  const _DocLanguageNote({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              height: 1.45,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final locale = LocaleController.instance;
    return Obx(() {
      final current = locale.choice.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text(
                tr('لغة النظام'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                current == AppLanguage.system
                    ? '${tr('لغة الجهاز')} · ${locale.resolved.value.labelEn}'
                    : current.labelEn,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                AppLanguage.choices.map((lang) {
                  final active = lang == current;
                  return InkWell(
                    key: ValueKey<String>('language-${lang.code}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => locale.setLanguage(lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            active
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              active ? AppColors.primary : AppColors.border,
                          width: active ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (active) ...[
                            const Icon(
                              Icons.check_circle,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            lang == AppLanguage.system
                                ? tr('لغة الجهاز')
                                : lang.label,
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.bold : FontWeight.w600,
                              color:
                                  active
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            tr('تُطبَّق على كل شاشات النظام فورًا بلا إعادة تشغيل.'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
    });
  }
}
