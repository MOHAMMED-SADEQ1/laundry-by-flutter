// منتقي خطّ الطباعة — **بطاقات معاينة** لا قائمة منسدلة.
//
// لماذا؟ لأن اختيار الخطّ قرار بصري: قائمة «IBM Plex» و«المراعي» لا تقول
// للمستخدم شيئًا. هنا يرى كل خطّ **مكتوبًا بخطّه** بنصّ فاتورة حقيقي، ويرى
// وسماً يقول: أيّها يصلح للحراري وأيّها للورق.
//
// المصدر الوحيد للبيانات `PrintFonts` (منطق خالص)، والقيمة تُحفظ عبر
// `SettingsController.updateSetting` كأي إعداد آخر.
import 'package:flutter/material.dart';

import 'package:laundry/config/constants.dart';
import 'package:laundry/controller/settings/settings_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/pdf/print_font.dart';
import 'package:laundry/services/settings/app_settings_service.dart';

/// بطاقة «خطّ الطباعة» في صفحة الطباعة: تُظهر الخطّ الحالي وتفتح المنتقي.
class PrintFontCard extends StatelessWidget {
  const PrintFontCard({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final current = PrintFonts.byKey(AppSettingsService.instance.printFontKey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                tr('خطّ الطباعة'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('print-font-open'),
                onPressed: () => _open(context),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: Text(
                  tr('تغيير الخطّ'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr('يحكم كل المستندات المطبوعة: الفاتورة · كشف الحساب · ملخّص الوردية.'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          // معاينة الخطّ الحالي بنفسه.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      current.label,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UsageBadge(font: current),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr(PrintFonts.sample),
                  style: TextStyle(fontFamily: current.family, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(PrintFonts.sampleSmall),
                  style: TextStyle(fontFamily: current.family, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder:
          (_) => _PrintFontDialog(
            currentKey: AppSettingsService.instance.printFontKey,
          ),
    );
    if (picked == null) return;
    if (picked == AppSettingsService.instance.printFontKey) return;
    await controller.updateSetting(AppConstants.settingPrintFont, picked);
  }
}

/// وسم الاستخدام: حراري / ورق / كلاهما.
class _UsageBadge extends StatelessWidget {
  const _UsageBadge({required this.font});

  final PrintFont font;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) =
        font.thermal && font.paper
            ? (const Color(0xFFDCFCE7), const Color(0xFF166534))
            : font.thermal
            ? (const Color(0xFFDBEAFE), const Color(0xFF1E40AF))
            : (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tr(font.usageLabel),
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

/// نافذة الاختيار — كل الخطوط مع معاينتها الحقيقية.
class _PrintFontDialog extends StatefulWidget {
  const _PrintFontDialog({required this.currentKey});

  final String currentKey;

  @override
  State<_PrintFontDialog> createState() => _PrintFontDialogState();
}

class _PrintFontDialogState extends State<_PrintFontDialog> {
  late String _selected = PrintFonts.byKey(widget.currentKey).key;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return AlertDialog(
      title: Text(
        tr('خطّ الطباعة'),
        style: const TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: width < 700 ? width * 0.85 : 620,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tr(
                  'للطابعة الحرارية اختر خطًّا خفيف الحبر: «IBM Plex خفيف» أو «المراعي خفيف» أو «المهنّد». الخطوط الثقيلة تُلتحم على 8–10 نقاط.',
                ),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: PrintFonts.all.length,
                itemBuilder: (context, i) {
                  final f = PrintFonts.all[i];
                  final on = f.key == _selected;
                  return InkWell(
                    key: Key('print-font-${f.key}'),
                    onTap: () => setState(() => _selected = f.key),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: on ? AppColors.primary : AppColors.border,
                          width: on ? 1.6 : 1,
                        ),
                        color: on
                            ? AppColors.primary.withValues(alpha: 0.05)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            on
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color:
                                on ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      f.label,
                                      style: const TextStyle(
                                        fontFamily: 'cairo',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _UsageBadge(font: f),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // المعاينة الحقيقية بهذا الخطّ.
                                Text(
                                  tr(PrintFonts.sampleSmall),
                                  style: TextStyle(
                                    fontFamily: f.family,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(f.note),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            tr('إلغاء'),
            style: const TextStyle(fontFamily: 'cairo'),
          ),
        ),
        FilledButton(
          key: const Key('print-font-apply'),
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(
            tr('طبّق'),
            style: const TextStyle(fontFamily: 'cairo'),
          ),
        ),
      ],
    );
  }
}
