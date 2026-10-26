import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/users/users_controller.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';

/// ورقة سفلية لضبط **التجاوزات الفردية** لمستخدم بعينه.
///
/// **ثلاث حالات لكل صلاحية — لا حالتان.** اللحظة التي نعرض فيها مفتاحًا
/// ثنائيًا (منح/سحب) نكون قد أعطينا المستخدم **منحة ضمنية**: ما لا يُذكَر
/// في الجدول يبقى على حزمة الدور. لذلك كل صفّ يعرض أصلًا **الحالة الفعلية**
/// (موروثة من الدور أو متجاوزة)، ويُتاح ثلاث اختيارات:
/// - `موروث` (بلا صفّ في `permission_overrides`) — يتبع الدور.
/// - `ممنوح` (`allow = 1`) — يُضاف حتى لو منعه الدور.
/// - `مسحوب` (`allow = 0`) — يُسحب حتى لو منحه الدور.
///
/// لولا الحالة الثالثة لكان أي سحب يقتل الميراث فلا يعود بإرجاع الدور.
class UserPermissionsSheet extends StatefulWidget {
  final int userId;
  final String userName;
  final String role;
  final UsersController controller;

  const UserPermissionsSheet({
    super.key,
    required this.userId,
    required this.userName,
    required this.role,
    required this.controller,
  });

  @override
  State<UserPermissionsSheet> createState() => _UserPermissionsSheetState();
}

enum _OverrideState { inherit, allow, deny }

class _UserPermissionsSheetState extends State<UserPermissionsSheet> {
  bool _loading = true;

  /// حزمة الدور (الميراث) — تُحمّل مرة واحدة.
  Set<String> _roleKeys = <String>{};

  /// التجاوزات الحالية: المفتاح ⇒ الحالة.
  Map<String, _OverrideState> _overrides = <String, _OverrideState>{};

  /// التزم بـ`users.manage` — نفس المفتاح الذي يفحصه `setOverride` في
  /// المتحكّم. لو اختلف المفتاحان هنا وهناك لتاه المدير بين واجهة تُظهر
  /// أزرارًا تُرفَض عند الضغط.
  bool get _canManage => PermissionService.can(PermissionKeys.usersManage);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final roleId = await widget.controller.roleIdOf(widget.role);
      final roleKeys = roleId == null
          ? PermissionService.defaultKeysForRole(widget.role)
          : await widget.controller.grantedOf(roleId);
      final raw = await widget.controller.overridesOf(widget.userId);

