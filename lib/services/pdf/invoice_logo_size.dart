/// حساب مقاس شعار الفاتورة المطبوع — منطق خالص قابل للاختبار.
///
/// الإعداد يُخزَّن **بالمليمتر** لأنه وحدة يفهمها صاحب النشاط، بينما حزمة
/// `pdf` ترسم بالنقاط. والتحويل هنا لا في الواجهة، حتى يبقى المولّد هو
/// المصدر الوحيد لقرار المقاس.
///
/// **لماذا لا نمرّر المليمتر كما هو؟** لأن جميع حدود الورق والهوامش في
/// `PreparePDF` بالنقاط؛ خلط الوحدتين يُخرج شعارًا أكبر من الورقة على
/// الإيصال الحراري بلا أي رسالة.
library;

import 'package:laundry/config/constants.dart';
import 'package:laundry/core/services/paper_size.dart';

class InvoiceLogoSize {
  InvoiceLogoSize._();

  /// أصغر بُعد مسموح بالنقاط — لا يسمح باختفاء الشعار بسبب قيمة شاذّة.
  static const double minPoints = 8;

  /// يحوّل قيمة الإعداد (مم) إلى نقاط، ويقيّدها بعرض الورق القابل للطباعة.
  ///
  /// [rawMm] قد تأتي من JSON قديم أو من عزل `compute` كنصّ أو `num` أو
  /// `null`؛ كل الحالات تُعالَج بلا رمي. و[ maxWidth] هو عرض الورق بعد
  /// الهوامش، فلا يخرج الشعار عن الصفحة على المقاسات الضيقة (حراري 58 مم).
  static double resolvePoints(Object? rawMm, {required double maxWidth}) {
    final parsed = switch (rawMm) {
      num v => v.toDouble(),
      String v => double.tryParse(v.trim()),
      _ => null,
    };
    var mm =
        parsed != null && parsed.isFinite
            ? parsed
            : AppConstants.invoiceLogoSizeDefaultMm.toDouble();
    mm =
        mm
            .clamp(
              AppConstants.invoiceLogoSizeMinMm.toDouble(),
              AppConstants.invoiceLogoSizeMaxMm.toDouble(),
            )
            .toDouble();

    final points = PaperSizes.mmToPoints(mm);
    final available = maxWidth > minPoints ? maxWidth : minPoints;
    if (points > available) return available;
    return points < minPoints ? minPoints : points;
  }
}
