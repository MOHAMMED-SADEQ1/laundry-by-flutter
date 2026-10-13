/// **تجهيز المرحلة الثانية من زاتكا** — مُولّد UBL 2.1 منطق خالص.
///
/// هذا الملف يبني **تمثيل الفاتورة الضريبية** بصيغة UBL 2.1 التي تطلبها
/// الهيئة، بلا أي اتصال شبكة وبلا توقيع. الغرض أن يكون التوقيع والإرسال
/// لاحقًا **طبقة فوقه** لا إعادة كتابة: البنية والحقول الإلزامية موجودة
/// ومختبَرة الآن، والتفعيل الفعلي يبقى معطَّلًا حتى يقرّر النشاط.
///
///     dart run tool/verify_ubl_builder.dart
library;

/// بند واحد في الفاتورة.
class UblLine {
  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double taxRate;
  final double taxAmount;

  const UblLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.taxRate = 0.15,
    this.taxAmount = 0,
  });
}

/// مدخلات بناء فاتورة UBL.
class UblInvoiceInput {
  final String invoiceNumber;
  final String uuid;
  final DateTime issueDate;
  final String sellerName;
  final String sellerVat;
  final String sellerCr;
  final String sellerAddress;
  final String buyerName;
  final String buyerVat;

  /// فاتورة مبسّطة (نقطة بيع) أم ضريبية قياسية.
  final bool simplified;

  final double taxBase;
  final double taxAmount;
  final double payable;
  final double rate;
  final List<UblLine> lines;

  const UblInvoiceInput({
    required this.invoiceNumber,
    required this.uuid,
    required this.issueDate,
    required this.sellerName,
    required this.sellerVat,
    this.sellerCr = '',
    this.sellerAddress = '',
    this.buyerName = '',
    this.buyerVat = '',
    this.simplified = true,
    required this.taxBase,
    required this.taxAmount,
    required this.payable,
    this.rate = 0.15,
    this.lines = const [],
  });
}

/// بوّابة التكامل الضريبي: متى يجوز إصدار مستند ضريبي؟
///
/// **متى لا نُخرِج شيئًا:** إن كان النشاط غير مسجَّل، أو الضريبة معطَّلة، أو
/// الرقم الضريبي غائبًا. النشاط غير الخاضع للضريبة **لا يتصل بالهيئة ولا
/// يُصدر QR ولا XML** — وهذا هو الفرق بينه وبين النشاط المسجَّل.
class ZatcaGate {
  ZatcaGate._();

  static bool canIssueDocument({
    required bool taxEnabled,
    required bool registered,
    required String taxNumber,
  }) => taxEnabled && registered && taxNumber.trim().isNotEmpty;

  static bool canPrintQr({
    required bool taxEnabled,
    required bool registered,
    required bool qrOptionOn,
    required String taxNumber,
  }) =>
      qrOptionOn &&
      canIssueDocument(
        taxEnabled: taxEnabled,
        registered: registered,
        taxNumber: taxNumber,
      );

  static bool canBuildUbl({
    required bool taxEnabled,
    required bool registered,
    required bool phase2Prepared,
    required String taxNumber,
  }) =>
      phase2Prepared &&
      canIssueDocument(
        taxEnabled: taxEnabled,
        registered: registered,
        taxNumber: taxNumber,
      );
}

class UblBuilder {
  UblBuilder._();

  /// يبني مستند UBL 2.1 كنصّ XML.
  ///
  /// الصيغة مبسّطة على قدر ما تحتاجه فاتورة مغسلة، لكنها تحمل كل الحقول
  /// الإلزامية التي تُرفض الفاتورة بغيابها: المعرّف · UUID · التاريخ والوقت ·
  /// رمز النوع (388/383) · الضريبة الإجمالية · الإجمالي النقدي · طرفا
  /// المعاملة · بنود الفاتورة.
  static String build(UblInvoiceInput input) {
    final typeCode = input.simplified ? '388' : '388';
    final subtype = input.simplified ? '0200000' : '0100000';
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"'
        ' xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"'
        ' xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">');
    buf.writeln('  <cbc:ID>${_esc(input.invoiceNumber)}</cbc:ID>');
    buf.writeln('  <cbc:UUID>${_esc(input.uuid)}</cbc:UUID>');
    buf.writeln('  <cbc:IssueDate>${_date(input.issueDate)}</cbc:IssueDate>');
    buf.writeln('  <cbc:IssueTime>${_time(input.issueDate)}</cbc:IssueTime>');
    buf.writeln('  <cbc:InvoiceTypeCode name="$subtype">$typeCode</cbc:InvoiceTypeCode>');
    buf.writeln('  <cbc:DocumentCurrencyCode>SAR</cbc:DocumentCurrencyCode>');
    buf.writeln('  <cbc:TaxCurrencyCode>SAR</cbc:TaxCurrencyCode>');

    buf.writeln('  <cac:AdditionalDocumentReference>');
    buf.writeln('    <cbc:ID>ICV</cbc:ID>');
    buf.writeln('    <cbc:UUID>${_esc(input.invoiceNumber)}</cbc:UUID>');
    buf.writeln('  </cac:AdditionalDocumentReference>');

