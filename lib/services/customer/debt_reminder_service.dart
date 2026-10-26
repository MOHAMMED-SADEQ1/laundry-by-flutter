import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/core/services/invoice_share_service.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/customer/debt_report_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// مطالبة ذمة عبر واتساب.
///
/// **لماذا هذا هو الاقتراح الأعلى أثرًا نقديًا؟** تقارير الذمم تكشف المشكلة،
/// لكن التحصيل هو ما يعيد النقد للصندوق. وأكبر عائق في التحصيل ليس عدم رغبة
/// الزبون، بل عدم معرفته أو نسيانه. الرسالة الجاهزة تُزيل هذا العائق: تكفي
/// ضغطة واحدة ليصل للزبون بيان واضح بمبلغه ومدة تأخره.
///
/// **النبرة تُختار حسب العمر**: رسالة بعد ٥ أيام لا تصلح لذمة عمرها ١٢٠ يومًا
/// (العرف: تأخير قصير = تنبيه لطيف، تأخير طويل = مطالبة رسمية جدّية).
/// التصعيد التلقائي يرفع فرص التحصيل دون أن يُحرج الزبون في البداية.
class DebtReminderService {
  DebtReminderService._();

  static final SqlDB _db = SqlDB();

  /// نطاق نبرة المطالبة بحسب عمر أقدم ذمة
  static String _toneOf(int? oldestDays) {
    final days = oldestDays ?? 0;
    if (days <= 7) return 'soft';
    if (days <= 30) return 'normal';
    if (days <= 60) return 'firm';
    return 'formal';
  }

  /// بناء نص المطالبة — يشمل المبلغ ومدة التأخر وتفصيل الفواتير المتأخرة.
  ///
  /// يُذكر كل مبلغ بفئته العمرية لأنه **يُذكّر الزبون بالتاريخ** ويُبرّر
  /// المطالبة بالمبلغ الكلي، فيقلّ الاعتراض على الرقم.
  static Future<String> buildMessage(
    CustomerAgingRow row, {
    bool includeInvoices = true,
  }) async {
    final bizName = BusinessInfoService.instance.name.isNotEmpty
        ? BusinessInfoService.instance.name
        : 'نظام المغاسل';
    final money = NumberFormat('#,##0.00', 'en');
    final tone = _toneOf(row.oldestDays);
    final lines = StringBuffer();

    // رأس الرسالة حسب النبرة
    switch (tone) {
      case 'soft':
        lines.writeln(trf('🧺 *تنبيه ودّي من {0}*', [bizName]));
        break;
      case 'normal':
        lines.writeln(trf('🧺 *تذكير بذمة قائمة — {0}*', [bizName]));
        break;
      case 'firm':
        lines.writeln(trf('⚠️ *مطالبة بذمة متأخرة — {0}*', [bizName]));
        break;
      default:
        lines.writeln(trf('📋 *مطالبة رسمية بذمة متأخرة — {0}*', [bizName]));
    }

    lines.writeln('─────────────────');
    lines.writeln(trf('عزيزنا {0}،', [row.customerName]));

    // مفتتح بحسب النبرة
    final days = row.oldestDays ?? 0;
    switch (tone) {
      case 'soft':
        lines.writeln(
          tr(
            'نأمل أن تكون بخير. لديك مبلغ متبقٍ لم يُسدَّد بعد، ونودّ تذكيرك به ودّيًا:',
          ),
        );
        break;
      case 'normal':
        lines.writeln(
          trf(
            'نود تذكيرك بأن لديك ذمة قائمة منذ {0} يومًا، ونأمل تسويتها في أقرب وقت:',
            [days],
          ),
        );
        break;
      case 'firm':
        lines.writeln(
          trf(
            'لديك ذمة متأخرة عن السداد منذ {0} يومًا. نرجو المبادرة بتسويتها وتجنّب أي إجراء لاحق:',
            [days],
          ),
        );
        break;
      default:
        lines.writeln(
          trf(
            'ذمتك القائمة لدينا تجاوزت {0} يومًا دون سداد، وهي مدة تتجاوز المدى المعتاد بشكل واضح. نطلب تسويتها فورًا أو التواصل معنا لترتيب السداد:',
            [days],
          ),
        );
    }

    lines.writeln('─────────────────');
    lines.writeln(
      trf('💰 *إجمالي الذمة: {0} ر.س*', [money.format(row.totalDebt)]),
    );
    lines.writeln(trf('📄 عدد الفواتير: {0}', [row.openInvoices]));

    // تفصيل الفواتير المتأخرة (الأقدم أولًا)
    if (includeInvoices) {
      final invoices = await _openInvoicesOf(row.customerId);
      if (invoices.isNotEmpty) {
        lines.writeln('─────────────────');
        lines.writeln(tr('*تفصيل المبالغ:*'));
        for (final inv in invoices.take(8)) {
          final id = inv['invoices_id'];
          final due = ((inv['remaining_amount'] ?? 0) as num).toDouble();
          final date = _parse(inv['invoice_date']);
          final invoiceDays = date == null ? 0 : _daysSince(date);
          final ageLabel = invoiceDays >= 91
              ? trf('متأخرة {0} يومًا', [invoiceDays])
              : trf('منذ {0} يوم', [invoiceDays]);
          lines.writeln(
            trf('• فاتورة #{0} — {1} ر.س ({2})', [
              id,
              money.format(due),
              ageLabel,
            ]),
          );
        }
        if (invoices.length > 8) {
          lines.writeln(
            trf('... و{0} فاتورة أخرى', [invoices.length - 8]),
          );
        }
      }
    }

    lines.writeln('─────────────────');
    final bizPhone = BusinessInfoService.instance.phone;
    if (bizPhone.isNotEmpty) {
      lines.writeln(trf('📞 للتواصل: {0}', [bizPhone]));
    }
    lines.writeln(trf('شكرًا لتعاونك — {0} 💙', [bizName]));

    return lines.toString();
  }