      if (!mounted) return;
      setState(() {
        _roleKeys = roleKeys;
        _overrides = {
          for (final e in raw.entries)
            e.key:
                e.value ? _OverrideState.allow : _OverrideState.deny,
        };
        _loading = false;
      });
    } catch (e) {
      debugPrint('UserPermissionsSheet load: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// الحالة الفعلية: تجاوز إن وُجد، وإلا ميراث الدور.
  bool _effective(String key) {
    final ov = _overrides[key];
    if (ov == _OverrideState.allow) return true;
    if (ov == _OverrideState.deny) return false;
    return _roleKeys.contains(key);
  }

  Future<void> _set(String key, _OverrideState state) async {
    final previous = _overrides[key] ?? _OverrideState.inherit;

    // تحديث تفاؤلي: الشاشة تستجيب فورًا ثم تُصحَّح عند فشل الكتابة.
    setState(() {
      if (state == _OverrideState.inherit) {
        _overrides.remove(key);
      } else {
        _overrides[key] = state;
      }
    });

    final allow = state == _OverrideState.inherit
        ? null
        : (state == _OverrideState.allow);
    final ok = await widget.controller.setOverride(
      userId: widget.userId,
      key: key,
      allow: allow,
    );

    if (!ok && mounted) {
      setState(() {
        if (previous == _OverrideState.inherit) {
          _overrides.remove(key);
        } else {
          _overrides[key] = previous;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final overridesCount = _overrides.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        trf(
                          'الدور: {0} · {1} صلاحية موروثة{2}',
                          [
                            PermissionCatalog.roleLabelOf(widget.role),
                            '${_roleKeys.length}',
                            overridesCount > 0
                                ? trf(' · {0} تجاوز', ['$overridesCount'])
                                : '',
                          ],
                        ),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (overridesCount > 0)
                  TextButton(
                    onPressed: _loading ? null : _confirmClear,
                    child: Text(tr('مسح الكل'),
                        style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12,
                            color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _legend(tr('موروث'), AppColors.textMuted),
                const SizedBox(width: 12),
                _legend(tr('ممنوح'), const Color(0xFF16A34A)),
                const SizedBox(width: 12),
                _legend(tr('مسحوب'), const Color(0xFFDC2626)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                    children: [
                      for (final e in PermissionCatalog.grouped.entries) ...[
                        _groupHeader(e.key, e.value),
                        ...e.value.map((item) => _row(item)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 10.5,
                color: AppColors.textMuted)),
      ],
    );
  }

  Widget _groupHeader(String group, List<PermissionItem> items) {
    final inherited =
        items.where((i) => _effective(i.key)).length;
    final altered = items
        .where((i) => (_overrides[i.key] ?? _OverrideState.inherit) !=
            _OverrideState.inherit)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
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
          if (altered > 0)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(trf('{0} متجاوز', ['$altered']),
                  style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
          Text('$inherited/${items.length}',
              style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _row(PermissionItem item) {
    final state = _overrides[item.key] ?? _OverrideState.inherit;
    final effective = _effective(item.key);

    // لون الحالة: أخضر فعّال، رمادي موروث غير فعّال، أحمر مسحوب.
    final Color stateColor = state == _OverrideState.allow
        ? const Color(0xFF16A34A)
        : state == _OverrideState.deny
            ? const Color(0xFFDC2626)
            : (effective ? AppColors.textSecondary : AppColors.textMuted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: stateColor,
                  ),
                ),
              ),
              if (_canManage)
                _segmented(item, state)
              else
                Icon(
                  effective ? Icons.check_circle : Icons.remove_circle_outline,
                  size: 18,
                  color: effective
                      ? const Color(0xFF16A34A)
                      : AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// ثلاث حالات لكل صلاحية: موروث · ممنوح · مسحوب.
  Widget _segmented(PermissionItem item, _OverrideState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pick(item, _OverrideState.inherit, tr('موروث — يتبع الدور'),
            Icons.subdirectory_arrow_left, AppColors.textMuted),
        const SizedBox(width: 4),
        _pick(item, _OverrideState.allow, tr('ممنوح — فوق الدور'),
            Icons.check_circle_outline, const Color(0xFF16A34A)),
        const SizedBox(width: 4),
        _pick(item, _OverrideState.deny, tr('مسحوب — دون الدور'),
            Icons.block, const Color(0xFFDC2626)),
      ],
    );
  }

  Widget _pick(
    PermissionItem item,
    _OverrideState target,
    String tooltip,
    IconData icon,
    Color color,
  ) {
    final selected = (_overrides[item.key] ?? _OverrideState.inherit) == target;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _set(item.key, target),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? color : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  /// تأكيد مسح التجاوزات كلها.
  ///
  /// **لا نعتمد على القيمة المُعادة من الحوار.** لو اعتمدنا عليها لكان
  /// `null` (إغلاق بالسحب) و`false` (إلغاء) سواءً في نظر المتغيّر — وقد
  /// يُخطئ الفحص فيُعيد التحميل بلا سبب أو يُهمله بعد نجاح فعلًا. المصدر
  /// الوحيد الصادق هنا هو **نجاح الكتابة نفسها**، لذلك كل شيء يجري داخل
  /// `onConfirm`، والحوار لا يُعيد قيمة تُقرأ.
  Future<void> _confirmClear() async {
    Get.defaultDialog<void>(
      title: tr('مسح التجاوزات'),
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      middleText: trf(
        'سيُعاد «{0}» إلى حزمة دوره وحدها.',
        [widget.userName],
      ),
      middleTextStyle:
          const TextStyle(fontFamily: 'cairo', fontSize: 13, height: 1.6),
      textConfirm: tr('مسح'),
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFFDC2626),
      onConfirm: () async {
        final success = await widget.controller.clearOverrides(widget.userId);
        if (success) dismissOpenDialog();
        if (success && mounted) await _load();
      },
    );
  }
}
