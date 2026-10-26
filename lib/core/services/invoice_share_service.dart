// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/doc_template_service.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// إرسال الفاتورة للزبون عبر واتساب:
/// - مشاركة ملف الفاتورة نفسه (PDF) من قائمة المشاركة → واتساب،
/// - أو فتح محادثة رقم الزبون المسجّل برسالة ملخّص مباشرة.
/// ولو لم يكن للزبون رقم محفوظ، نعرض إدخال الرقم ونحفظه في سجل الزبائن
/// ثم نُكمل الإرسال — فلا تتوقف العملية أبداً.
class InvoiceShareService {
  InvoiceShareService._();

  static final SqlDB _db = SqlDB();

  // ═════════════════ بيانات الفاتورة ═════════════════

  /// بنود الفاتورة من عمود list_data (JSON نصي)
  static List<Map<String, dynamic>> decodeItems(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw.toString()));
    } catch (_) {
      return [];
    }
  }

  /// بيانات الفاتورة الإضافية من عمود map_data (JSON نصي)
  static Map<String, dynamic> decodeMap(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw.toString()));
    } catch (_) {
      return {};
    }
  }

  /// إجمالي الفاتورة المخزَّنة: من `map_data.summation` ثم عمود `total_price`.
  /// وإن كان المخزَّن **صفرًا** (فواتير قديمة كُتبت قبل إصلاح مزامنة المجموع)
  /// يُشتق الإجمالي من بنود `list_data` — فلا تُطبع ولا تُشارَك بصفر.
  static double resolveTotal(
    Map<String, dynamic> invoice, {
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? extra,
  }) {
    final stored =
        extra?['summation'] ??
        invoice['total_price'] ??
        invoice['final_amount'];
    final parsed =
        stored is num
            ? stored.toDouble()
            : double.tryParse('${stored ?? 0}') ?? 0.0;
    if (parsed > 0) return parsed;

    final list = items ?? decodeItems(invoice['list_data']);
    var total = 0.0;
    for (final item in list) {
      final lineTotal = item['total_price'];
      final parsedLine =
          lineTotal is num
              ? lineTotal.toDouble()
              : double.tryParse('${lineTotal ?? ''}') ?? 0.0;
      if (parsedLine > 0) {
        total += parsedLine;
        continue;
      }
      final count =
          item['count'] is num
              ? (item['count'] as num).toDouble()
              : double.tryParse('${item['count'] ?? 0}') ?? 0.0;
      final price =
          item['price'] is num
              ? (item['price'] as num).toDouble()
              : double.tryParse('${item['price'] ?? 0}') ?? 0.0;
      total += price * count;
    }
    return total;
  }

  /// بيانات توليد PDF من صف الفاتورة المخزَّن في قاعدة البيانات
  static Map<String, dynamic> buildPdfData(Map<String, dynamic> invoice) {
    final items = decodeItems(invoice['list_data']);
    final extra = decodeMap(invoice['map_data']);
    final name =
        (extra['customername'] ?? invoice['customer_name'] ?? '').toString();
    return {
      'payment':
          (extra['payment'] ?? invoice['payment_method'] ?? 'كاش').toString(),
      'logoImage': PrintInvoiceController.logoImageBytes,
      'riyalImage': PrintInvoiceController.riyalImageBytes,
      'arabicFont': PrintInvoiceController.arabicFont,
      'invoiceItems': items,
      // المجموع: المخزَّن إن كان موجبًا، وإلا يُشتق من البنود
      'summation': resolveTotal(invoice, items: items, extra: extra),
      'invoiceNumber': invoice['invoices_id'],
      'customername': name,
      'pickupCode': invoice['pickup_code']?.toString() ?? '',
      // فاتورة المشترك تُطبع بدون أسعار (على حساب الاشتراك)
      'hidePrices': invoice['subscription_id'] != null,
      'date':
          extra['date'] ??
          (invoice['invoice_date']?.toString().replaceAll('T', ' ') ?? ''),
      'bizName': BusinessInfoService.instance.name,
      'bizPhone': BusinessInfoService.instance.phone,
      'bizAddress': BusinessInfoService.instance.address,
      'createdByName': '',
      // حجم الشعار يتبع إعداد الفاتورة الحالي — إعادة المشاركة تُخرج الشكل
      // نفسه الذي يراه المستخدم في المعاينة، لا مقاسًا ثابتًا في الكود.
      'logoSizeMm': AppSettingsService.instance.invoiceLogoSizeMm,
      // ─── قالب المستند (تفعيل ونصوص كل عنصر) ───
      ...DocTemplateService.instance.transport(DocKind.invoice),
    };
  }

  /// توليد ملف الفاتورة PDF من البيانات المخزّنة
  static Future<Uint8List?> buildInvoicePdf(
    Map<String, dynamic> invoice,
  ) async {
    await PrintInvoiceController.initializeAssets();
    if (PrintInvoiceController.arabicFont == null ||
        PrintInvoiceController.logoImageBytes == null ||
        PrintInvoiceController.riyalImageBytes == null) {
      return null;
    }
    return compute(PreparePDF.generatePdfData, buildPdfData(invoice));
  }

  // ════════════════ رسالة واتساب ═════════════════

  /// رسالة ملخّص الفاتورة (تُستخدم في المحادثة وفي مشاركة الملف)
  static String buildMessage(Map<String, dynamic> invoice) {
    final items = decodeItems(invoice['list_data']);
    final extra = decodeMap(invoice['map_data']);
    final lines = StringBuffer();
    final bizName =
        BusinessInfoService.instance.name.isNotEmpty
            ? BusinessInfoService.instance.name
            : tr('نظام المغاسل');
    lines.writeln(
      trf('🧺 *فاتورة {0} #{1}*', [bizName, invoice['invoices_id']]),
    );
    final customer =
        (extra['customername'] ?? invoice['customer_name'] ?? '')
            .toString()
            .trim();
    if (customer.isNotEmpty) lines.writeln(trf('👤 الزبون: {0}', [customer]));
    final date = extra['date']?.toString() ?? '';
    if (date.isNotEmpty) lines.writeln('📅 $date');
    lines.writeln('─────────────────');
    for (final item in items.take(12)) {
      lines.writeln(
        '• ${localized(item, 'vestments')} (${localized(item, 'content')}) × ${item['count']}',
      );
      final note = '${item['note'] ?? ''}'.trim();
      if (note.isNotEmpty) lines.writeln('   📝 $note');
    }
    if (items.length > 12) {
      lines.writeln(trf('... و{0} أصناف أخرى', [items.length - 12]));
    }
    lines.writeln('─────────────────');
    if (invoice['subscription_id'] != null) {
      lines.writeln(tr(' على حساب الاشتراك الشهري'));
    } else {
      final total = resolveTotal(invoice, items: items, extra: extra);
      final paid = double.tryParse('${invoice['paid_amount'] ?? 0}') ?? 0;
      final remaining =
          double.tryParse('${invoice['remaining_amount'] ?? 0}') ?? 0;
      lines.writeln(trf('💰 الإجمالي: {0} ر.س', [total.toStringAsFixed(2)]));
      final method = PaymentMethods.label(
        '${extra['payment'] ?? invoice['payment_method'] ?? ''}',
      );
      lines.writeln(
        trf('💳 الدفع: {0} (مدفوع: {1})', [method, paid.toStringAsFixed(2)]),
      );
      if (remaining > 0) {
        lines.writeln(trf('⚠️ متبقي: {0} ر.س', [remaining.toStringAsFixed(2)]));
      }
    }
    final code = invoice['pickup_code']?.toString() ?? '';
    if (code.isNotEmpty) {
      lines.writeln(trf('🔑 رمز استلام الغسيل: {0}', [code]));
    }
    final shop =
        BusinessInfoService.instance.name.isNotEmpty
            ? BusinessInfoService.instance.name
            : tr('نظام المغاسل');
    lines.writeln(trf('شكراً لثقتكم — {0} 💙', [shop]));
    return lines.toString();
  }

  // ════════════════ رقم الزبون ════════════════

  /// تحويل الرقم إلى صيغة واتساب الدولية (05xxxxxxxx → 9665xxxxxxxx)
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.isEmpty) return '';
    if (digits.startsWith('0')) {
      digits = '966${digits.substring(1)}';
    } else if (digits.length == 9 && digits.startsWith('5')) {
      digits = '966$digits';
    }
    return digits;
  }

  static String _pickPhone(Map<String, dynamic> customer) {
    final p1 = (customer['phone_1'] ?? '').toString().trim();
    if (p1.isNotEmpty) return p1;
    return (customer['phone_2'] ?? '').toString().trim();
  }

  /// الزبون المسجّل صاحب الفاتورة (بالمعرّف ثم بالاسم) — أو null
  static Future<Map<String, dynamic>?> resolveCustomer(
    Map<String, dynamic> invoice,
  ) async {
    try {
      final id = invoice['customer_id'];
      if (id != null) {
        final rows = await _db.safeRead(
          'customers',
          where: 'customer_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isNotEmpty) return rows.first;
      }
      final name = (invoice['customer_name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        final rows = await _db.safeRead(
          'customers',
          where: 'customer_name = ? COLLATE NOCASE AND is_active = 1',
          whereArgs: [name],
          limit: 1,
        );
        if (rows.isNotEmpty) return rows.first;
      }
    } catch (e) {
      debugPrint('resolveCustomer error: $e');
    }
    return null;
  }

  /// رقم الزبون: من الفاتورة، ثم من سجل الزبائن بالمعرّف، ثم بالاسم
  static Future<String> resolvePhone(Map<String, dynamic> invoice) async {
    final direct = (invoice['customer_phone'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final customer = await resolveCustomer(invoice);
    if (customer != null) return _pickPhone(customer);
    return '';
  }

  /// حفظ رقم الزبون في سجله (أو إنشاؤه إن لم يكن مسجّلاً) وربطه بالفاتورة
  static Future<void> saveCustomerPhone({
    required Map<String, dynamic> invoice,
    required String phone,
  }) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final name = (invoice['customer_name'] ?? '').toString().trim();
    try {
      var id = invoice['customer_id'] as int?;
      if (id == null) {
        final existing = await resolveCustomer(invoice);
        id = existing?['customer_id'] as int?;
      }
      if (id != null) {
        await _db.safeUpdate(
          'customers',
          {'phone_1': trimmed},
          where: 'customer_id = ?',
          whereArgs: [id],
        );
      } else if (name.isNotEmpty) {
        final newId = await _db.safeInsert('customers', {
          'customer_name': name,
          'phone_1': trimmed,
          'join_date': DateTime.now().toIso8601String(),
          'is_active': 1,
        });
        if (newId > 0) id = newId;
      }
      // ربط الفاتورة بالزبون حتى تُستخدم البيانات في المرات القادمة
      await _db.safeUpdate(
        'invoices',
        {'customer_phone': trimmed, if (id != null) 'customer_id': id},
        where: 'invoices_id = ?',
        whereArgs: [invoice['invoices_id']],
      );
      Get.snackbar(
        tr('تم الحفظ'),
        tr('حُفظ رقم الزبون في سجله — يمكن إرسال الفاتورة الآن'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      debugPrint('saveCustomerPhone error: $e');
      _error(trf('تعذر حفظ رقم الزبون: {0}', [e]));
    }
  }

  // ═════════════════ المشاركة والإرسال ═════════════════

  /// مشاركة ملف الفاتورة PDF (تفتح قائمة المشاركة → واتساب)
  static Future<void> sharePdfFile(Map<String, dynamic> invoice) async {
    try {
      final bytes = await buildInvoicePdf(invoice);
      if (bytes == null || bytes.isEmpty) {
        _error(tr('تعذر تجهيز ملف الفاتورة'));
        return;
      }
      final filename = '${tr('فاتورة')}_${invoice['invoices_id']}.pdf';
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
          subject: trf('فاتورة {0} #{1}', [
            BusinessInfoService.instance.name.isNotEmpty
                ? BusinessInfoService.instance.name
                : tr('نظام المغاسل'),
            invoice['invoices_id'],
          ]),
          body: buildMessage(invoice),
        );
        return;
      }
      // سطح المكتب: نحفظ الملف ثم نفتحه ليُرسل من أي تطبيق
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${invoice['invoices_id']}.pdf');
      await file.writeAsBytes(bytes);
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Get.snackbar(
          tr('تم تجهيز الفاتورة'),
          trf('حُفظت الفاتورة في: {0}', [file.path]),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.info,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      debugPrint('sharePdfFile error: $e');
      _error(trf('فشل مشاركة الفاتورة: {0}', [e]));
    }
  }

  /// فتح محادثة واتساب (مع رقم إن وُجد) برسالة الملخّص
  static Future<void> openWhatsAppChat(String phone, String message) async {
    final number = normalizePhone(phone);
    final uri = Uri.parse(
      'https://wa.me/${number.isEmpty ? '' : number}?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _error(tr('تعذر فتح واتساب'));
    }
  }

  /// زر «واتساب» في الفواتير: يحلّل رقم الزبون ثم يعرض خيارات الإرسال
  static Future<void> sendInvoiceToCustomer(
    Map<String, dynamic> invoice,
  ) async {
    final message = buildMessage(invoice);
    final phone = await resolvePhone(invoice);
    if (phone.isEmpty) {
      await _askForPhoneThenSend(invoice, message);
      return;
    }
    _showSendSheet(invoice, phone, message);
  }

  /// لوحة خيارات الإرسال (ملف PDF / محادثة الزبون / ملخّص لأي جهة)
  static void _showSendSheet(
    Map<String, dynamic> invoice,
    String phone,
    String message,
  ) {
    Get.bottomSheet(
      Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat,
                      color: Color(0xFF25D366),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trf('إرسال الفاتورة #{0}', [invoice['invoices_id']]),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          trf('رقم الزبون: {0}', [phone]),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SheetOption(
                icon: Icons.picture_as_pdf,
                color: AppColors.danger,
                title: tr('إرسال ملف الفاتورة (PDF)'),
                subtitle: tr('تظهر قائمة المشاركة — اختر واتساب ثم الزبون'),
                onTap: () {
                  Get.back();
                  sharePdfFile(invoice);
                },
              ),
              _SheetOption(
                icon: Icons.chat,
                color: const Color(0xFF25D366),
                title: tr('فتح محادثة الزبون على واتساب'),
                subtitle: trf('رسالة ملخّص الفاتورة إلى الرقم {0} مباشرة', [
                  phone,
                ]),
                onTap: () {
                  Get.back();
                  openWhatsAppChat(phone, message);
                },
              ),
              _SheetOption(
                icon: Icons.ios_share,
                color: AppColors.info,
                title: tr('إرسال ملخّص نصي لأي جهة'),
                subtitle: tr('لمشاركة الملخّص دون تحديد رقم'),
                onTap: () {
                  Get.back();
                  openWhatsAppChat('', message);
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  /// لا يوجد رقم للزبون: نطلبه ونحفظه ثم نُكمل الإرسال
  static Future<void> _askForPhoneThenSend(
    Map<String, dynamic> invoice,
    String message,
  ) async {
    final customer = await resolveCustomer(invoice);
    final name = (invoice['customer_name'] ?? '').toString().trim();
    final phoneCtrl = TextEditingController(text: _pickPhone(customer ?? {}));
    Get.dialog(
      Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: _phoneDialog(invoice, name, phoneCtrl),
      ),
      barrierDismissible: true,
    );
  }

  /// نافذة طلب رقم الزبون
  static Widget _phoneDialog(
    Map<String, dynamic> invoice,
    String name,
    TextEditingController phoneCtrl,
  ) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                gradient: AppColors.amberGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('لا يوجد رقم واتساب لهذا الزبون'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name.isEmpty
                  ? tr('أدخل رقم الزبون ليُحفظ في سجله وتُرسل الفاتورة إليه.')
                  : trf(
                    'الزبون «{0}» غير مسجّل برقم — أدخل الرقم ليُحفظ في سجله.',
                    [name],
                  ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '05xxxxxxxx',
                prefixIcon: const Icon(
                  Icons.phone_android,
                  color: AppColors.success,
                ),
                filled: true,
                fillColor: AppColors.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _phoneDialogActions(invoice, phoneCtrl),
          ],
        ),
      ),
    );
  }

  /// أزرار نافذة طلب الرقم
  static Widget _phoneDialogActions(
    Map<String, dynamic> invoice,
    TextEditingController phoneCtrl,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Get.back(),
                child: Text(
                  tr('إلغاء'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Get.back();
                  sharePdfFile(invoice);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                ),
                child: Text(
                  tr('إرسال الملف فقط'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) {
                Get.snackbar(
                  tr('تنبيه'),
                  tr('أدخل رقم الزبون أولاً'),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.warning,
                  colorText: Colors.white,
                );
                return;
              }
              Get.back();
              await saveCustomerPhone(invoice: invoice, phone: phone);
              _showSendSheet(invoice, phone, buildMessage(invoice));
            },
            child: Text(
              tr('حفظ الرقم وإرسال الفاتورة'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _error(String message) {
    Get.snackbar(
      tr('خطأ'),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.danger,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}

/// خيار داخل لوحة الإرسال (واتساب)
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
