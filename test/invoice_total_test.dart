// اختبار انحدار: مجموع الفاتورة.
//
// **الخطأ الذي يحرسه هذا الاختبار:** كان `InvoiceController.summation` حقلًا
// تفاعليًا لا يُحدَّث أبدًا (`calcSummation()` لم تكن تُستدعى من أي مكان)،
// فكانت الشاشة تعرض المجموع الصحيح (لأنها تحسبه لحظيًا) بينما يُحفظ في قاعدة
// البيانات `total_price = 0` و`final_amount = 0`، ويُطبع في PDF صفرًا.
// أثر ذلك: إيراد مفقود في التقارير والصندوق ودَين زبائن لا يُسجَّل.

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/services/invoice_share_service.dart';

/// بند فاتورة كما تبنيه `ShowDialogController._addToInvoice`
Map<String, dynamic> item(String name, num price, int count) => {
  'vestments': name,
  'content': 'غسيل وكوي عادي',
  'count': count,
  'price': price,
  'total_price': price * count,
};

void main() {
  group('InvoiceController — المجموع مشتق من البنود ومتزامن معها', () {
    test('totalValue يجمع total_price لكل بند', () {
      final c = InvoiceController()
        ..invoice.addAll([item('ثوب', 10, 3), item('بنطال', 15, 2)]);
      expect(c.totalValue(), 60.0);
    });

    test('addItem تُضيف البند وتُزامن summation.value', () {
      final c = InvoiceController();
      c.addItem(item('ثوب', 12.5, 4));
      expect(c.invoice.length, 1);
      expect(c.summation.value, 50.0);
      c.addItem(item('بنطال', 7.25, 2));
      expect(c.summation.value, 64.5);
      expect(c.totalValue(), c.summation.value);
    });

    test('removeItem تُزامن summation.value بعد الحذف', () {
      final c = InvoiceController()
        ..addItem(item('ثوب', 10, 3))
        ..addItem(item('بنطال', 15, 2));
      c.removeItem(0);
      expect(c.summation.value, 30.0);
      expect(c.summation.value, c.totalValue());
    });

    test('setItems (استعادة مسودة) تُزامن المجموع', () {
      final c = InvoiceController()..addItem(item('ثوب', 10, 3));
      c.setItems([item('بنطال', 15, 2), item('بطانية', 20, 1)]);
      expect(c.summation.value, 50.0);
      expect(c.invoice.length, 2);
    });

    test('المجموع الكلي لا يُصفّر — هذه هي حالة الخطأ الأصلية', () {
      final c = InvoiceController()
        ..addItem(item('ثوب', 10, 3))
        ..addItem(item('بنطال', 15, 2));
      // لو عاد الخطأ القديم (summation غير متزامن) يفشل هذا السطر
      expect(c.summation.value, 60.0);
    });

    test('كسور عشرية دقيقة بلا فقدان', () {
      final c = InvoiceController()..addItem(item('قميص', 15.25, 3));
      expect(c.totalValue(), closeTo(45.75, 1e-9));
      expect(c.summation.value, closeTo(45.75, 1e-9));
    });

    test('refreshSummation بعد تفريغ البنود يُعيد الصفر', () {
      final c = InvoiceController()..addItem(item('ثوب', 10, 3));
      c.invoice.clear();
      c.refreshSummation();
      expect(c.summation.value, 0.0);
      expect(c.totalValue(), 0.0);
    });
  });

  group('InvoiceShareService.resolveTotal — طباعة/مشاركة الفواتير المخزَّنة', () {
    test('يفضّل المجموع المخزَّن إن كان موجبًا', () {
      final total = InvoiceShareService.resolveTotal({
        'total_price': 120.0,
        'list_data': '[{"total_price":999}]',
        'map_data': '{"summation":120.0}',
      });
      expect(total, 120.0);
    });

    test('يشتق من البنود إن كان المخزَّن صفرًا (فاتورة قديمة)', () {
      final total = InvoiceShareService.resolveTotal({
        'total_price': 0.0,
        'map_data': '{"summation":0.0}',
        'list_data':
            '[{"count":3,"price":10,"total_price":30},'
            '{"count":2,"price":15,"total_price":30}]',
      });
      expect(total, 60.0);
    });

    test('يشتق بـ price × count إن غاب total_price من البند', () {
      final total = InvoiceShareService.resolveTotal({
        'total_price': 0.0,
        'list_data': '[{"count":3,"price":10},{"count":2,"price":15}]',
      });
      expect(total, 60.0);
    });

    test('يتعامل مع الأرقام المخزَّنة كنص (قواعد بيانات قديمة)', () {
      final total = InvoiceShareService.resolveTotal({
        'total_price': '0',
        'list_data': '[{"count":"3","price":"10.5","total_price":"31.5"}]',
      });
      expect(total, 31.5);
    });

    test('يعيد صفرًا لفاتورة بلا بنود وبلا مجموع', () {
      final total = InvoiceShareService.resolveTotal({
        'total_price': 0.0,
        'list_data': '[]',
      });
      expect(total, 0.0);
    });
  });
}