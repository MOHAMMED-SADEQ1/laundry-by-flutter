import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// يفتح حوار تجديد الترخيص. يُعيد `true` إن تم التجديد فعلًا.
///
/// **خطوتان مقصودتان:** التحقق من هوية **admin نشِط** أولًا، ثم اختيار
/// التاريخ. فلا يُتاح تغيير تاريخ الانتهاء إلا لمن يملك بيانات مدير النظام،
/// ويبقى مسار التجديد مفتوحًا حتى والنظام مقفل (وهو شرط عملية التجديد).
Future<bool?> showLicenseRenewDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _LicenseRenewDialog(),
  );
}

class _LicenseRenewDialog extends StatefulWidget {
  const _LicenseRenewDialog();

  @override
  State<_LicenseRenewDialog> createState() => _LicenseRenewDialogState();
}

class _LicenseRenewDialogState extends State<_LicenseRenewDialog> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _verified = false;
  bool _busy = false;
  String? _error;

  /// التاريخ الجديد — افتراضيًا سنة من اليوم.
  DateTime _newDate = SystemLicenseController.plainDate(
    DateTime.now().add(const Duration(days: 365)),
  );

  SystemLicenseController get _license => Get.find<SystemLicenseController>();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _license.verifyAdminCredentials(
      _usernameCtrl.text,
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verified = ok;
      if (!ok) _error = tr('بيانات مدير النظام غير صحيحة');
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 30),
      helpText: tr('اختر تاريخ انتهاء الاشتراك'),
    );
    if (picked != null && mounted) {
      setState(() => _newDate = SystemLicenseController.plainDate(picked));
    }
  }

  Future<void> _renew() async {
    setState(() => _busy = true);
    await _license.setExpiry(_newDate);
    if (!mounted) return;
    Get.back(result: true);
    Get.snackbar(
      tr('تم التجديد'),
      trf('أصبح اشتراك النظام سارٍ حتى {0}', [
        SystemLicenseController.formatDate(_newDate),
      ]),
      backgroundColor: AppColors.success,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.key_outlined, color: AppColors.violet),
            const SizedBox(width: 8),
            Text(
              tr('تجديد اشتراك النظام'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _verified
                    ? tr('اختر تاريخ انتهاء الاشتراك الجديد.')
                    : tr('أدخل بيانات مدير النظام (admin) للتجديد.'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (!_verified) ...[
                TextField(
                  controller: _usernameCtrl,
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr('اسم المستخدم'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  enabled: !_busy,
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _verify(),
                  decoration: InputDecoration(
                    labelText: tr('كلمة المرور'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trf('ينتهي في {0}', [
                            SystemLicenseController.formatDate(_newDate),
                          ]),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _pickDate,
                        child: Text(
                          tr('تغيير'),
                          style: const TextStyle(fontFamily: 'cairo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Get.back(result: false),
            child: Text(
              tr('إلغاء'),
              style: const TextStyle(fontFamily: 'cairo'),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : (_verified ? _renew : _verify),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_verified ? Icons.check_circle_outline : Icons.lock_open),
            label: Text(
              _verified ? tr('تجديد وتفعيل') : tr('تحقق من الهوية'),
              style: const TextStyle(fontFamily: 'cairo'),
            ),
          ),
        ],
      ),
    );
  }
}
