/// **حالة رابط الموقع** — سطر حيّ يجيب سؤالًا واحدًا: هل سيُطبع رمز QR؟
///
/// ## لماذا وُجد هذا الملف؟
/// العيب الذي أبلغ عنه المستخدم: «الرمز لا يُطبع». والقيمة المحفوظة كانت
/// `https://ujfx8uiyhjfgksp8iuyrhjfsb` — بروتوكول + رمز بلا نطاق، أي **ليست
/// رابطًا**، فرفضها [MapQr.resolve] كما يجب. لكن النظام **لم يقل شيئًا**:
/// لا في شاشة الإدخال ولا في المعاينة. فيبقى المستخدم يجرّب ويطبع ولا يفهم.
///
/// الحكم هنا **حيّ** (يُحدَّث مع كل حرف) لأنه يُستعمل في ثلاثة مواضع:
/// الإعداد الأولي · «معلومات النشاط» · معاينة الفاتورة. وموضع واحد يعني أن
/// السلوك لا يتفرّع بين شاشة وأخرى.
library;

import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/pdf/map_qr.dart';

/// حكم على نصّ رابط الموقع — **منطق عرض فقط** بلا كتابة في القاعدة.
class MapLinkVerdict {
  const MapLinkVerdict({
    required this.state,
    required this.message,
    this.suggestion = '',
  });

  final MapLinkState state;
  final String message;

  /// الصيغة المقترحة حين يكون المُدخل رمز مشاركة بلا نطاق.
  final String suggestion;

  bool get canRepair => suggestion.isNotEmpty;

  /// يحكم على القيمة الحالية كما ستراها الطباعة تمامًا.
  factory MapLinkVerdict.of(Object? raw) {
    final value = '${raw ?? ''}'.trim();
    if (value.isEmpty) {
      return MapLinkVerdict(
        state: MapLinkState.empty,
        message: tr('لا رمز QR — لم يُدخَل رابط موقع.'),
      );
    }
    final url = MapQr.resolve(value);
    if (url.isEmpty) {
      final fixed = MapQr.repair(value);
      return MapLinkVerdict(
        state: MapLinkState.invalid,
        suggestion: fixed,
        message:
            fixed.isEmpty
                ? tr(
                  'لن يُطبع رمز QR: هذا ليس رابطًا. الصق رابطًا يبدأ بـ https:// أو إحداثيات مثل 24.7136,46.6753.',
                )
                : tr('لن يُطبع رمز QR: الرابط بلا نطاق — يبدو رمز مشاركة فقط.'),
      );
    }
    if (!MapQr.looksLikeMaps(value)) {
      return MapLinkVerdict(
        state: MapLinkState.notMaps,
        message: tr(
          'سيُطبع رمز QR، لكن الرابط لا يبدو رابط خرائط جوجل — تأكّد أنه يفتح موقعك.',
        ),
      );
    }
    return MapLinkVerdict(
      state: MapLinkState.ok,
      message: tr(
        'سيُطبع رمز QR على الفاتورة وكشف الحساب، ويفتح موقعك على خرائط جوجل.',
      ),
    );
  }

  Color get color => switch (state) {
    MapLinkState.ok => AppColors.success,
    MapLinkState.notMaps => AppColors.warning,
    MapLinkState.invalid => AppColors.danger,
    MapLinkState.empty => AppColors.textMuted,
  };

  IconData get icon => switch (state) {
    MapLinkState.ok => Icons.qr_code_2,
    MapLinkState.notMaps => Icons.help_outline,
    MapLinkState.invalid => Icons.error_outline,
    MapLinkState.empty => Icons.info_outline,
  };
}

enum MapLinkState { empty, ok, notMaps, invalid }

/// سطر الحالة أسفل حقل «رابط الموقع» — يتحدّث مع كل حرف.
class MapLinkStatus extends StatelessWidget {
  const MapLinkStatus({
    super.key,
    required this.controller,
    this.onRepaired,
    this.compact = false,
  });

  final TextEditingController controller;

  /// يُنادى بعد تطبيق الاقتراح (لتحديث أي حالة خارجية).
  final VoidCallback? onRepaired;

  /// بلا زرّ إصلاح — للمعاينة حيث لا حقل إدخال.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final v = MapLinkVerdict.of(value.text);
        return Padding(
          padding: EdgeInsets.only(top: compact ? 0 : 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(v.icon, size: 14, color: v.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.message,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        height: 1.4,
                        color: v.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (!compact && v.canRepair) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      controller.text = v.suggestion;
                      controller.selection = TextSelection.collapsed(
                        offset: v.suggestion.length,
                      );
                      onRepaired?.call();
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 15),
                    label: Text(
                      trf('استخدام الصيغة الصحيحة: {0}', [v.suggestion]),
                      style: const TextStyle(fontFamily: 'cairo', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// سطر حالة **قراءة فقط** لقيمة محفوظة — لمعاينة الفاتورة.
///
/// لا يقرأ حقل إدخال لأنه لا يوجد حقل هناك؛ يقرأ الإعداد المحفوظ مباشرةً،
/// ويعيد رسم نفسه عند تغيّر الإعدادات عبر [Obx] في الموضع المستدعي.
class MapLinkStatusText extends StatelessWidget {
  const MapLinkStatusText({super.key, required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final v = MapLinkVerdict.of(raw);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(v.icon, size: 13, color: v.color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            v.message,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              height: 1.35,
              color: v.color,
            ),
          ),
        ),
      ],
    );
  }
}