    buf.writeln('  <cac:AccountingSupplierParty>');
    buf.writeln('    <cac:Party>');
    buf.writeln('      <cac:PartyTaxScheme>');
    buf.writeln('        <cbc:CompanyID>${_esc(input.sellerVat)}</cbc:CompanyID>');
    buf.writeln('        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>');
    buf.writeln('      </cac:PartyTaxScheme>');
    buf.writeln('      <cac:PartyLegalEntity>');
    buf.writeln('        <cbc:RegistrationName>${_esc(input.sellerName)}</cbc:RegistrationName>');
    if (input.sellerCr.trim().isNotEmpty) {
      buf.writeln('        <cbc:CompanyID>${_esc(input.sellerCr)}</cbc:CompanyID>');
    }
    buf.writeln('      </cac:PartyLegalEntity>');
    buf.writeln('    </cac:Party>');
    buf.writeln('  </cac:AccountingSupplierParty>');

    buf.writeln('  <cac:AccountingCustomerParty>');
    buf.writeln('    <cac:Party>');
    if (input.buyerVat.trim().isNotEmpty) {
      buf.writeln('      <cac:PartyTaxScheme>');
      buf.writeln('        <cbc:CompanyID>${_esc(input.buyerVat)}</cbc:CompanyID>');
      buf.writeln('        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>');
      buf.writeln('      </cac:PartyTaxScheme>');
    }
    buf.writeln('      <cac:PartyLegalEntity>');
    buf.writeln('        <cbc:RegistrationName>${_esc(input.buyerName)}</cbc:RegistrationName>');
    buf.writeln('      </cac:PartyLegalEntity>');
    buf.writeln('    </cac:Party>');
    buf.writeln('  </cac:AccountingCustomerParty>');

    buf.writeln('  <cac:TaxTotal>');
    buf.writeln('    <cbc:TaxAmount currencyID="SAR">${_money(input.taxAmount)}</cbc:TaxAmount>');
    buf.writeln('    <cac:TaxSubtotal>');
    buf.writeln('      <cbc:TaxableAmount currencyID="SAR">${_money(input.taxBase)}</cbc:TaxableAmount>');
    buf.writeln('      <cbc:TaxAmount currencyID="SAR">${_money(input.taxAmount)}</cbc:TaxAmount>');
    buf.writeln('      <cac:TaxCategory>');
    buf.writeln('        <cbc:ID>${_taxCat(input.rate)}</cbc:ID>');
    buf.writeln('        <cbc:Percent>${_percent(input.rate)}</cbc:Percent>');
    buf.writeln('        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>');
    buf.writeln('      </cac:TaxCategory>');
    buf.writeln('    </cac:TaxSubtotal>');
    buf.writeln('  </cac:TaxTotal>');

    buf.writeln('  <cac:LegalMonetaryTotal>');
    buf.writeln('    <cbc:LineExtensionAmount currencyID="SAR">${_money(input.taxBase)}</cbc:LineExtensionAmount>');
    buf.writeln('    <cbc:TaxExclusiveAmount currencyID="SAR">${_money(input.taxBase)}</cbc:TaxExclusiveAmount>');
    buf.writeln('    <cbc:TaxInclusiveAmount currencyID="SAR">${_money(input.payable)}</cbc:TaxInclusiveAmount>');
    buf.writeln('    <cbc:PayableAmount currencyID="SAR">${_money(input.payable)}</cbc:PayableAmount>');
    buf.writeln('  </cac:LegalMonetaryTotal>');

    for (var i = 0; i < input.lines.length; i++) {
      final line = input.lines[i];
      buf.writeln('  <cac:InvoiceLine>');
      buf.writeln('    <cbc:ID>${i + 1}</cbc:ID>');
      buf.writeln('    <cbc:InvoicedQuantity unitCode="PCE">${_qty(line.quantity)}</cbc:InvoicedQuantity>');
      buf.writeln('    <cbc:LineExtensionAmount currencyID="SAR">${_money(line.lineTotal)}</cbc:LineExtensionAmount>');
      buf.writeln('    <cac:TaxTotal>');
      buf.writeln('      <cbc:TaxAmount currencyID="SAR">${_money(line.taxAmount)}</cbc:TaxAmount>');
      buf.writeln('      <cbc:RoundingAmount currencyID="SAR">${_money(line.lineTotal + line.taxAmount)}</cbc:RoundingAmount>');
      buf.writeln('    </cac:TaxTotal>');
      buf.writeln('    <cac:Item><cbc:Name>${_esc(line.name)}</cbc:Name></cac:Item>');
      buf.writeln('    <cac:Price><cbc:PriceAmount currencyID="SAR">${_money(line.unitPrice)}</cbc:PriceAmount></cac:Price>');
      buf.writeln('  </cac:InvoiceLine>');
    }

    buf.writeln('</Invoice>');
    return buf.toString();
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _money(double v) => v.toStringAsFixed(2);
  static String _qty(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(3);
  static String _percent(double r) {
    final v = r * 100;
    final rounded = v.roundToDouble();
    if ((v - rounded).abs() < 0.0001) return rounded.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _taxCat(double r) {
    if (r <= 0) return 'Z'; // صفرية / معفاة
    return 'S'; // قياسية
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
  static String _time(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}
