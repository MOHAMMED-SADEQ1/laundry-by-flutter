import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// شاشة ترحيب لإدخال معلومات النشاط التجاري عند أول تشغيل للنظام
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final db = SqlDB();
      await db.updateSetting('business_name', _nameCtrl.text.trim());
      await db.updateSetting('business_phone', _phoneCtrl.text.trim());
      await db.updateSetting('business_address', _addressCtrl.text.trim());
      await db.updateSetting('business_location', _locationCtrl.text.trim());

      // تحديث الخدمة المركزية
      await BusinessInfoService.instance.load();
      await BusinessInfoService.instance.completeOnboarding();

      // الانتقال لشاشة تسجيل الدخول
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar(
        tr('خطأ'),
        trf('حدث خطأ أثناء الحفظ: {0}', ['$e']),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // الشعار
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.local_laundry_service,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr('مرحباً بك في نظام إدارة المغاسل'),
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontFamily: 'cairo',
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('أدخل معلومات نشاطك التجاري لتبدأ'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontFamily: 'cairo',
                          ),
                        ),
                        const SizedBox(height: 32),

                        // البطاقة
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // اسم النشاط
                              TextFormField(
                                controller: _nameCtrl,
                                textDirection: appTextDirection,
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  labelText: tr('اسم النشاط التجاري'),
                                  hintText: tr('مثال: مغاسل النظارة'),
                                  prefixIcon:
                                      const Icon(Icons.storefront_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return tr('أدخل اسم النشاط');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // رقم الهاتف
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                textDirection: L10n.isRtl
                                    ? appTextDirection
                                    : TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  labelText: tr('رقم الهاتف'),
                                  hintText: tr('مثال: 05XXXXXXXX'),
                                  prefixIcon:
                                      const Icon(Icons.phone_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return tr('أدخل رقم الهاتف');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // العنوان
                              TextFormField(
                                controller: _addressCtrl,
                                textDirection: L10n.isRtl
                                    ? appTextDirection
                                    : TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  labelText: tr('العنوان'),
                                  hintText:
                                      tr('مثال: الرياض - حي اشبيليا'),
                                  prefixIcon:
                                      const Icon(Icons.location_on_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return tr('أدخل العنوان');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // الموقع (Google Maps)
                              TextFormField(
                                controller: _locationCtrl,
                                textDirection: L10n.isRtl
                                    ? appTextDirection
                                    : TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      tr('رابط الموقع على خرائط جوجل'),
                                  hintText: tr(
                                    'اختياري — الصق رابط Google Maps',
                                  ),
                                  prefixIcon:
                                      const Icon(Icons.map_outlined),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // زر الحفظ
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: _saving ? null : _save,
                                  child: _saving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(tr('بدء الاستخدام')),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('يمكنك تعديل هذه المعلومات لاحقاً من الإعدادات'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontFamily: 'cairo',
                          ),
                        ),
                        // حقوق المطوّر — أسفل شاشة إدخال اسم النشاط لأول مرة
                        const SizedBox(height: 10),
                        const DeveloperCredit(onDark: true, fontSize: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
