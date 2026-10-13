import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/customer/customer_statement_service.dart';
import 'package:printing/printing.dart';

/// تصدير كشف حساب الزبون: طباعة PDF أو مشاركته على واتساب.
///
/// **لماذا متحكّم منفصل؟** الكشف يُطلب من أكثر من شاشة (حساب الزبون، أعمار
/// الديون). لو كُتب في كل شاشة لتكرّر بناء البيانات وتفاوت التنسيق — وهو
/// نفس الخطأ الذي جعل منطق FIFO يتفرّع سابقًا.
class CustomerStatementController extends GetxController {
  final RxBool isBusy = false.obs;

  /// الفترة المختارة للكشف (null = الكشف كامل بلا تقييد).
  final Rxn<DateTimeRange> selectedRange = Rxn<DateTimeRange>();

  /// نصّ الفترة المختارة — للعرض في الواجهة.
  String get rangeLabel {
    final r = selectedRange.value;
    if (r == null) return 'كل الفترة (بلا تقييد)';
    return 'من ${_day(r.start)} إلى ${_day(r.end)}';
  }

  /// ضبط الفترة (null = إلغاء التقييد).
  void setRange(DateTimeRange? range) => selectedRange.value = range;

  /// يبني الكشف ويرسله للطباعة أو المشاركة.
  ///
  /// [share] = true → قائمة مشاركة النظام (واتساب)، وإلا → حوار الطباعة.
  /// [range] يتجاوز الفترة المخزَّنة إن مُرِّر.
  Future<void> export(
    int customerId, {
    bool share = false,
    DateTimeRange? range,
  }) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final r = range ?? selectedRange.value;
      final st = await CustomerStatementService.instance.build(
        customerId,
        from: r?.start,
        to: r?.end,
      );
      if (st == null) {
        _info('تعذّر تجهيز كشف الحساب', AppColors.danger);
        return;
      }
      final data = buildPdfData(st);
      final bytes = await PreparePDF.generateCustomerStatementPdf(data);
      if (bytes.isEmpty) {
        _info('تعذّر توليد ملف الكشف', AppColors.danger);
        return;
      }
      final filename = 'كشف_حساب_${st.customerId}.pdf';

      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
          subject: 'كشف حساب — ${st.customerName}',
          body: summaryText(st),
        );
      } else {
        // على الجوال يفتح حوار الطباعة مباشرةً؛ على سطح المكتب يُحفظ الملف.
        final done = await Printing.layoutPdf(
          name: filename,
          onLayout: (_) => bytes,
        );
        if (!done) {
          await _saveToDisk(bytes, filename, st.customerName);
        }
      }
    } catch (e) {
      debugPrint('CustomerStatementController.export error: $e');
      _info('فشل تصدير الكشف: $e', AppColors.danger);
    } finally {
      isBusy.value = false;
    }
  }

  /// ملخّص نصّي جاهز للإرسال على واتساب.
  String summaryText(CustomerStatement st) {
    final b = StringBuffer();
    final biz = BusinessInfoService.instance.name;
    if (biz.isNotEmpty) b.writeln(biz);
    b.writeln('كشف حساب: ${st.customerName}');
    if (st.hasRange) b.writeln('الفترة: ${periodLabel(st)}');
    b.writeln('────────────────');
    b.writeln('إجمالي المشتريات: ${_m(st.totalPurchases)} ريال');
    b.writeln('المسدَّد: ${_m(st.totalPaidOnInvoices)} ريال');
    if (st.hasDebt) {
      b.writeln('الذمة المتبقية (عليه): ${_m(st.totalDebt)} ريال');
      if (st.oldestDebtDate != null) {
        b.writeln('أقدم ذمة: ${_d(st.oldestDebtDate!)}');
      }
    }
    if (st.hasCredit) {
      b.writeln('الرصيد الدائن (له): ${_m(st.creditBalance)} ريال');
    }
    b.writeln(
      'صافي الموقف: ${_m(st.netPosition.abs())} ريال '
      '${st.netPosition >= 0 ? '(له)' : '(عليه)'}',
    );
    if (st.totalSubscriptionPieces > 0) {
      b.writeln('قطع الاشتراك المستهلكة: ${st.totalSubscriptionPieces}');
    }
    b.writeln('────────────────');
    b.write('مغاسل النظارة — شكرًا لتعاملكم معنا');
    return b.toString();
  }

  /// نصّ الفترة للعرض («من 2026-10-01 إلى 2026-10-03» أو طرف واحد).
  String periodLabel(CustomerStatement st) {
    final f = st.rangeFrom;
    final t = st.rangeTo;
    if (f == null && t == null) return '';
    if (f != null && t != null) return 'من ${_day(f)} إلى ${_day(t)}';
    if (f != null) return 'من ${_day(f)} حتى الآن';
    return 'حتى ${_day(t!)}';
  }

  /// خريطة البيانات التي يستهلكها مولّد الـPDF.
  Map<String, dynamic> buildPdfData(CustomerStatement st) {
    final biz = BusinessInfoService.instance;
    return {
      'bizName': biz.name,
      'bizPhone': biz.phone,
      'bizAddress': biz.address,
      'customerName': st.customerName,
      'customerPhone': st.phone,
      'printedAt': DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now()),
      // فارغ = كشف كامل؛ غير فارغ ⇒ يُطبع سطر «الفترة» تحت العنوان.
      'period': periodLabel(st),
      'totals': {
        'purchases': st.totalPurchases,
        'paid': st.totalPaidOnInvoices,
        'debt': st.totalDebt,
        'credit': st.creditBalance,
        'net': st.netPosition,
        'pieces': st.totalPieces,
        'subPieces': st.totalSubscriptionPieces,
        'subValue': st.totalSubscriptionValue,
      },
      'invoices': st.invoices
          .map(
            (e) => {
              'id': e.id,
              'date': _d(e.date),
              'total': e.total,
              'paid': e.paid,
              'remaining': e.remaining,
            },
          )
          .toList(),
      // الأصناف في **جدول واحد**: كل بند بتاريخه وعدده وقيمته.
      // (حُذف الجدول المجمَّع `items` 2026-10-03 بطلب المستخدم: كان يكرّر
      //  الصنف بلا تاريخ ويطيل الكشف بلا جدوى. `st.itemSummary` يبقى لأنه
      //  مستخدم في شاشة حساب الزبون.)
      'itemsDetailed': [
        for (final inv in st.invoices)
          for (final it in inv.items)
            {
              'date': _dt(inv.date),
              'name': it.name,
              'count': it.count,
              'value': it.value,
            },
      ],
      'payments': st.payments
          .map(
            (e) => {
              'date': _d(e.date),
              'amount': e.amount,
              'method': e.method,
              'note': _sourceLabel(e),
            },
          )
          .toList(),
      'usages': st.usages
          .map(
            (e) => {
              'date': _d(e.date),
              'subscriptionId': e.subscriptionId,
              'pieces': e.pieces,
              'value': e.value,
              'invoiceId': e.invoiceId,
            },
          )
          .toList(),
    };
  }

  /// وصف مقروء لمصدر الدفعة — يفصل النقدي عن التسويات.
  ///
  /// ⚠️ الفاصل **شرطة قصيرة `–` لا طويلة `—`**: خط `AL-Mohanad` لا يحوي
  /// محرف الشرطة الطويلة (U+2014) فيُرسم مربّعًا/محرفًا خاطئًا في الـPDF.
  String _sourceLabel(StatementPayment p) {
    final base = switch (p.source) {
      'credit_use' => 'استهلاك رصيد سلفة',
      'cancel_refund' => 'استرداد إلغاء اشتراك',
      'delivery' => 'تحصيل عند التسليم',
      _ => p.method.isNotEmpty ? p.method : 'دفعة',
    };
    final note = p.note.trim();
    return note.isEmpty ? base : '$base – $note';
  }

  Future<void> _saveToDisk(
    Uint8List bytes,
    String filename,
    String customerName,
  ) async {
    try {
      final dir = await Directory.systemTemp.createTemp('statement');
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      _info('حُفظ الكشف في: ${file.path}', AppColors.info);
    } catch (e) {
      debugPrint('saveStatement error: $e');
      _info('تعذّر حفظ الكشف', AppColors.danger);
    }
  }

  static String _m(double v) => v.toStringAsFixed(2);

  /// يوم فقط `yyyy-MM-dd` من كائن تاريخ.
  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// تنسيق تاريخ ISO إلى صيغة مقروءة (يتحمّل الفشل).
  static String _d(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(raw));
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  /// تاريخ **ووقت** — لبند الصنف («في أي يوم وكم الساعة أخذه»).
  ///
  /// ⚠️ الطوابع مخزَّنة محليًا (`toIso8601String` بلا `toUtc`) ⇒ لا تحويل
  /// مناطق زمنية هنا، وإلا أُزيح الوقت بإزاحة الجهاز.
  static String _dt(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  void _info(String message, Color color) {
    Get.snackbar(
      'كشف الحساب',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
