import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/license/system_license_service.dart';

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
      if (!ok) _error = 'بيانات مدير النظام غير صحيحة';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 30),
      helpText: 'اختر تاريخ انتهاء الاشتراك',
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
      'تم التجديد',
      'أصبح اشتراك النظام سارٍ حتى '
          '${SystemLicenseController.formatDate(_newDate)}',
      backgroundColor: AppColors.success,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.key_outlined, color: AppColors.violet),
            SizedBox(width: 8),
            Text(
              'تجديد اشتراك النظام',
              style: TextStyle(
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
                    ? 'اختر تاريخ انتهاء الاشتراك الجديد.'
                    : 'أدخل بيانات مدير النظام (admin) للتجديد.',
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
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  enabled: !_busy,
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _verify(),
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: Icon(Icons.lock_outline),
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
                          'ينتهي في '
                          '${SystemLicenseController.formatDate(_newDate)}',
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
                        child: const Text(
                          'تغيير',
                          style: TextStyle(fontFamily: 'cairo'),
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
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'cairo'),
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
              _verified ? 'تجديد وتفعيل' : 'تحقق من الهوية',
              style: const TextStyle(fontFamily: 'cairo'),
            ),
          ),
        ],
      ),
    );
  }
}
