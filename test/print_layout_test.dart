// اختبار تخطيط الطباعة الفعلي — يحرس إصلاح «قصّ يمين الورقة» في الطباعة
// التلقائية.
//
// **العيب الذي يحرسه:** الطبقة الأصلية في ويندوز ترسم صفحة الـPDF بكامل عرض
// الورقة المادية من حدّها الأيسر. فأي محتوى يقع في هامش العتاد غير القابل
// للطباعة يُقصّ — وفي العربية يُقصّ يمين الصفحة، أي بداية أسماء الأصناف.
// الحلّ: توليد نسخة الطباعة بمقاس الورقة الفعلي وبهامش لا يقلّ عن هامش
// العتاد. هذه الاختبارات تثبت السياسة نفسها بلا طابعة حقيقية.

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/services/printer/print_layout.dart';
import 'package:pdf/pdf.dart';

void main() {
  group('PrintLayout.fromPdfPageFormat', () {
    test('يقرأ المقاس والهوامش ويُهمل السالب', () {
      final layout = PrintLayout.fromPdfPageFormat(
        const PdfPageFormat(
          600,
          800,
          marginLeft: 20,
          marginTop: -5,
          marginRight: 12.5,
          marginBottom: 0,
        ),
      );

      expect(layout.width, 600);
      expect(layout.height, 800);
      expect(layout.left, 20);
      expect(layout.top, 0);
      expect(layout.right, 12.5);
      expect(layout.bottom, 0);
      expect(layout.isUsable, isTrue);
    });

    test('يرفض الأبعاد غير المعقولة (تعريف شاذ)', () {
      expect(
        PrintLayout.fromData(<String, dynamic>{
          'width': 0,
          'height': 0,
          'left': 0,
          'top': 0,
          'right': 0,
          'bottom': 0,
        }),
        isNull,
      );
    });
  });

  group('نقل الخريطة إلى العزل', () {
    test('applyTo ثم fromData يعيد القيم نفسها', () {
      const layout = PrintLayout(
        width: 595.28,
        height: 841.89,
        left: 11.5,
        top: 8,
        right: 22.75,
        bottom: 9,
      );

      final payload = layout.applyTo(<String, dynamic>{'paperSize': 'a4'});
      expect(payload['paperSize'], 'a4');

      final back = PrintLayout.fromData(payload[PrintLayout.dataKey]);
      expect(back, isNotNull);
      expect(back!.width, 595.28);
      expect(back.height, 841.89);
      expect(back.left, 11.5);
      expect(back.top, 8);
      expect(back.right, 22.75);
      expect(back.bottom, 9);
    });
  });

  group('هامش الطباعة الآمن', () {
    const base = PdfPageFormat.cm; // 28.35 نقطة

    test('هامش التصميم يفوز حين يكون هامش العتاد أصغر', () {
      expect(
        PrintLayout.safeMargin(
          hardware: 4,
          base: base,
          safety: 4.25,
          extent: 595,
        ),
        base,
      );
    });

    test('هامش العتاد + أمان يفوز حين يكون أوسع', () {
      expect(
        PrintLayout.safeMargin(
          hardware: 40,
          base: base,
          safety: 4.25,
          extent: 595,
        ),
        closeTo(44.25, 0.001),
      );
    });

    test('سقف ٣٠٪ يمنع تعريفًا شاذًا من ابتلاع الصفحة', () {
      expect(
        PrintLayout.safeMargin(
          hardware: 500,
          base: base,
          safety: 4.25,
          extent: 595,
        ),
        closeTo(595 * 0.30, 0.001),
      );
    });
  });

  group('PrintLayout.pageFormat', () {
    test('بلا تخطيط: الورق المصمَّم ومقاسه الافتراضي', () {
      final f = PrintLayout.pageFormat(
        width: 595.28,
        height: 841.89,
        layout: null,
        baseMargin: PdfPageFormat.cm,
        safety: 4.25,
      );

      expect(f.width, 595.28);
      expect(f.height, 841.89);
      expect(f.marginLeft, PdfPageFormat.cm);
      expect(f.marginRight, PdfPageFormat.cm);
    });

    test('مع تخطيط: مقاس الطابعة وهامشها الأيمن الأوسع', () {
      final f = PrintLayout.pageFormat(
        width: 595.28,
        height: 841.89,
        layout: const PrintLayout(
          width: 612,
          height: 792,
          left: 10,
          top: 10,
          right: 40,
          bottom: 10,
        ),
        baseMargin: PdfPageFormat.cm,
        safety: 4.25,
      );

      expect(f.width, 612); // عرض الورقة الفعلي لا المصمَّم
      expect(f.height, 792);
      expect(f.marginLeft, PdfPageFormat.cm); // هامش التصميم أوسع
      expect(f.marginRight, closeTo(44.25, 0.001)); // 40 + 4.25
      expect(f.availableWidth, closeTo(612 - PdfPageFormat.cm - 44.25, 0.001));
    });

    test('keepHeight يُبقي ارتفاع التصميم (ورق حراري متصل)', () {
      final f = PrintLayout.pageFormat(
        width: 226.77,
        height: 360,
        layout: const PrintLayout(
          width: 226.77,
          height: 1000,
          left: 4,
          top: 4,
          right: 4,
          bottom: 4,
        ),
        baseMargin: 5.67,
        safety: 1.42,
        keepHeight: true,
      );

      expect(f.height, 360);
      expect(f.width, 226.77);
    });
  });
}
