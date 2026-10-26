import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/controller/audit/audit_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/audit/audit_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// شاشة سجل التدقيق.
///
/// **لماذا:** `logAudit` كان يُستدعى في 24 موضعًا ولا يُقرأ في أي مكان.
/// هذه الشاشة تُظهر ما سُجِّل فعلًا: من تجاوز حدّ ائتمان، من منع تجاوز سقف
/// اشتراك، من ألغى اشتراكًا، ومن حذف فاتورة أو زبونًا.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late final AuditController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(AuditController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(title: tr('سجل التدقيق')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Column(
          children: [
            _filters(),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value && c.entries.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.entries.isEmpty) return _empty();
                return RefreshIndicator(
                  onRefresh: c.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    itemCount: c.entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _entryTile(c.entries[i]),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Obx(() {
      final current = c.range.value;
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AuditRange.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (_, i) {
                        final r = AuditRange.values[i];
                        final active = r == current;
                        return GestureDetector(
                          onTap: () => c.setRange(r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              r.label,
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: c.toggleSensitiveOnly,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.sensitiveOnly.value
                            ? AppColors.danger.withValues(alpha: 0.12)
                            : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.sensitiveOnly.value
                              ? AppColors.danger
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: c.sensitiveOnly.value
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tr('الحساسة فقط'),
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: c.sensitiveOnly.value
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: c.actionFilter.value.isEmpty
                            ? null
                            : c.actionFilter.value,
                        hint: Text(
                          tr('كل الأحداث'),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(tr('كل الأحداث')),
                          ),
                          ...c.availableActions.map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(
                                a.replaceAll('_', ' '),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => c.setActionFilter(v ?? ''),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 52,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            tr('لا توجد أحداث في هذه الفترة'),
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

  Widget _entryTile(AuditEntry e) {
    final color = e.isSensitive ? AppColors.danger : AppColors.info;
    final timeLabel = e.timestamp == null
        ? ''
        : DateFormat('yyyy-MM-dd  HH:mm').format(e.timestamp!);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: e.isSensitive
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  e.isSensitive ? Icons.warning_amber_rounded : Icons.info_outline,
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            e.tableLabel,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (e.recordId != null) ...[
                          const SizedBox(width: 5),
                          Text(
                            '#${e.recordId}',
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.userName.isEmpty ? tr('غير معروف') : e.userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
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

  void _showDetail(AuditEntry e) {
    Get.bottomSheet(
      Directionality(
        textDirection: appTextDirection,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  e.actionLabel,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _kv(tr('الحدث'), e.action),
                _kv(tr('الجدول'), e.tableLabel),
                if (e.recordId != null) _kv(tr('السجل'), '#${e.recordId}'),
                _kv(
                  tr('المستخدم'),
                  e.userName.isEmpty ? tr('غير معروف') : e.userName,
                ),
                if (e.timestamp != null)
                  _kv(
                    tr('التاريخ'),
                    DateFormat('yyyy-MM-dd  HH:mm:ss').format(e.timestamp!),
                  ),
                if (e.oldValues != null && e.oldValues!.trim().isNotEmpty)
                  _jsonBlock(tr('القيم السابقة'), e.oldValues!),
                if (e.newValues != null && e.newValues!.trim().isNotEmpty)
                  _jsonBlock(tr('القيم الجديدة'), e.newValues!),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            k,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
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

  Widget _jsonBlock(String title, String raw) {
    // نحاول تنسيقه مقروءًا، وإلا نعرضه كما هو
    String pretty = raw;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      pretty = raw;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
