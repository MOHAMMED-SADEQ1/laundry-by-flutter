import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/users/roles_controller.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// شاشة الأدوار والصلاحيات.
///
/// **بنية الشاشة:** قائمة الأدوار أوّلًا (كل دور بطاقة تُوسَّع لتعرض صلاحياته
/// مجموعةً مجموعة). لماذا هذا الترتيب لا العكس؟ لأن السؤال الذي يُسأل دائمًا
/// هو «ماذا يستطيع **فلان** أن يفعل؟» — الأدوار هي نقطة الدخول الطبيعية،
/// والمجموعات هي تفصيلها.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late final RolesController controller;

  /// الأدوار المفتوحة حاليًا (لعرض صلاحياتها).
  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    controller = Get.put(RolesController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: tr('الأدوار والصلاحيات'),
        subtitle: trf(
          tr('{0} صلاحية موزَّعة على {1} مجموعات'),
          [
            '${PermissionCatalog.count}',
            '${PermissionGroups.ordered.length}',
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (controller.isLoading.value && controller.roles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _headerNote(),
              const SizedBox(height: 14),
              ...controller.roles.map(_roleCard),
              const SizedBox(height: 8),
              if (PermissionService.can(PermissionKeys.rolesManage))
                _addRoleButton(),
              const SizedBox(height: 20),
              _catalogSummary(),
            ],
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // الترويسة والتذييل
  // ══════════════════════════════════════════════════════════════════

  Widget _headerNote() {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                'لكل دور حزمة صلاحيات. أي تغيير هنا يسري فورًا على من يعمل بالدور، ويُسجَّل في سجل التدقيق.',
              ),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catalogSummary() {
    final grouped = PermissionCatalog.grouped;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('الكتالوج'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 10),
          ...grouped.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _groupColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr(PermissionGroups.labelOf(e.key)),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          )),
                    ),
                    Text('${e.value.length}',
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        )),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // بطاقة دور
  // ══════════════════════════════════════════════════════════════════

  Widget _roleCard(RoleRecord role) {
    final open = _expanded.contains(role.roleId);
    final canManage = PermissionService.can(PermissionKeys.rolesManage);
    final color = _groupColor(PermissionGroups.governance);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              if (open) {
                _expanded.remove(role.roleId);
              } else {
                _expanded.add(role.roleId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (role.isRoot ? color : AppColors.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      role.isRoot ? Icons.verified_user : Icons.groups,
                      color: role.isRoot ? color : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(role.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  )),
                            ),
                            if (role.isRoot) ...[
                              const SizedBox(width: 6),
                              _badge(tr('جذر'), color),
                            ] else if (role.isSystem)
                              ...[
                              const SizedBox(width: 6),
                              _badge(tr('نظامي'), const Color(0xFF6B7280)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trf('{0} صلاحية · {1} مستخدم', [
                            '${role.granted.length}',
                            '${role.usersCount}',
                          ]),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted),
                  if (canManage && !role.isRoot)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: AppColors.textMuted, size: 20),
                      onSelected: (v) => _roleMenu(v, role),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: ListTile(
                            leading: const Icon(Icons.edit, size: 18),
                            title: Text(tr('إعادة تسمية'),
                                style: const TextStyle(fontFamily: 'cairo')),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reset',
                          child: ListTile(
                            leading: const Icon(Icons.restart_alt, size: 18),
                            title: Text(tr('استعادة الافتراضي'),
                                style: const TextStyle(fontFamily: 'cairo')),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (!role.isSystem)
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              title: Text(tr('حذف الدور'),
                                  style: const TextStyle(
                                      fontFamily: 'cairo', color: Colors.red)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1),
            if (role.isRoot)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  trf(
                    'دور الجذر يملك كل صلاحيات الكتالوج ({0}) ولا يقبل التعديل — يضمن وجود سلطة عليا تُعيد ضبط النظام.',
                    ['${PermissionCatalog.count}'],
                  ),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              ...PermissionCatalog.grouped.entries
                  .map((e) => _groupSection(role, e.key, e.value)),
          ],
        ],
      ),
    );
  }

  Widget _groupSection(RoleRecord role, String group, List<PermissionItem> items) {
    final grantedInGroup =
        items.where((i) => role.granted.contains(i.key)).length;
    final all = grantedInGroup == items.length;
    final canManage = PermissionService.can(PermissionKeys.rolesManage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 2),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _groupColor(group),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  PermissionGroups.labelOf(group),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text('$grantedInGroup/${items.length}',
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  )),
              const SizedBox(width: 4),
              if (canManage)
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: all ? tr('سحب المجموعة') : tr('منح المجموعة'),
                  icon: Icon(
                    all ? Icons.remove_done : Icons.done_all,
                    color: all ? const Color(0xFFDC2626) : AppColors.primary,
                  ),
                  onPressed: () =>
                      controller.setGroup(role: role, group: group, allow: !all),
                ),
            ],
          ),
        ),
        ...items.map((item) => _permissionRow(role, item, canManage)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _permissionRow(RoleRecord role, PermissionItem item, bool canManage) {
    final on = role.granted.contains(item.key);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.displayLabel,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: on
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (item.isDestructive)
                      _riskChip(tr('حذف'), const Color(0xFFDC2626)),
                    if (item.touchesMoney)
                      _riskChip(tr('مالي'), const Color(0xFFD97706)),
                    if (item.isSecurity)
                      _riskChip(tr('أمني'), const Color(0xFF7C3AED)),
                  ],
                ),
                Text(
                  item.displayDescription,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Switch(
            value: on,
            activeThumbColor: AppColors.primary,
            onChanged: canManage
                ? (v) => controller.setPermission(
                      role: role,
                      key: item.key,
                      allow: v,
                    )
                : null,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // إجراءات
  // ══════════════════════════════════════════════════════════════════

  Future<void> _roleMenu(String value, RoleRecord role) async {
    switch (value) {
      case 'rename':
        _renameDialog(role);
        break;
      case 'reset':
        _confirmDialog(
          title: tr('استعادة الافتراضي'),
          message: trf(
            tr('ستُستبدل حزمة «{0}» بالحزمة الافتراضية ({1} صلاحية).'),
            [
              role.label,
              '${PermissionCatalog.defaultBundleOf(role.name)?.length ?? 0}',
            ],
          ),
          confirmLabel: tr('استعادة'),
          onConfirm: () => controller.resetToDefault(role),
        );
        break;
      case 'delete':
        _confirmDialog(
          title: tr('حذف الدور'),
          message: trf(
            tr('سيُحذف «{0}» بصلاحياته. لا يمكن التراجع.'),
            [role.label],
          ),
          confirmLabel: tr('حذف'),
          onConfirm: () => controller.deleteRole(role),
        );
        break;
    }
  }

  void _renameDialog(RoleRecord role) {
    final ctrl = TextEditingController(text: role.label);
    Get.defaultDialog(
      title: tr('إعادة تسمية الدور'),
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(fontFamily: 'cairo'),
          decoration: InputDecoration(
            labelText: tr('الاسم المعروض'),
            labelStyle: const TextStyle(fontFamily: 'cairo'),
            helperText: trf(
              tr('الاسم التقني «{0}» لا يتغيّر'),
              [role.name],
            ),
            helperStyle: const TextStyle(fontFamily: 'cairo', fontSize: 11),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      textConfirm: tr('حفظ'),
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () async {
        final ok =
            await controller.renameRole(role: role, label: ctrl.text.trim());
        if (ok) dismissOpenDialog();
      },
    );
  }

  Widget _addRoleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addRoleDialog,
        icon: const Icon(Icons.add, size: 20),
        label: Text(tr('دور جديد'),
            style: const TextStyle(
                fontFamily: 'cairo', fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _addRoleDialog() {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String base = '';
    final usage = <String, int>{};

    for (final r in controller.roles) {
      usage[r.name] = r.granted.length;
    }

    Get.defaultDialog(
      title: tr('دور جديد'),
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      content: StatefulBuilder(
        builder: (context, setLocal) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(fontFamily: 'cairo'),
                  decoration: InputDecoration(
                    labelText: tr('الاسم المعروض'),
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontFamily: 'cairo'),
                  decoration: InputDecoration(
                    labelText: tr('الاسم التقني (لاتيني)'),
                    hintText: tr('مثال: supervisor'),
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                // **قيمة الحرس `''` لا `null`.** بندٌ بـ`value: null` مع
                // `DropdownButtonFormField<String>` يُفعِّل تحقّق فلاتر
                // («بند واحد فقط يطابق القيمة») ويسقط في الوضع التنقيحي،
                // لأن `null` يجوز أن يُطابق «لا اختيار» و«بند بلا قيمة»
                // معًا. السلسلة الفارغة صريحة ولا تلتبس بمفتاح دور حقيقي
                // (مفاتيح الأدوار لا تكون فارغة أبدًا).
                DropdownButtonFormField<String>(
                  initialValue: base,
                  decoration: InputDecoration(
                    labelText: tr('نسخ صلاحيات (اختياري)'),
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.copy_all, size: 20),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(tr('بدون — ابدأ فارغًا'),
                          style: const TextStyle(
                              fontFamily: 'cairo', fontSize: 13)),
                    ),
                    ...usage.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            trf('{0} ({1} صلاحية)', [
                              PermissionCatalog.roleLabelOf(e.key),
                              '${e.value}',
                            ]),
                            style: const TextStyle(
                                fontFamily: 'cairo', fontSize: 13),
                          ),
                        )),
                  ],
                  // `v` يأتي `String?` من الودجة، و`base` من نوع `String` —
                  // فالإسناد المباشر يخالف نظام الأنواع. والقيمة `null`
                  // مستحيلة هنا عمليًا: القائمة تحتوي البند `''` صراحةً
                  // فيبقى للمستخدم دائمًا خيار غير فارغ، و`DropdownButton`
                  // لا يُرسل `null` إلا عند الضغط على «إفراغ» ولا زرّ له.
                  onChanged: (v) => setLocal(() => base = v ?? ''),
                ),
              ],
            ),
          ),
        ),
      ),
      textConfirm: tr('إنشاء'),
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () async {
        if (nameCtrl.text.trim().isEmpty || labelCtrl.text.trim().isEmpty) {
          Get.snackbar(tr('خطأ'), tr('أدخل الاسم المعروض والاسم التقني.'),
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        final initial = base.isEmpty
            ? const <String>[]
            : (controller.roles
                    .firstWhereOrNull((r) => r.name == base)
                    ?.granted
                    .toList() ??
                const <String>[]);
        final ok = await controller.createRole(
          name: nameCtrl.text,
          label: labelCtrl.text,
          initialKeys: initial,
        );
        if (ok) dismissOpenDialog();
      },
    );
  }

  void _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<bool> Function() onConfirm,
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 17,
        color: Colors.red,
      ),
      middleText: message,
      middleTextStyle: const TextStyle(
          fontFamily: 'cairo', fontSize: 13, height: 1.6),
      textConfirm: confirmLabel,
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        final ok = await onConfirm();
        if (ok) dismissOpenDialog();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // مساعدات عرض
  // ══════════════════════════════════════════════════════════════════

  static Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          )),
    );
  }

  static Widget _riskChip(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          )),
    );
  }

  static Color _groupColor(String group) {
    switch (group) {
      case PermissionGroups.invoices:
        return const Color(0xFF2563EB);
      case PermissionGroups.cash:
        return const Color(0xFF16A34A);
      case PermissionGroups.customers:
        return const Color(0xFFD97706);
      case PermissionGroups.books:
        return const Color(0xFF7C3AED);
      case PermissionGroups.processing:
        return const Color(0xFF0891B2);
      case PermissionGroups.system:
        return const Color(0xFFDB2777);
      case PermissionGroups.governance:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
