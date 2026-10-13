// ignore_for_file: avoid_print
//
// تحقّق من **مُولّد UBL** وبوّابة التكامل الضريبي.
//
//     dart run tool/verify_ubl_builder.dart

import 'package:laundry/services/zatca/ubl_builder.dart';

int passed = 0;
int failed = 0;

void check(String name, Object? got, Object? expected) {
  final ok = '$got' == '$expected';
  ok ? passed++ : failed++;
  print('[${ok ? 'PASS' : 'FAIL'}] $name\n        got=$got  expected=$expected');
}

void checkTrue(String name, bool got) => check(name, got, true);

void main() {
  print('=' * 70);
  print('A. بوّابة التكامل: متى نُصدر مستندًا ضريبيًا؟');
  print('=' * 70);

  checkTrue(
    'A1. مسجَّل + ضريبة + رقم ⇒ نعم',
    ZatcaGate.canIssueDocument(
      taxEnabled: true,
      registered: true,
      taxNumber: '300000000000003',
    ),
  );
  check(
    'A2. غير مسجَّل ⇒ لا',
    ZatcaGate.canIssueDocument(
      taxEnabled: true,
      registered: false,
      taxNumber: '300000000000003',
    ),
    false,
  );
  check(
    'A3. الضريبة معطَّلة ⇒ لا',
    ZatcaGate.canIssueDocument(
      taxEnabled: false,
      registered: true,
      taxNumber: '300000000000003',
    ),
    false,
  );
  check(
    'A4. بلا رقم ضريبي ⇒ لا',
    ZatcaGate.canIssueDocument(
      taxEnabled: true,
      registered: true,
      taxNumber: '  ',
    ),
    false,
  );
  check(
    'A5. لا QR لنشاط غير خاضع',
    ZatcaGate.canPrintQr(
      taxEnabled: false,
      registered: true,
      qrOptionOn: true,
      taxNumber: '300000000000003',
    ),
    false,
  );
  check(
    'A6. لا UBL بلا تجهيز المرحلة الثانية',
    ZatcaGate.canBuildUbl(
      taxEnabled: true,
      registered: true,
      phase2Prepared: false,
      taxNumber: '300000000000003',
    ),
    false,
  );
  checkTrue(
    'A7. UBL يُبنى عند اكتمال الشروط',
    ZatcaGate.canBuildUbl(
      taxEnabled: true,
      registered: true,
      phase2Prepared: true,
      taxNumber: '300000000000003',
    ),
  );

  print('=' * 70);
  print('B. بنية مستند UBL 2.1');
  print('=' * 70);

  final xml = UblBuilder.build(
    UblInvoiceInput(
      invoiceNumber: 'INV-000123',
      uuid: '8e6b2b3c-1111-2222-3333-444455556666',
      issueDate: DateTime(2026, 10, 6, 10, 30, 5),
      sellerName: 'مغاسل النظارة',
      sellerVat: '300000000000003',
      sellerCr: '1010000000',
      buyerName: 'عميل نقدي',
      taxBase: 100,
      taxAmount: 15,
      payable: 115,
      rate: 0.15,
      lines: const [
        UblLine(
          name: 'قميص',
          quantity: 2,
          unitPrice: 50,
          lineTotal: 100,
          taxAmount: 15,
        ),
      ],
    ),
  );

  checkTrue('B1. ترويسة XML', xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
  checkTrue('B2. فضاء UBL 2.1', xml.contains('xsd:Invoice-2'));
  checkTrue('B3. معرّف الفاتورة', xml.contains('<cbc:ID>INV-000123</cbc:ID>'));
  checkTrue(
    'B4. UUID موجود',
    xml.contains('<cbc:UUID>8e6b2b3c-1111-2222-3333-444455556666</cbc:UUID>'),
  );
  checkTrue('B5. التاريخ', xml.contains('<cbc:IssueDate>2026-10-06</cbc:IssueDate>'));
  checkTrue('B6. الوقت', xml.contains('<cbc:IssueTime>10:30:05</cbc:IssueTime>'));
  checkTrue('B7. رمز نوع الفاتورة 388', xml.contains('>388</cbc:InvoiceTypeCode>'));
  checkTrue('B8. العملة SAR', xml.contains('<cbc:DocumentCurrencyCode>SAR</cbc:DocumentCurrencyCode>'));
  checkTrue('B9. الرقم الضريبي للبائع', xml.contains('<cbc:CompanyID>300000000000003</cbc:CompanyID>'));
  checkTrue('B10. السجل التجاري', xml.contains('<cbc:CompanyID>1010000000</cbc:CompanyID>'));
  checkTrue('B11. ضريبة إجمالية 15', xml.contains('<cbc:TaxAmount currencyID="SAR">15.00</cbc:TaxAmount>'));
  checkTrue('B12. الإجمالي شامل 115', xml.contains('<cbc:TaxInclusiveAmount currencyID="SAR">115.00</cbc:TaxInclusiveAmount>'));
  checkTrue('B13. فئة ضريبية قياسية S', xml.contains('<cbc:ID>S</cbc:ID>'));
  checkTrue('B14. النسبة 15', xml.contains('<cbc:Percent>15</cbc:Percent>'));
  checkTrue('B15. بند فاتورة', xml.contains('<cbc:Name>قميص</cbc:Name>'));
  checkTrue('B16. الكمية', xml.contains('<cbc:InvoicedQuantity unitCode="PCE">2</cbc:InvoicedQuantity>'));
  checkTrue('B17. إغلاق المستند', xml.trim().endsWith('</Invoice>'));

  print('=' * 70);
  print('C. الهروب والفئة الصفرية');
  print('=' * 70);

  final escaped = UblBuilder.build(
    UblInvoiceInput(
      invoiceNumber: 'X&Y',
      uuid: 'u',
      issueDate: DateTime(2026, 1, 1),
      sellerName: 'متجر <أ>',
      sellerVat: '300000000000003',
      taxBase: 10,
      taxAmount: 0,
      payable: 10,
      rate: 0,
    ),
  );
  checkTrue('C1. هروب &', escaped.contains('X&amp;Y'));
  checkTrue('C2. هروب < و >', escaped.contains('متجر &lt;أ&gt;'));
  checkTrue('C3. فئة صفرية Z', escaped.contains('<cbc:ID>Z</cbc:ID>'));

  print('=' * 70);
  if (failed > 0) {
    print('$failed من ${passed + failed} فحصًا فشل');
    throw StateError('$failed فحوصات فاشلة');
  }
  print('كل الفحوصات نجحت ($passed/${passed + failed})');
}
