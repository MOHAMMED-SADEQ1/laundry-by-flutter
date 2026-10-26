import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/backup/backup_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/database/backup_naming.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/database/backup_service.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// شاشة النسخ الاحتياطي: إنشاء باسم ومكان يختارهما المستخدم، واستعادة من
/// قائمة داخلية أو من أي ملف على الجهاز.
///
/// **الصيغة المعروضة للمستخدم صريحة:** ملف SQLite خام بامتداد `.db` — نسخة
/// مطابقة لقاعدة بيانات النظام تُفتح بأي أداة SQLite وتُستعاد مباشرة.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(BackupController());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: Scaffold(
        appBar: CustomAppbar(
          title: tr('النسخ الاحتياطي'),
          subtitle: tr('إنشاء واستعادة بيانات النظام'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFC), AppColors.background],
            ),
          ),
          child: PermissionService.can(PermissionKeys.backupPerform)
              ? _body()
              : _noPermission(),
        ),
      ),
    );
  }

  Widget _noPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 54, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              tr('النسخ الاحتياطي والاستعادة لمدير النظام (admin) وحده'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Obx(() {
      if (c.isLoading.value && c.backups.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: c.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
          children: [
            FadeInUp(child: _infoCard()),
            const SizedBox(height: 14),
            FadeInUp(delayMs: 70, child: _actionsCard()),
            const SizedBox(height: 14),
            FadeInUp(delayMs: 130, child: _listHeader()),
            const SizedBox(height: 8),
            if (c.backups.isEmpty)
              _empty()
            else
              ...c.backups.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _entryTile(e),
                ),
              ),
            const SizedBox(height: 14),
            FadeInUp(delayMs: 200, child: _warningCard()),
          ],
        ),
      );
    });
  }

  // ─── بطاقة المعلومات: الصيغة والمكان وآخر نسخة ───
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                tr('صيغة النسخة والمكان'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoLine(
            tr('الصيغة'),
            tr('ملف قاعدة بيانات SQLite خام بامتداد .db — يُفتح بأي أداة SQLite ويُستعاد مباشرة'),
          ),
          _infoLine(
            tr('الحفظ'),
            tr('كل نسخة تُحفظ مرتين: داخل التطبيق دائمًا، وفي المكان الذي تختاره من حوار الحفظ'),
          ),
          Obx(() {
            final dir = c.archiveDir.value;
            return dir.isEmpty
                ? const SizedBox.shrink()
                : _infoLine(tr('مجلد النسخ'), dir);
          }),
          Obx(() {
            final last = c.lastBackupLabel.value;
            return last.isEmpty
                ? const SizedBox.shrink()
                : _infoLine(tr('آخر نسخة'), last);
          }),
          Obx(() {
            final last = c.lastRestoreLabel.value;
            return last.isEmpty
                ? const SizedBox.shrink()
                : _infoLine(tr('آخر استعادة'), last);
          }),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                height: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── أزرار العمل ───
  Widget _actionsCard() {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Obx(() {
        final busy = c.isBusy.value;
        return Column(
          children: [
            _actionTile(
              icon: Icons.save_alt,
              color: AppColors.success,
              title: tr('إنشاء نسخة احتياطية'),
              subtitle: tr('تسميتها واختيار مكان حفظها'),
              enabled: !busy,
              onTap: _create,
            ),
            const Divider(height: 18),
            _actionTile(
              icon: Icons.folder_open,
              color: AppColors.warning,
              title: tr('استعادة من ملف على الجهاز'),
              subtitle:
                  tr('اختر أي ملف .db — مثل نسخة وصلت عبر واتساب'),
              enabled: !busy,
              onTap: _pickAndRestore,
            ),
            if (busy) ...const [
              SizedBox(height: 12),
              LinearProgressIndicator(),
            ],
          ],
        );
      }),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: enabled ? 0.12 : 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new,
                size: 13,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── القائمة ───
  Widget _listHeader() {
    return Row(
      children: [
        const Icon(Icons.storage_outlined, size: 18, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          tr('النسخ المحفوظة داخل التطبيق'),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Obx(
          () => Text(
            '${c.backups.length}',
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 50,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            tr('لا توجد نسخ محفوظة بعد'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(BackupEntry e) {
    final color = e.isSafety ? AppColors.violet : AppColors.primary;
    final when = e.modifiedAt == null
        ? ''
        : '${e.modifiedAt!.year}-${e.modifiedAt!.month.toString().padLeft(2, '0')}-${e.modifiedAt!.day.toString().padLeft(2, '0')}  ${e.modifiedAt!.hour.toString().padLeft(2, '0')}:${e.modifiedAt!.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  e.isSafety ? Icons.health_and_safety_outlined : Icons.archive_outlined,
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
                      e.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _chip(e.sizeLabel, AppColors.slate),
                        const SizedBox(width: 6),
                        _chip(e.kindLabel, color),
                        if (when.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              when,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: c.isBusy.value ? null : () => _restore(e.path),
                icon: const Icon(Icons.restore, size: 16),
                label: Text(
                  tr('استعادة'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: c.isBusy.value ? null : () => _delete(e),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppColors.danger,
                ),
                label: Text(
                  tr('حذف'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('قبل كل استعادة يأخذ النظام نسخة أمان تلقائية من بياناتك الحالية، ويرفض أي ملف ليس قاعدة بيانات سليمة. وبعد الاستعادة يلزم إعادة تشغيل النظام لتحميل البيانات الجديدة.'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                height: 1.7,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // العمليات
  // ──────────────────────────────────────────────

  Future<void> _create() async {
    final name = await _askName();
    if (name == null) return; // ألغى المستخدم

    final result = await c.createNew(name: name);
    if (!mounted || result == null) return;

    if (!result.success) {
      _snack(
        tr('فشل'),
        result.error ?? tr('سبب غير معروف'),
        AppColors.danger,
      );
      return;
    }
    if (result.cancelled) {
      _snack(
        tr('أُخذت النسخة'),
        trf(
          'أُلغي اختيار المكان، وحُفظت النسخة داخل التطبيق: {0}',
          [result.archivePath?.split(Platform.pathSeparator).last ?? ''],
        ),
        AppColors.warning,
      );
      return;
    }
    _snack(
      tr('تم إنشاء النسخة'),
      trf(
        'حُفظت في: {0} ({1})',
        [
          result.savedPath ?? result.archivePath,
          BackupNaming.formatSize(result.sizeBytes),
        ],
      ),
      AppColors.success,
    );
  }

  Future<void> _pickAndRestore() async {
    try {
      final path = await c.pickFile();
      if (path == null || path.isEmpty) return;
      if (!mounted) return;
      await _restore(path);
    } catch (e) {
      if (mounted) {
        _snack(tr('تعذّر اختيار الملف'), '$e', AppColors.danger);
      }
    }
  }

  /// **كل استثناء يُلتقط هنا**: لا يُسمح لخطأ في الاستعادة أن يفلت إلى إطار
  /// الواجهة، فذاك هو الفرق بين «فشلت العملية» و«انهار التطبيق».
  Future<void> _restore(String path) async {
    try {
      // فحص أولًا: نعرف ماذا سنستعيد، ونرفض غير الصالح بلا لمس أي بيانات.
      final info = await c.inspect(path);
      if (!mounted) return;
      if (!info.valid) {
        _snack(
          tr('ملف غير صالح'),
          info.reason ?? tr('الملف ليس نسخة احتياطية صالحة'),
          AppColors.danger,
        );
        return;
      }

      final ok = await _confirmRestore(info);
      if (ok != true || !mounted) return;

      final result = await c.restore(path);
      if (!mounted || result == null) return;

      if (!result.success) {
        _snack(
          tr('فشلت الاستعادة'),
          result.error ?? tr('سبب غير معروف'),
          result.rolledBack ? AppColors.warning : AppColors.danger,
        );
        return;
      }

      await _afterRestore(result);
    } catch (e) {
      if (mounted) {
        _snack(
          tr('فشلت الاستعادة'),
          trf('تعذّر إكمال العملية: {0}', ['$e']),
          AppColors.danger,
        );
      }
    }
  }

  Future<void> _delete(BackupEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            tr('حذف النسخة؟'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            e.name,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                tr('إلغاء'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: Text(
                tr('حذف'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final error = await c.delete(e.path);
    if (!mounted) return;
    if (error != null) {
      _snack(tr('تعذّر الحذف'), error, AppColors.warning);
    } else {
      _snack(
        tr('تم الحذف'),
        trf('حُذفت النسخة: {0}', [e.name]),
        AppColors.success,
      );
    }
  }

  // ─── حوار الاسم ───
  Future<String?> _askName() async {
    final ctrl = TextEditingController(
      text: BackupService.suggestedFileName(),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (_) => Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.drive_file_rename_outline,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                tr('اسم النسخة الاحتياطية'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15.5,
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
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('اسم الملف'),
                    suffixText: '.db',
                    helperText: tr(
                      tr('يمكنك كتابة أي اسم — وستُطبَّع الأحرف الممنوعة'),
                    ),
                    helperStyle: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('الصيغة: ملف SQLite خام بامتداد .db'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('بعد الموافقة سيُفتح حوار لاختيار مكان الحفظ؛ وتبقى نسخة داخل التطبيق في كل الأحوال.'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                tr('إلغاء'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Get.back(result: ctrl.text),
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: Text(
                tr('متابعة للحفظ'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
            ),
          ],
        ),
      ),
    );
    // اسم فارغ ⇒ الاسم الافتراضي بالتاريخ (تسمية حرّة بلا إلزام).
    if (result == null) return null;
    return result.trim().isEmpty ? BackupService.suggestedFileName() : result;
  }

  // ─── حوار تأكيد الاستعادة: يعرض ماذا سيُستعاد بالضبط ───
  Future<bool?> _confirmRestore(BackupFileInfo info) {
    final lastInvoice = info.lastInvoiceAt == null
        ? tr('غير معروف')
        : '${info.lastInvoiceAt!.year}-${info.lastInvoiceAt!.month.toString().padLeft(2, '0')}-${info.lastInvoiceAt!.day.toString().padLeft(2, '0')}';

    return showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.restore, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                tr('تأكيد الاستعادة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15.5,
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
                  tr('ستستبدل بيانات النظام الحالية ببيانات هذه النسخة:'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _row(tr('الملف'), info.fileName),
                _row(
                  tr('الحجم'),
                  BackupNaming.formatSize(info.sizeBytes),
                ),
                _row(tr('عدد الفواتير'), '${info.invoiceCount}'),
                _row(tr('عدد المستخدمين'), '${info.userCount}'),
                _row(tr('أحدث فاتورة'), lastInvoice),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.health_and_safety_outlined,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tr('سيأخذ النظام نسخة أمان من بياناتك الحالية قبل الاستبدال، ويعيدها تلقائيًا إن فشل الفحص.'),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                tr('إلغاء'),
                style: const TextStyle(fontFamily: 'cairo'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              icon: const Icon(Icons.check, size: 17, color: Colors.white),
              label: Text(
                tr('استعادة الآن'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ما بعد الاستعادة: إعادة التحميل إلزامية عمليًا ───
  Future<void> _afterRestore(RestoreResult result) async {
    // كاش الترخيص قد يحمل تاريخًا من القاعدة السابقة.
    if (Get.isRegistered<SystemLicenseController>()) {
      try {
        await Get.find<SystemLicenseController>().load();
      } catch (_) {}
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                tr('تمت الاستعادة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15.5,
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
                _row(
                  tr('الفواتير'),
                  '${result.restoredFrom?.invoiceCount ?? 0}',
                ),
                if (result.safetyPath != null)
                  _row(
                    tr('نسخة الأمان'),
                    result.safetyPath!.split(Platform.pathSeparator).last,
                  ),
                const SizedBox(height: 10),
                Text(
                  tr('قاعدة البيانات استُبدلت بالكامل، وكل الشاشات المفتوحة تحمل بيانات قديمة في الذاكرة. لذلك يُغلق التطبيق الآن — افتحه من جديد فتُقرأ البيانات المستعادة من أول لحظة.'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Get.back();
                _closeApp();
              },
              icon: const Icon(Icons.power_settings_new, size: 17),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              label: Text(
                tr('إغلاق التطبيق الآن'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// إغلاق التطبيق بعد الاستعادة — **لا إعادة تحميل لينة**.
  ///
  /// **لماذا:** الاستعادة تستبدل ملف القاعدة تحت عشرات المتحكّمات التي تحمل
  /// بيانات وقواعد مفتوحة في الذاكرة. إعادة بناء الشاشات فوق قاعدة مُستبدلة
  /// تُبقي هذه الحالة القديمة (وأي اتصال قديم) حيّة فتتسلسل الأخطاء ويتعطل
  /// النظام. الإغلاق يجعل أول قراءة للبيانات تأتي من عملية نظيفة تمامًا.
  Future<void> _closeApp() async {
    SystemChannels.platform.invokeMethod<void>('SystemNavigator.pop');
    // احتياط: إن لم يُغلق المنصة النافذة (سطح المكتب/iOS) فإغلاق صريح.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    exit(0);
  }

  void _snack(String title, String message, Color color) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }
}
