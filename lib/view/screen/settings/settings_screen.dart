import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/settings/settings_controller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/screen/settings/settings_sections.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// **فهرس الإعدادات** — صفحة البداية: مدخل لكل جزء، وكل مدخل صفحة مستقلّة.
///
/// ## لماذا فهرس لا صفحة طويلة؟
/// كانت الإعدادات صفحة واحدة تتراكم فيها الأقسام (معلومات النشاط · النسخ
/// الاحتياطي · الترخيص · الخصومات · المظهر · المعاينة · الطابعة · ثم 14
/// مجموعة خيارات) — فيضيع المستخدم في تمرير طويل. صارت الآن أربع بطاقات
/// مرتّبة بحسب الاستخدام، وكل مدخل ينقل إلى صفحته في `settings_pages.dart`.
///
/// ## البطاقات
///   • **النشاط والواجهة** — معلومات النشاط · المظهر.
///   • **الفواتير والطباعة** — الفواتير والترقيم · الطباعة وإخراج الفاتورة.
///   • **الحسابات والتشغيل** — الذمم والاشتراكات · العمليات والمصنعية · الضريبة.
///   • **النظام والصيانة** — الاحتفاظ بالبيانات · الترخيص · النسخ الاحتياطي ·
///     الخصومات · حول النظام.
///
/// ## الصلاحيات
/// المدخلات الحسّاسة تُخفى كما كانت تُخفى أقسامها: الترخيص والنسخ الاحتياطي
/// لمدير النظام، والخصومات للإدارة. ومدخل لا يظهر لأحد يُسقط بطاقته إن خلت.
///
/// ## ملاحظة عن البحث
/// مربّع البحث انتقل إلى **كل صفحة تعرض خيارات** (لا هنا): الفهرس صغير وواضح
/// فلا يحتاج بحثًا، والبحث في صفحة فرعية أدقّ وأسرع.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    if (controller.settings.isEmpty) controller.loadSettings();

    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: Scaffold(
        appBar: CustomAppbar(
          title: tr('الإعدادات'),
          subtitle: tr('إعدادات النظام والنشاط التجاري'),
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.settings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // مدخلات «النظام والصيانة» شرطية الصلاحية — تُبنى قبل القائمة كي
          // لا تُعرض بطاقة فارغة إن خلت من أي مدخل مرئي.
          final systemTiles = <Widget>[
            SettingTile(
              icon: Icons.auto_delete_outlined,
              iconColor: AppColors.warning,
              title: tr('الاحتفاظ بالبيانات'),
              subtitle: tr('مدة الاحتفاظ بالفواتير والحذف التلقائي'),
              onTap: () => Get.toNamed(AppRoute.settingsRetention),
            ),
            if (PermissionService.can(PermissionKeys.settingsManage))
              SettingTile(
                icon: Icons.verified_user_outlined,
                iconColor: AppColors.violet,
                title: tr('ترخيص النظام'),
                subtitle: tr('حالة الاشتراك · تاريخ الانتهاء · سجل التغييرات'),
                onTap: () => Get.toNamed(AppRoute.settingsLicense),
              ),
            if (PermissionService.can(PermissionKeys.backupPerform))
              SettingTile(
                icon: Icons.backup_outlined,
                iconColor: AppColors.success,
                title: tr('النسخ الاحتياطي'),
                subtitle: tr('إنشاء نسخة · قائمة النسخ · الاستعادة'),
                onTap: () => Get.toNamed(AppRoute.settingsBackup),
              ),
            if (PermissionService.can(PermissionKeys.discountManage))
              SettingTile(
                icon: Icons.local_offer_outlined,
                iconColor: AppColors.secondary,
                title: tr('الخصومات'),
                subtitle: tr('أكواد الخصم: نسبة أو مبلغ · سريان · حدّ استخدام'),
                onTap: () => Get.toNamed(AppRoute.discounts),
              ),
            SettingTile(
              icon: Icons.info_outline,
              iconColor: AppColors.textSecondary,
              title: tr('حول النظام'),
              subtitle: tr('الإصدار ومعلومات المطوّر'),
              onTap: () => Get.toNamed(AppRoute.settingsAbout),
            ),
          ];

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              FadeInUp(
                child: _hubCard(
                  title: tr('النشاط والواجهة'),
                  icon: Icons.storefront_outlined,
                  color: AppColors.primary,
                  tiles: [
                    SettingTile(
                      icon: Icons.business_outlined,
                      iconColor: AppColors.primary,
                      title: tr('معلومات النشاط التجاري'),
                      subtitle:
                          tr('الاسم · الهاتف · العنوان · الرقم الضريبي · السجل التجاري'),
                      onTap: () => Get.toNamed(AppRoute.settingsBusiness),
                    ),
                    SettingTile(
                      icon: Icons.brush_outlined,
                      iconColor: AppColors.secondary,
                      title: tr('المظهر'),
                      subtitle: tr('حجم الخط في كل الشاشات'),
                      onTap: () => Get.toNamed(AppRoute.settingsAppearance),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FadeInUp(
                delayMs: 80,
                child: _hubCard(
                  title: tr('الفواتير والطباعة'),
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.secondary,
                  tiles: [
                    SettingTile(
                      icon: Icons.receipt_outlined,
                      iconColor: AppColors.secondary,
                      title: tr('الفواتير والترقيم'),
                      subtitle: tr('معاينة الفاتورة · الترقيم · ما يظهر عليها'),
                      onTap: () => Get.toNamed(AppRoute.settingsInvoice),
                    ),
                    SettingTile(
                      icon: Icons.print_outlined,
                      iconColor: AppColors.slate,
                      title: tr('الطباعة وإخراج الفاتورة'),
                      subtitle:
                          tr('الطابعة الافتراضية · الطباعة عند البيع · حفظ PDF ومجلده'),
                      onTap: () => Get.toNamed(AppRoute.settingsPrinting),
                    ),
                    if (PermissionService.can(PermissionKeys.settingsManage))
                      SettingTile(
                        icon: Icons.design_services_outlined,
                        iconColor: AppColors.violet,
                        title: tr('قوالب الطباعة'),
                        subtitle: tr(
                          'تصميم الفاتورة وكشف الحساب — كل عنصر: تفعيل ونصّ',
                        ),
                        onTap: () => Get.toNamed(AppRoute.settingsDocTemplate),
                      ),
                    if (PermissionService.can(PermissionKeys.settingsManage))
                      SettingTile(
                        icon: Icons.local_laundry_service_outlined,
                        iconColor: AppColors.success,
                        title: tr('قالب ورقة المغسلة'),
                        subtitle: tr(
                          'نسخة المحل — كل عنصر: تفعيل ونصّ وحجم ووزن',
                        ),
                        onTap: () => Get.toNamed(
                          AppRoute.settingsDocTemplate,
                          arguments: DocKind.laundrySlip,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FadeInUp(
                delayMs: 160,
                child: _hubCard(
                  title: tr('الحسابات والتشغيل'),
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.info,
                  tiles: [
                    SettingTile(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.info,
                      title: tr('الذمم والاشتراكات'),
                      subtitle:
                          tr('الذمم والائتمان · الاشتراكات · الزبائن · نقاط الولاء'),
                      onTap: () => Get.toNamed(AppRoute.settingsAccounts),
                    ),
                    SettingTile(
                      icon: Icons.local_laundry_service_outlined,
                      iconColor: AppColors.success,
                      title: tr('العمليات والمصنعية'),
                      subtitle: tr('تتبّع الغسيل · مصنعية العمال · نقطة البيع'),
                      onTap: () => Get.toNamed(AppRoute.settingsOperations),
                    ),
                    SettingTile(
                      icon: Icons.percent,
                      iconColor: AppColors.indigo,
                      title: tr('الضريبة'),
                      subtitle: tr('ضريبة القيمة المضافة · ضريبة المدخلات'),
                      onTap: () => Get.toNamed(AppRoute.settingsTax),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FadeInUp(
                delayMs: 240,
                child: _hubCard(
                  title: tr('النظام والصيانة'),
                  icon: Icons.settings_suggest_outlined,
                  color: AppColors.violet,
                  tiles: systemTiles,
                ),
              ),
              const SizedBox(height: 20),
              // حقوق المطوّر — نهاية فهرس الإعدادات (وتظهر أيضًا في «حول النظام»).
              const FadeInUp(
                delayMs: 300,
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

  /// بطاقة فهرس: عنوان قسم + مدخلاته مفصولة بخطوط رفيعة.
  Widget _hubCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> tiles,
  }) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: tr(title), icon: icon, color: color),
          const SizedBox(height: 4),
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            tiles[i],
          ],
        ],
      ),
    );
  }
}
