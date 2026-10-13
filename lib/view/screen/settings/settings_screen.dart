import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/controller/settings/settings_controller.dart';
import 'package:laundry/controller/settings/theme_controller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/database/backup_naming.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/customappbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    controller.loadSettings();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: CustomAppbar(
          title: 'الإعدادات',
          subtitle: 'إعدادات النظام والنشاط التجاري',
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.settings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              FadeInUp(child: _businessInfoCard(controller)),
              const SizedBox(height: 14),
              // ─── النسخ الاحتياطي ───
              // لمدير النظام وحده: الاستعادة تستبدل قاعدة البيانات كلها،
              // فلا تُتاح لأي حساب عامل.
              if (PermissionService.canPerformBackup) ...[
                FadeInUp(delayMs: 80, child: _backupSection(controller)),
                const SizedBox(height: 14),
              ],
              // ─── ترخيص النظام ───
              // لمدير النظام (admin) وحده: هو من يتحمّل قرار الاشتراك. إخفاؤه
              // عن غيره يمنع تمديد المدة ذاتيًا من أي حساب عامل.
              if (PermissionService.canManageSettings) ...[
                FadeInUp(delayMs: 120, child: _licenseSection(context)),
                const SizedBox(height: 14),
              ],
              // ─── أكواد الخصم ───
              // للإدارة (مدير النظام/المدير): الخصم يُنقص الإيراد مباشرةً،
              // فإدارته ليست عمل كاشير.
              if (PermissionService.canManageDiscounts) ...[
                FadeInUp(delayMs: 140, child: _discountsSection()),
                const SizedBox(height: 14),
              ],
              FadeInUp(delayMs: 160, child: _appearanceSection(controller)),
              const SizedBox(height: 14),
              // ─── معاينة الفاتورة الحيّة ───
              // تتغير فورًا مع كل خيار إظهار، فالمستخدم يرى أثر الإعداد
              // قبل أن يطبعه على فاتورة حقيقية.
              FadeInUp(delayMs: 170, child: _invoicePreviewCard(controller)),
              const SizedBox(height: 14),
              // ─── بحث في خيارات النظام ───
              FadeInUp(
                delayMs: 176,
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: TextField(
                    onChanged: (v) => controller.optionSearch.value = v.trim(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: AppColors.primary),
                      hintText: 'ابحث في خيارات النظام...',
                      suffixIcon:
                          controller.optionSearch.value.isEmpty
                              ? null
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
              ),
              const SizedBox(height: 14),
              // ─── خيارات النظام ───
              // بطاقة لكل مجموعة، مبنية من السجل الواحد [SettingOptions.all]:
              // كل قيمة كانت ثابتًا في `config/constants.dart` صارت هنا خيارًا
              // يُفعَّل/يُعطَّل وتُحدَّد قيمته. وخيارات الترخيص لمدير النظام
              // وحده (كقسم «ترخيص النظام» أعلى الصفحة).
              _systemOptionsSections(controller),
              FadeInUp(delayMs: 400, child: _aboutSection()),
              const SizedBox(height: 20),
              // حقوق المطوّر — نهاية صفحة الإعدادات
              const FadeInUp(
                delayMs: 440,
                child: DeveloperCredit(
                  fontSize: 12,
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
      ),
    );
  }

  Widget _businessInfoCard(SettingsController controller) {
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
          const SectionHeader(
            title: 'معلومات النشاط التجاري',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم النشاط',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: locationCtrl,
            decoration: const InputDecoration(
              labelText: 'رابط الموقع (Google Maps)',
              hintText: 'اختياري — الصق رابط الخريطة',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: taxNumberCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'الرقم الضريبي (VAT)',
              hintText: 'اختياري — 15 رقمًا، يظهر على الفاتورة وQR الهيئة',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: crCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'السجل التجاري',
              hintText: 'اختياري — يظهر على الفاتورة عند تفعيل خياره',
              prefixIcon: Icon(Icons.business_center_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: shortAddressCtrl,
            decoration: const InputDecoration(
              labelText: 'العنوان الوطني المختصر',
              hintText: 'اختياري — يظهر على الفاتورة عند تفعيل خياره',
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
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'حفظ المعلومات',
                style: TextStyle(fontFamily: 'cairo'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupSection(SettingsController controller) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'النسخ الاحتياطي',
            icon: Icons.backup_outlined,
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: Icons.backup,
            iconColor: AppColors.success,
            title: 'إنشاء نسخة احتياطية',
            subtitle: 'نسخة SQLite خام (‎.db‎) باسم ومكان تختارهما',
            onTap: () async {
              final result = await controller.exportData();
              if (result.success) {
                final where = result.cancelled
                    ? 'حُفظت داخل التطبيق فقط'
                    : 'حُفظت في: ${result.savedPath}';
                Get.snackbar(
                  'تم إنشاء النسخة',
                  '$where\n${BackupNaming.formatSize(result.sizeBytes)}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.success,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 5),
                );
              } else {
                Get.snackbar(
                  'فشل في إنشاء النسخة',
                  result.error ?? 'سبب غير معروف',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.danger,
                  colorText: Colors.white,
                );
              }
            },
          ),
          const Divider(height: 20),
          _SettingTile(
            icon: Icons.restore,
            iconColor: AppColors.warning,
            title: 'إدارة النسخ والاستعادة',
            subtitle: 'قائمة النسخ المحفوظة · استعادة من أي ملف على الجهاز',
            onTap: () => Get.toNamed(AppRoute.backup),
          ),
        ],
      ),
    );
  }

  /// بطاقة أكواد الخصم — مدخل شاشة الإدارة.
  Widget _discountsSection() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'الخصومات',
            icon: Icons.local_offer_outlined,
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: Icons.confirmation_number_outlined,
            iconColor: AppColors.success,
            title: 'إدارة أكواد الخصم',
            subtitle: 'نسبة أو مبلغ ثابت · تاريخ سريان · حدّ استخدام',
            onTap: () => Get.toNamed(AppRoute.discounts),
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(SettingsController controller) {    final theme = ThemeController.instance;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المظهر', icon: Icons.brush_outlined),
          const SizedBox(height: 10),
          Obx(() {
            final fontSize =
                theme.fontScale.value * ThemeController.baseFontSize;
            return Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_fields, color: AppColors.secondary),
                    const SizedBox(width: 10),
                    const Text(
                      'حجم الخط',
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

  /// معاينة حيّة لشكل الفاتورة وفق خيارات الإظهار الحالية.
  ///
  /// ليست الحساب الفعلي (ذاك في ترقيم الفاتورة)، بل عرض تمثيلي يبيّن للمستخدم
  /// أثر كل خيار قبل الطباعة.
  Widget _invoicePreviewCard(SettingsController controller) {
    final biz = BusinessInfoService.instance;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'معاينة الفاتورة',
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
              final lines = <Widget>[];
              void add(String text, {bool bold = false, double size = 12}) {
                lines.add(
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: size,
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal,
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
                biz.name.isEmpty ? 'اسم النشاط' : biz.name,
                bold: true,
                size: 13,
              );
              if (_effOn(controller, AppConstants.settingInvoiceShowShortAddress)) {
                add('العنوان الوطني: 1234 الرياض', size: 11);
              }
              add(
                controller.settings[AppConstants.settingInvoiceTitleText] ??
                    AppConstants.invoiceTitleTextDefault,
                bold: true,
              );
              if (_effOn(controller, AppConstants.settingInvoiceShowTaxNumber)) {
                final tn = biz.taxNumber.isEmpty ? '300000000000003' : biz.taxNumber;
                add('الرقم الضريبي: $tn', size: 11);
              }
              if (_effOn(controller, AppConstants.settingInvoiceShowCrNumber)) {
                add('السجل التجاري: 1010000000', size: 11);
              }
              if (_effOn(controller, AppConstants.settingInvoiceShowDatetime)) {
                add('التاريخ: 2026-10-06 10:30 ص', size: 11);
              }
              if (_effOn(controller, AppConstants.settingInvoiceShowCashier)) {
                add('صدر بواسطة: مدير النظام', size: 11);
              }
              if (_effOn(controller, AppConstants.settingInvoiceShowPickupCode)) {
                add('رمز الاستلام: 1234', size: 11);
              }
              add('— قميص ×1 = 10.00 —', size: 11);
              if (_effOn(
                controller,
                AppConstants.settingInvoiceShowDiscountLine,
              )) {
                add('الخصم: 2.00', size: 11);
              }
              if (_effOn(controller, AppConstants.settingTaxEnabled) &&
                  _effOn(controller, AppConstants.settingInvoiceShowTaxLine)) {
                add('ضريبة القيمة المضافة 15%: 1.04', size: 11);
              }
              add('المستحق: 8.00 ر.س', bold: true, size: 13);
              if (_effOn(controller, AppConstants.settingInvoiceShowPaid)) {
                add('المدفوع: 8.00', size: 11);
              }
              if (_effOn(controller, AppConstants.settingInvoiceShowRemaining)) {
                add('المتبقي: 0.00', size: 11);
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
              return Column(children: lines);
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'معاينة تمثيلية تتغير مع كل خيار إظهار — لا تُحفظ ولا تُطبع.',
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

  /// هل الخيار مُفعَّل فعلًا (نفسه وكل أسلافه)؟
  bool _effOn(SettingsController controller, String key) {
    final option = SettingOptions.byKey(key);
    if (option == null) return _isOn(controller, key);
    return isEffectivelyOn(
      option,
      (k) => controller.settings[k],
    );
  }

  /// بطاقات **خيارات النظام** — مبنية من السجل الواحد [SettingOptions.all].
  ///
  /// كل قيمة كانت ثابتًا في `config/constants.dart` (ترقيم الفواتير · الاحتفاظ
  /// بالبيانات · الولاء · الضريبة · الترخيص · العملة) صارت خيارًا هنا: مفتاح
  /// تفعيل/تعطيل + حقل لتحديد القيمة. وإضافة أي خيار جديد إلى السجل تُظهره في
  /// هذه الصفحة تلقائيًا بلا أي تعديل في الواجهة.
  Widget _systemOptionsSections(SettingsController controller) {
    return Obx(() {
      final query = controller.optionSearch.value.trim().toLowerCase();
      final widgets = <Widget>[];
      var delayMs = 180;
      for (final group in SettingGroups.ordered) {
        final meta = _groupMeta[group];
        var options = SettingOptions.ofGroup(group);
        if (meta == null || options.isEmpty) continue;
        // خيارات الترخيص لمدير النظام وحده — كقسم «ترخيص النظام» أعلى الصفحة.
        final adminOnly =
            group == SettingGroups.license &&
            !PermissionService.canManageSettings;
        if (adminOnly) continue;
        // تصفية البحث: بالعنوان أو الوصف أو المفتاح.
        if (query.isNotEmpty) {
          options = options
              .where(
                (o) =>
                    o.label.toLowerCase().contains(query) ||
                    o.description.toLowerCase().contains(query) ||
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
        return const SoftCard(
          padding: EdgeInsets.all(16),
          child: Text(
            'لا يوجد خيار مطابق للبحث.',
            style: TextStyle(fontFamily: 'cairo', fontSize: 13),
            textAlign: TextAlign.center,
          ),
        );
      }
      return Column(children: widgets);
    });
  }

  Widget _optionsCard(
    SettingsController controller,
    _GroupMeta meta,
    List<SettingOption> options,
  ) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: meta.title, icon: meta.icon, color: meta.color),
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
              meta.note!,
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
          option.label,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${option.description}\n${on ? 'مُفعَّل' : 'معطَّل'}',
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
        onChanged:
            (val) => controller.updateSetting(option.key, val ? '1' : '0'),
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
                  option.label,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.description,
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
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              items:
                  choices
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(
                            option.labelOfChoice(c),
                            style: const TextStyle(fontFamily: 'cairo'),
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  (val) =>
                      val == null
                          ? null
                          : controller.updateSetting(option.key, val),
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
                option.label,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.description,
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
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            // الحفظ عند تأكيد الحقل فقط — لا مع كل حرف، فلا تُخزَّن قيم ناقصة
            // أثناء الكتابة (مثل "1" من "15").
            onFieldSubmitted:
                (val) => controller.updateSetting(option.key, val),
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

  /// القيمة المطبَّعة المعروضة في الحقل (بحسب نوع الخيار وحدوده).
  String _valueOf(SettingsController controller, SettingOption option) =>
      normalizeValue(option, controller.settings[option.key]);

  /// قسم «ترخيص النظام» — عرض الحالة وتعديل تاريخ انتهاء الاشتراك.
  ///
  /// التعديل هنا يظهر بأثر فوري على البوابة العامة (`MyApp.builder`)، فلو
  /// عُيّن تاريخ ماضٍ يُقفل النظام لحظيًا — وهذا مقصود. وكل تغيير يُسجَّل في
  /// `audit_log` من المتحكّم نفسه.
  Widget _licenseSection(BuildContext context) {
    final license = Get.find<SystemLicenseController>();
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final expiry = license.expiryDate;
        final color =
            license.isLocked
                ? AppColors.danger
                : license.isExpiringSoon
                ? AppColors.warning
                : license.isUnlimited
                ? AppColors.textMuted
                : AppColors.success;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'ترخيص النظام',
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
                              ? 'لا يوجد تاريخ انتهاء'
                              : 'تاريخ الانتهاء: '
                                  '${SystemLicenseController.formatDate(expiry)}',
                          style: TextStyle(
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
                    label: const Text(
                      'تعيين تاريخ الانتهاء',
                      style: TextStyle(fontFamily: 'cairo', fontSize: 13),
                    ),
                  ),
                ),
                if (!license.isUnlimited) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => license.clearExpiry(),
                    child: const Text(
                      'بلا تاريخ',
                      style: TextStyle(fontFamily: 'cairo', fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // الدخول لسجل التغييرات: من مدّد ومتى وإلى أي تاريخ.
            _SettingTile(
              icon: Icons.history,
              iconColor: AppColors.violet,
              title: 'سجل الترخيص',
              subtitle: 'حالة الاشتراك والأيام المتبقية وسجل كل تغيير',
              onTap: () => Get.toNamed(AppRoute.licenseLog),
            ),
            const SizedBox(height: 4),
            Text(
              'غياب التاريخ يعني نظامًا غير محدود. ويُسجَّل كل تغيير في سجل '
              'التدقيق باسم محدّثه.',
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
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: now,
      lastDate: DateTime(now.year + 30),
      helpText: 'اختر تاريخ انتهاء اشتراك النظام',
    );
    if (picked != null) {
      await license.setExpiry(picked);
      Get.snackbar(
        'تم الحفظ',
        'تاريخ انتهاء الاشتراك: '
            '${SystemLicenseController.formatDate(SystemLicenseController.plainDate(picked))}',
      );
    }
  }

  Widget _aboutSection() {
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
                : 'نظام إدارة المغاسل',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الإصدار ${AppInfo.version}',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'نظام إدارة المغاسل الشامل — تصميم عصري وتجربة سلسة',
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
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingTile({
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

/// وصف عرض المجموعة: العنوان · الأيقونة · اللون · ملاحظة أسفل البطاقة.
///
/// الأيقونات والألوان خاصة بالواجهة، فلا تُوضع في ملف المنطق الخالص
/// (`lib/services/settings/setting_option.dart`) — الربط بالمفتاح هنا.
class _GroupMeta {
  final String title;
  final IconData icon;
  final Color color;
  final String? note;

  const _GroupMeta(this.title, this.icon, this.color, [this.note]);
}

/// مجموعات خيارات النظام كما تُعرض في الصفحة (بالترتيب في
/// [SettingGroups.ordered]).
const Map<String, _GroupMeta> _groupMeta = <String, _GroupMeta>{
  SettingGroups.invoicing: _GroupMeta(
    'الفوترة والترقيم',
    Icons.receipt_long_outlined,
    AppColors.primary,
    'الترقيم لا يتراجع: لا يقلّ رقم الفاتورة الجديدة عن أعلى رقم مسجَّل.',
  ),
  SettingGroups.invoiceDisplay: _GroupMeta(
    'ما يظهر على الفاتورة',
    Icons.visibility_outlined,
    AppColors.secondary,
    'كل خيار يُظهر/يُخفي حقلًا على الفاتورة المطبوعة. المعاينة أعلاه تتبع '
        'هذه الخيارات مباشرةً.',
  ),
  SettingGroups.printing: _GroupMeta(
    'الطباعة بكل المقاسات',
    Icons.print_outlined,
    AppColors.slate,
    'A4 · A5 · A6 · حراري 80/58 مم · ملصقات. التفعيل لا يغيّر سلوك أي '
        'تثبيت قائم حتى تختار المقاس.',
  ),
  SettingGroups.expensesVat: _GroupMeta(
    'ضريبة المدخلات (المصروفات)',
    Icons.receipt_rounded,
    AppColors.warning,
    'ضريبة المشتريات القابلة للخصم — تدخل في تقرير الإقرار الضريبي.',
  ),
  SettingGroups.receivables: _GroupMeta(
    'الذمم والائتمان',
    Icons.account_balance_wallet_outlined,
    AppColors.info,
    'هذه القيم كانت تُقرأ مباشرةً؛ صارت هنا مصدرًا واحدًا يظهر ويُدقَّق.',
  ),
  SettingGroups.subscriptions: _GroupMeta(
    'الاشتراكات',
    Icons.card_membership_outlined,
    AppColors.violet,
    'تحكم سلوك التغطية والسقوف والدفعات.',
  ),
  SettingGroups.processing: _GroupMeta(
    'المصنعية',
    Icons.local_laundry_service_outlined,
    AppColors.info,
    'تتبّع الغسيل من الاستلام للتسليم: المخطط · العامل · المهلة · الملصقات.',
  ),
  SettingGroups.labor: _GroupMeta(
    'مصنعية العمال',
    Icons.engineering_outlined,
    AppColors.success,
    'أجر القطعة وحوافز الإنتاج وتقرير الإنتاجية.',
  ),
  SettingGroups.pos: _GroupMeta(
    'نقطة البيع',
    Icons.point_of_sale_outlined,
    AppColors.primary,
    'سلوك شاشة الكاشير: الطباعة التلقائية · التأكيد · طريقة الدفع الافتراضية.',
  ),
  SettingGroups.customers: _GroupMeta(
    'الزبائن',
    Icons.people_outline,
    AppColors.secondary,
    'سياسات تسجيل الزبون الافتراضية.',
  ),
  SettingGroups.retention: _GroupMeta(
    'الاحتفاظ بالبيانات',
    Icons.auto_delete_outlined,
    AppColors.warning,
    'تنبيه: التقارير السنوية تعتمد على الفواتير المحفوظة. لا تُقلّل المدة '
        'ولا تُفعّل الحذف دون أخذ نسخة احتياطية.',
  ),
  SettingGroups.loyalty: _GroupMeta(
    'نقاط الولاء',
    Icons.stars_outlined,
    AppColors.violet,
    'التعطيل يوقف احتساب النقاط وترقيات الشرائح تمامًا عند إصدار الفواتير.',
  ),
  SettingGroups.tax: _GroupMeta(
    'الضريبة',
    Icons.percent,
    AppColors.indigo,
    'النسبة تُخزَّن وتُضبط من هنا، ولم تُضَف بعد إلى حساب الفاتورة.',
  ),
  SettingGroups.license: _GroupMeta(
    'خيارات الترخيص',
    Icons.verified_user_outlined,
    AppColors.violet,
    'القيم تسري فورًا على فحص صلاحية النظام أثناء العمل.',
  ),
};
