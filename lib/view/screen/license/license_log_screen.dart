import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/config/constants.dart';
import 'package:laundry/controller/license/license_log_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/license/license_event.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// شاشة سجل الترخيص: الحالة الحالية + من غيّر التاريخ ومتى وماذا كان قبله.
///
/// **لماذا:** تاريخ الانتهاء قابل للتغيير من مسارين (بذر من الكود، وتجديد
/// يدوي)، وسجل التدقيق يحفظ الأثر. بلا هذه الشاشة يبقى السؤال «من مدّد
/// الاشتراك ومتى وإلى أي تاريخ؟» بلا جواب داخل النظام.
class LicenseLogScreen extends StatefulWidget {
  const LicenseLogScreen({super.key});

  @override
  State<LicenseLogScreen> createState() => _LicenseLogScreenState();
}

class _LicenseLogScreenState extends State<LicenseLogScreen> {
  late final LicenseLogController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(LicenseLogController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: tr('سجل الترخيص'),
        subtitle: tr('حالة الاشتراك وتغييرات تاريخ الانتهاء'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (c.isLoading.value && c.events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
              children: [
                FadeInUp(child: _statusCard()),
                const SizedBox(height: 16),
                FadeInUp(delayMs: 80, child: _logHeader()),
                const SizedBox(height: 8),
                if (c.events.isEmpty)
                  _empty()
                else
                  ...c.events.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _eventTile(e),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── بطاقة الحالة الحالية ───
  Widget _statusCard() {
    if (!Get.isRegistered<SystemLicenseController>()) {
      return const SizedBox.shrink();
    }
    final license = Get.find<SystemLicenseController>();
    return Obx(() {
      final expiry = license.expiryDate;
      final remaining = license.daysRemaining;
      final unlimited = license.isUnlimited;
      final color = license.isLocked
          ? AppColors.danger
          : license.isExpiringSoon
          ? AppColors.warning
          : unlimited
          ? AppColors.textMuted
          : AppColors.success;

      // مصدر التاريخ المعروض: مطابق للكود، أم مُعيَّن يدويًا، أم غير محدود.
      final codeDefault = AppConstants.defaultLicenseExpiryDate.trim();
      final currentRaw = expiry == null
          ? ''
          : SystemLicenseController.formatDate(expiry);
      final source = unlimited
          ? tr('غير محدود')
          : (codeDefault.isNotEmpty && currentRaw == codeDefault)
          ? tr('مطابق للتاريخ المضمَّن في الكود')
          : tr('مُعيَّن يدويًا من داخل النظام');

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: unlimited ? AppColors.inkGradient : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('حالة الترخيص'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13.5,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    license.statusLabel,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  unlimited
                      ? '—'
                      : (remaining == null || remaining < 0
                            ? '0'
                            : '$remaining'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    unlimited ? tr('بلا حد') : tr('يومًا متبقيًا'),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12.5,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              expiry == null
                  ? tr('لا يوجد تاريخ انتهاء')
                  : trf('تاريخ الانتهاء: {0}', [
                      SystemLicenseController.formatDate(expiry),
                    ]),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              source,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── ترويسة السجل + عدّادات ───
  Widget _logHeader() {
    return Row(
      children: [
        const Icon(Icons.history, size: 18, color: AppColors.violet),
        const SizedBox(width: 7),
        Text(
          tr('سجل التغييرات'),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (c.seedCount > 0)
          _chip(trf('{0} تطبيق كود', ['${c.seedCount}']), AppColors.info),
        if (c.seedCount > 0 && c.manualCount > 0) const SizedBox(width: 6),
        if (c.manualCount > 0)
          _chip(
            trf('{0} تجديد', ['${c.manualCount}']),
            AppColors.success,
          ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 52,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            tr('لا توجد تغييرات مسجّلة على الترخيص'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              tr(
                'يُسجَّل هنا كل تطبيق لتاريخ الكود وكل تجديد أو تعديل يدوي، باسم من نفّذه ووقته.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                height: 1.6,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventTile(LicenseEvent e) {
    final color = e.isSeed ? AppColors.info : AppColors.success;
    final timeLabel = e.timestamp == null
        ? ''
        : DateFormat('yyyy-MM-dd  HH:mm').format(e.timestamp!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              e.isSeed ? Icons.download_done_outlined : Icons.edit_calendar,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.actionLabel,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (e.hasParseError)
                  Text(
                    tr('تعذّر قراءة تفاصيل الحدث'),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11,
                      color: AppColors.warning,
                    ),
                  )
                else
                  _changeLine(e),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _actorLabel(e),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// سطر «من → إلى».
  Widget _changeLine(LicenseEvent e) {
    final from = e.oldExpiry.isEmpty ? tr('غير محدود') : e.oldExpiry;
    final to = e.newExpiry.isEmpty ? tr('غير محدود') : e.newExpiry;
    return Row(
      children: [
        Flexible(
          child: Text(
            from,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 11,
            color: AppColors.textMuted,
          ),
        ),
        Flexible(
          child: Text(
            to,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: e.isSeed ? AppColors.info : AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  /// من نفّذ التغيير. البذر يقع غالبًا **قبل** تسجيل الدخول فلا مستخدم له.
  String _actorLabel(LicenseEvent e) {
    if (e.userName.trim().isNotEmpty) return e.userName;
    return e.isSeed
        ? tr('تلقائي — عند تشغيل النظام')
        : tr('غير معروف');
  }
}