  /// الفواتير المفتوحة لزبون مرتّبة بالأقدم — تُستخدم في الرسالة والتفصيل.
  static Future<List<Map<String, dynamic>>> _openInvoicesOf(
    int customerId,
  ) async {
    try {
      return await _db.readData(
        'SELECT invoices_id, remaining_amount, invoice_date FROM invoices WHERE customer_id = ? AND subscription_id IS NULL   AND COALESCE(remaining_amount, 0) > 0.004 ORDER BY invoice_date ASC',
        [customerId],
      );
    } catch (e) {
      debugPrint('_openInvoicesOf error: $e');
      return [];
    }
  }

  /// إرسال مطالبة لزبون: يجهّز النص ثم يفتح واتساب على رقمه.
  ///
  /// إن لم يكن للزبون رقم مسجّل، نطلب الرقم ونحفظه في سجله — فلا تتوقف
  /// عملية التحصيل بسبب نقص بيانات. هذا نفس مبدأ `InvoiceShareService`
  /// حتى يتّسق السلوك في التطبيق كله.
  static Future<void> sendReminder(CustomerAgingRow row) async {
    if (row.totalDebt <= 0) {
      _info(tr('لا ذمة على هذا الزبون'));
      return;
    }

    final message = await buildMessage(row);
    final phone = row.phone.trim();

    if (phone.isEmpty) {
      await _askPhoneThenSend(row, message);
      return;
    }

    // نُعطي خيار تعديل الرسالة قبل الإرسال — المطالبة قرار تواصلي
    _showPreviewSheet(row, phone, message);
  }

  /// لوحة معاينة الرسالة قبل الإرسال (تعديل + إرسال + نسخ)
  static void _showPreviewSheet(
    CustomerAgingRow row,
    String phone,
    String message,
  ) {
    final ctrl = TextEditingController(text: message);
    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: Container(
          height: MediaQuery.of(Get.context!).size.height * 0.78,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.chat,
                          size: 19, color: Color(0xFF25D366)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trf('مطالبة {0}', [row.customerName]),
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_toneLabel(_toneOf(row.oldestDays))} · ${trf('الرقم: {0}', [phone])}',
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tr('راجع الرسالة قبل الإرسال — يمكنك تعديل أي كلمة.'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: ctrl.text),
                          );
                          _info(
                            tr('نُسخت الرسالة — يمكنك لصقها في أي تطبيق'),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(
                          tr('نسخ'),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Get.back();
                          InvoiceShareService.openWhatsAppChat(
                            phone,
                            ctrl.text,
                          );
                        },
                        icon: const Icon(Icons.send,
                            size: 17, color: Colors.white),
                        label: Text(
                          tr('إرسال عبر واتساب'),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// لا يوجد رقم: نطلبه ونحفظه في سجل الزبون ثم نُكمل
  static Future<void> _askPhoneThenSend(
    CustomerAgingRow row,
    String message,
  ) async {
    final ctrl = TextEditingController();
    final confirmed = await Get.dialog<bool>(
      Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.phone_disabled,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                tr('لا يوجد رقم لهذا الزبون'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trf(
                  'الزبون «{0}» غير مسجّل برقم جوال. أدخل الرقم ليُحفظ في سجله وتُرسل المطالبة.',
                  [row.customerName],
                ),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '05xxxxxxxx',
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(Get.context!, false),
              child: Text(
                tr('إلغاء'),
                style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              onPressed: () => Navigator.pop(Get.context!, true),
              child: Text(
                tr('حفظ وإرسال'),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      ctrl.dispose();
      return;
    }

    final phone = ctrl.text.trim();
    ctrl.dispose();
    if (phone.isEmpty) {
      _info(tr('لم يُدخَل رقم — أُلغي الإرسال'));
      return;
    }

    await _savePhone(row.customerId, phone);
    _showPreviewSheet(row, phone, message);
  }

  /// حفظ رقم الزبون في سجله (يُستدعى بعد إدخاله من نافذة المطالبة)
  static Future<void> _savePhone(int customerId, String phone) async {
    try {
      await _db.safeUpdate(
        'customers',
        {'phone_1': phone},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
    } catch (e) {
      debugPrint('_savePhone error: $e');
    }
  }

  static String _toneLabel(String tone) {
    switch (tone) {
      case 'soft':
        return tr('تنبيه ودّي');
      case 'normal':
        return tr('تذكير');
      case 'firm':
        return tr('مطالبة');
      default:
        return tr('مطالبة رسمية');
    }
  }

  static DateTime? _parse(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text) ??
        DateTime.tryParse(text.split(' ').first);
  }

  static int _daysSince(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final then = DateTime(date.year, date.month, date.day);
    return today.difference(then).inDays;
  }

  static void _info(String message) {
    Get.snackbar(
      tr('ملاحظة'),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.info,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}
