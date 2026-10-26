import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/auth/auth_controller.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/screen/shifts_history_screen.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';

/// قائمة جانبية عصرية بتدرجات وأقسام منظمة
class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ShiftController shiftController = Get.find<ShiftController>();
    final AuthController authController = Get.find<AuthController>();

    return Drawer(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ─── الرأس المتدرج ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
            decoration: const BoxDecoration(
              gradient: AppColors.darkGradient,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BusinessInfoService.instance.name.isNotEmpty
                            ? BusinessInfoService.instance.name
                            : tr('نظام المغاسل'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final user = authController.username.value;
                        return Text(
                          user.isEmpty
                              ? tr('نظام إدارة المغاسل')
                              : trf('مرحباً، {0}', [user]),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontFamily: 'cairo',
                            fontSize: 12,
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      // شارة الدور
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Color(PermissionService.roleColor)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(PermissionService.roleColor)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          PermissionService.roleLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: tr('إغلاق القائمة'),
                ),
              ],
            ),
          ),

          // ─── حالة الوردية ───
          if (PermissionService.can(PermissionKeys.shiftOpen))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Obx(() {
                final active = shiftController.isShiftActive.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient:
                        active
                            ? AppColors.successGradient
                            : AppColors.amberGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppColors.softShadow(blur: 10, y: 3),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active ? Icons.lock_clock : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                active
                                    ? 'وردية مفتوحة الآن'
                                    : 'لا توجد وردية نشطة',
                              ),
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (active)
                              Text(
                                trf('منذ: {0}', [
                                  shiftController.shiftStartTime.value,
                                ]),
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Get.back();
                            active
                                ? shiftController.closeShift()
                                : shiftController.startShift();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Text(
                              tr(active ? 'إغلاق' : 'فتح وردية'),
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),

          // ─── القائمة ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              children: [
                // ─── الإدارة ───
                if (PermissionService.can(PermissionKeys.dashboardView) ||
                    PermissionService.can(PermissionKeys.categoryManage))
                  ...[
                    _SectionLabel(tr('الإدارة')),
                    if (PermissionService.can(PermissionKeys.dashboardView))
                      _DrawerItem(
                        icon: Icons.dashboard_outlined,
                        title: tr('لوحة التحكم'),
                        color: AppColors.primary,
                        route: '/dashboard',
                      ),
                    if (PermissionService.can(PermissionKeys.categoryManage))
                      _DrawerItem(
                        icon: Icons.add_card_outlined,
                        title: tr('إضافة لبس'),
                        color: AppColors.success,
                        route: '/addcategory',
                      ),
                    if (PermissionService.can(PermissionKeys.categoryManage))
                      _DrawerItem(
                        icon: Icons.edit_outlined,
                        title: tr('حذف وتعديل لبس'),
                        color: AppColors.warning,
                        route: '/category',
                      ),
                    const SizedBox(height: 8),
                  ],

                // ─── العمليات ───
                _SectionLabel(tr('العمليات')),
                if (PermissionService.can(PermissionKeys.customerManage))
                  _DrawerItem(
                    icon: Icons.contact_phone_outlined,
                    title: tr('الزبائن'),
                    color: AppColors.secondary,
                    route: '/customernumber',
                  ),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  title: tr('الفواتير'),
                  color: AppColors.info,
                  route: '/invoices',
                ),
                if (PermissionService.can(PermissionKeys.processingUpdate))
                  _DrawerItem(
                    icon: Icons.local_laundry_service_outlined,
                    title: tr('لوحة المصنعية'),
                    color: AppColors.violet,
                    route: '/processing',
                  ),
                if (PermissionService.can(PermissionKeys.subscriptionManage))
                  _DrawerItem(
                    icon: Icons.card_membership,
                    title: tr('الاشتراكات الشهرية'),
                    color: AppColors.warning,
                    route: '/subscriptions',
                  ),
                if (PermissionService.can(PermissionKeys.reportsView))
                  _DrawerItem(
                    icon: Icons.insights_outlined,
                    title: tr('لوحة الاشتراكات'),
                    color: AppColors.violet,
                    route: '/subscription-dashboard',
                  ),
                const SizedBox(height: 8),

                // ─── التقارير ───
                if (PermissionService.can(PermissionKeys.reportsView)) ...[
                  _SectionLabel(tr('التقارير')),
                  _DrawerItem(
                    icon: Icons.money_rounded,
                    title: tr('صندوق اليوم'),
                    color: AppColors.success,
                    route: '/daily-cash',
                  ),
                  if (PermissionService.can(PermissionKeys.expenseManage))
                    _DrawerItem(
                      icon: Icons.payments_outlined,
                      title: tr('المصروفات'),
                      color: AppColors.danger,
                      route: '/expenses',
                    ),
                  _DrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: tr('التقارير'),
                    color: AppColors.info,
                    route: '/reports',
                  ),
                  if (PermissionService.can(PermissionKeys.shiftOpen))
                    _DrawerItem(
                      icon: Icons.history_edu_outlined,
                      title: tr('سجل الورديات'),
                      color: AppColors.indigo,
                      onTap: () {
                        Get.back();
                        Get.to(() => const ShiftsHistoryScreen());
                      },
                    ),
                  const SizedBox(height: 8),
                ],

                // ─── النظام ───
                _SectionLabel(tr('النظام')),
                _DrawerItem(
                  icon: Icons.person_outline,
                  title: tr('الملف الشخصي'),
                  color: AppColors.primary,
                  route: '/profile',
                ),
                if (PermissionService.can(PermissionKeys.usersManage))
                  _DrawerItem(
                    icon: Icons.people_outlined,
                    title: tr('إدارة المستخدمين'),
                    color: AppColors.violet,
                    route: '/users',
                  ),
                // 🛡️ الأدوار والصلاحيات: مدخل مستقل عن «إدارة المستخدمين»
                // لأن من يرتّب الصلاحيات ليس بالضرورة من يُنشئ الحسابات.
                if (PermissionService.can(PermissionKeys.rolesManage))
                  _DrawerItem(
                    icon: Icons.shield_outlined,
                    title: tr('الأدوار والصلاحيات'),
                    color: AppColors.indigo,
                    route: '/roles',
                  ),
                if (PermissionService.can(PermissionKeys.settingsManage))
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: tr('الإعدادات'),
                    color: AppColors.slate,
                    route: '/settings',
                  ),
                // سجل التدقيق: يعرض ما سجّله النظام فعلًا من تجاوزات
                // وحذف وإلغاءات — كان يُكتب في 24 موضعًا ولا يُقرأ في أي شاشة.
                if (PermissionService.can(PermissionKeys.settingsManage))
                  _DrawerItem(
                    icon: Icons.fact_check_outlined,
                    title: tr('سجل التدقيق'),
                    color: AppColors.warning,
                    route: '/audit-log',
                  ),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  title: tr('تسجيل الخروج'),
                  color: AppColors.danger,
                  onTap: () {
                    Get.back();
                    Get.defaultDialog(
                      title: tr('تسجيل الخروج'),
                      middleText: tr('هل أنت متأكد من تسجيل الخروج من النظام؟'),
                      textConfirm: tr('تسجيل الخروج'),
                      textCancel: tr('إلغاء'),
                      confirmTextColor: Colors.white,
                      buttonColor: AppColors.danger,
                      onConfirm: () {
                        Get.back();
                        authController.logout();
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // ─── المطور ───
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      trf('الإصدار {0}  •  ', [AppInfo.version]),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    InkWell(
                      onTap: showDeveloperDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          tr('مطوّر النظام'),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // حقوق المطوّر — أسفل القائمة الجانبية
                const DeveloperCredit(fontSize: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? route;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.color,
    this.route,
    this.onTap,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color:
              _hovered
                  ? widget.color.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 19),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.chevron_left,
            size: 18,
            color: AppColors.textMuted,
          ),
          onTap: () {
            Get.back();
            if (widget.onTap != null) {
              widget.onTap!();
            } else if (widget.route != null) {
              Get.toNamed(widget.route!);
            }
          },
        ),
      ),
    );
  }
}
