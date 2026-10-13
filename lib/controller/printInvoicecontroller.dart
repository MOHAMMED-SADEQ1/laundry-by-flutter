// ignore_for_file: file_names

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/discount/discount_service.dart';
import 'package:laundry/services/invoice/invoice_items_service.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/view/widget/invoice/customdrafts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class PrintInvoiceController extends GetxController {
  static Uint8List? logoImageBytes;
  static Uint8List? riyalImageBytes;
  static pw.Font? arabicFont;
  final SqlDB db = SqlDB();

  static Future<void> initializeAssets() async {
    try {
      await Future.wait([
        _loadPdfAssets(),
        _loadArabicFont(),
        initializeDateFormatting('ar', null),
      ]);
    } catch (e) {
      debugPrint('Error initializing PDF assets: $e');
    }
  }

  static Future<void> _loadPdfAssets() async {
    if (logoImageBytes == null) {
      final ByteData logobytes = await rootBundle.load(
        'assets/images/logo-wash.png',
      );
      logoImageBytes = logobytes.buffer.asUint8List();
    }
    if (riyalImageBytes == null) {
      final ByteData riyalbytes = await rootBundle.load(
        'assets/images/saudi_riyal.png',
      );
      riyalImageBytes = riyalbytes.buffer.asUint8List();
    }
  }

  static Future<void> _loadArabicFont() async {
    if (arabicFont == null) {
      final fontData = await rootBundle.load(
        "assets/fonts/Noto/AL-Mohanad.ttf",
      );
      arabicFont = pw.Font.ttf(fontData);
    }
  }

  final InvoiceController invcontroller = Get.find<InvoiceController>();

  /// يبني بيانات الفاتورة **مرة واحدة** لأي مقاس ورق.
  ///
  /// فصلُ بناء البيانات عن بنائها في PDF هو ما يجعل الإيصال الحراري
  /// والمستند الكبير يعرضان **نفس الأرقام** لا نسختين قد تختلفان.
  Future<Map<String, dynamic>> buildInvoicePdfData(
    String payment,
    int invoiceNumber, {
    String pickupCode = '',
    bool hidePrices = false,
    String createdByName = '',
    double discountAmount = 0,
    String discountCode = '',
    double taxAmount = 0,
    double taxRate = 0,
    double taxBase = 0,
  }) async {
    if (arabicFont == null ||
        logoImageBytes == null ||
        riyalImageBytes == null) {
      await initializeAssets();
    }
    await initializeDateFormatting('ar', null);
    final today = DateTime.now();
    String formattedTime = DateFormat('hh:mm:ss a', 'ar').format(today);
    // ─── خيارات العرض من الإعدادات (مركز واحد) ───
    final settings = AppSettingsService.instance;
    final padding = settings.invoiceNumberPadding;
    final displayNumber =
        '${settings.invoiceNumberPrefix}'
        '${padding > 0 ? invoiceNumber.toString().padLeft(padding, '0') : invoiceNumber}';
    return <String, dynamic>{
      'payment': payment,
      'logoImage': logoImageBytes!,
      'riyalImage': riyalImageBytes!,
      'arabicFont': arabicFont!,
      'invoiceItems': List.from(invcontroller.invoice),
      // المجموع يُحسب من البنود لحظة الطباعة (مصدر الحقيقة) لا من حقل مخزَّن
      'summation': invcontroller.totalValue(),
      'invoiceNumber': invoiceNumber,
      'customername': invcontroller.customername.text,
      'pickupCode': pickupCode,
      'hidePrices': hidePrices,
      'date': "${today.year}-${today.month}-${today.day}  $formattedTime",
      'bizName': BusinessInfoService.instance.name,
      'bizPhone': BusinessInfoService.instance.phone,
      'bizAddress': BusinessInfoService.instance.address,
      'bizTaxNumber': BusinessInfoService.instance.taxNumber,
      'bizCrNumber': BusinessInfoService.instance.crNumber,
      'bizShortAddress': BusinessInfoService.instance.shortAddress,
      'createdByName': createdByName,
      // ─── خيارات العرض والطباعة (تتبع شاشة الإعدادات مباشرةً) ───
      'invoiceNumberText': displayNumber,
      'invoiceTitle': settings.invoiceTitleText,
      'footerNote': settings.invoiceFooterNote,
      'paperSize': settings.invoicePaperSize,
      'showLogo': settings.invoiceShowLogo,
      'showTaxNumber': settings.invoiceShowTaxNumber,
      'showCrNumber': settings.invoiceShowCrNumber,
      'showShortAddress': settings.invoiceShowShortAddress,
      'showCashier': settings.invoiceShowCashier,
      'showDatetime': settings.invoiceShowDatetime,
      'showQr': settings.invoiceShowQr,
      // ─── تفصيل الخصم والضريبة (يُطبع كما حُفظ، لا كما يُعاد حسابه) ───
      'discountAmount': discountAmount,
      'discountCode': discountCode,
      'taxAmount': taxAmount,
      'taxRate': taxRate,
      'taxBase': taxBase,
      // المستحق بعد الخصم — هو ما يدفعه الزبون، وهو ما يُطبع لا الإجمالي
      'payable': double.parse(
        (invcontroller.totalValue() - discountAmount).toStringAsFixed(2),
      ),
    };
  }

  // تعديل دالة المشاركة لاستقبال البارامتر الجديد
  Future<void> printPDF(
    String payment,
    int invoiceNumber, {
    double paid = -1,
    String? customerName,
    int? customerId,
    String? customerPhone,
    bool hidePrices = false,
    int? subscriptionId,
    double customerBalance = 0,
    double discountAmount = 0,
    String discountCode = '',
    int? discountId,
  }) async {
    final ShiftController shiftController = Get.find<ShiftController>();

    // المجموع **مشتق من البنود** لا من الحالة المخزَّنة: كان يُقرأ
    // `invcontroller.summation.value` وهو حقل لم يكن يُحدَّث أبدًا، فكانت
    // الفاتورة تُحفظ بـ`total_price = 0` و`final_amount = 0` وتُطبع بصفر
    // رغم أن البنود وأسعارها محفوظة — خطأ محاسبي في التقارير والصندوق.
    final summation = invcontroller.totalValue();
    final name =
        (customerName ?? invcontroller.customername.text.trim()).trim();

    // جلب رقم هاتف العميل من السجل إن أمكن
    var phone = (customerPhone ?? '').trim();
    if ((customerId != null || phone.isEmpty) &&
        name.isNotEmpty &&
        customerId != null) {
      try {
        final rows = await db.safeRead(
          'customers',
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
        if (rows.isNotEmpty) {
          final p = rows.first['phone_1']?.toString() ?? '';
          if (p.isNotEmpty) phone = p;
        }
      } catch (_) {}
    }

    // فاتورة مشترك: تُحفظ بأسعارها الكاملة داخلياً، لكن تُطبع بدون أسعار
    // — القيمة تُحاسب من تغطيته الشهرية لا من الجيب.
    final isSubscriptionInvoice = payment == 'اشتراك شهري';
    final effectiveHidePrices = hidePrices || isSubscriptionInvoice;

    // الكمية المستهلكة من الفاتورة الحالية — تُحسب مرة واحدة وتُستخدم في
    // فحص السقف وفي التسجيل، حتى لا يختلف الرقم بين الفحص والتنفيذ.
    var usedPieces = 0;
    var usedValue = 0.0;
    if (isSubscriptionInvoice) {
      for (final it in invcontroller.invoice) {
        final c = int.tryParse('${it['count'] ?? 0}') ?? 0;
        usedPieces += c;
        // قيمة البند = سعر الوحدة × الكمية.
        //
        // **إصلاح:** كان يجمع `total_price + price × count` — أي يضيف
        // الإجمالي **و** تفصيله معًا، فيضخّم القيمة إلى الضعف تقريبًا.
        // هذا كان يجعل السقف المالي ينفد عند نصف الاستخدام الحقيقي.
        // نعتمد `total_price` إن وُجد (هو الإجمالي المخزَّن)، وإلا نحسبه.
        final lineTotal = double.tryParse('${it['total_price'] ?? ''}');
        if (lineTotal != null) {
          usedValue += lineTotal;
        } else {
          usedValue += (double.tryParse('${it['price'] ?? 0}') ?? 0) * c;
        }
      }
      if (usedValue <= 0) usedValue = summation;
    }

    // ═══ فحص السقف: البوابة التي كانت غائبة ═══
    // سابقًا لم يكن هناك أي حدّ: اشتراك بـ50 ريالًا يغطي غسيلًا بلا نهاية
    // (`remaining_amount = 0` دائمًا). الفحص هنا **قبل** الحفظ، لأن قيمته
    // في المنع لا في التسجيل بعد وقوع الاستهلاك.
    if (isSubscriptionInvoice && subscriptionId != null) {
      final gate = await SubscriptionService.checkGate(
        subscriptionId: subscriptionId,
        addPieces: usedPieces,
        addValue: usedValue,
      );
      if (!gate.result.allowed) {
        await db.logAudit(
          userId: SessionManager.currentUserId,
          action: 'subscription_usage_blocked',
          tableName: 'subscriptions',
          recordId: subscriptionId,
          newValues:
              '{"pieces":$usedPieces,"value":$usedValue,'
              '"reason":"${gate.result.requiresManagerOverride ? 'needs_manager' : 'no_coverage'}"}',
        );
        Get.snackbar(
          gate.result.requiresManagerOverride
              ? 'تجاوز سقف الاشتراك'
              : 'لا تغطية سارية',
          gate.result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          duration: const Duration(seconds: 6),
          icon: const Icon(Icons.block, color: Colors.white),
        );
        return;
      }
      // تحذير عند 80%: نُعلم الكاشير قبل أن يُفاجأ بالمنع في الفاتورة القادمة.
      if (gate.result.isNearLimit) {
        Get.snackbar(
          'قارب سقف الاشتراك',
          'استهلكت ${(gate.result.usageRatio * 100).round()}% من سقف هذا '
              'الاشتراك. باقٍ ${gate.remainingPieces} قطعة و'
              '${gate.remainingValue.toStringAsFixed(2)} ر.س.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFF59E0B),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.warning_amber, color: Colors.white),
        );
      }
      // تجاوز بصلاحية مدير: نُسجّله صريحًا حتى لا يمرّ صامتًا
      if (gate.result.willExceed) {
        await db.logAudit(
          userId: SessionManager.currentUserId,
          action: 'subscription_usage_override',
          tableName: 'subscriptions',
          recordId: subscriptionId,
          newValues:
              '{"pieces":$usedPieces,"value":$usedValue,"role":"'
              '${SessionManager.currentRole}"}',
        );
      }
    }

    final invoiceDate = DateTime.now().toIso8601String();
    final listData = jsonEncode(invcontroller.invoice);

    // ═══ الخصم ثم الضريبة — والترتيب محاسبي لا شكلي ═══
    //
    // الضريبة تُحسب على **الصافي بعد الخصم**، لا على الإجمالي قبل الخصم:
    // حسابها على الإجمالي ثم خصم المبلغ يجعل الزبون يدفع ضريبة على مبلغ لم
    // يشتره. والأسعار **شاملة** الضريبة، فالضريبة تُستخرج من المبلغ لا تُضاف
    // فوقه (انظر `TaxService`).
    final grossAmount = summation;
    var appliedDiscount = discountAmount > 0 ? discountAmount : 0.0;
    // سقف الحماية: لا خصم أكبر من الفاتورة — وإلا صار الإجمالي سالبًا
    if (appliedDiscount > grossAmount) appliedDiscount = grossAmount;
    appliedDiscount = double.parse(appliedDiscount.toStringAsFixed(2));
    final payable = double.parse(
      (grossAmount - appliedDiscount).toStringAsFixed(2),
    );

    // ─── الضريبة عبر السياسة الواحدة (تتبع كل خيارات الضريبة) ───
    //
    // فاتورة الاشتراك مغطّاة بتغطية مدفوعة سابقًا؛ وإخضاعها للضريبة يتبع
    // خيار `tax_apply_to_subscriptions` بدل الإعفاء الصلب (افتراضيًا معفاة).
    final taxPolicy = AppSettingsService.instance.taxPolicy;
    final tax = taxPolicy.apply(
      payable,
      isSubscription: isSubscriptionInvoice,
    );

    final paidAmount = paid >= 0 ? paid : payable;
    // فاتورة الاشتراك مغطّاة بالتغطية الشهرية: لا متبقي عليها ولا ذمة
    final remainingAmount =
        isSubscriptionInvoice
            ? 0.0
            : (payable - paidAmount) > 0
            ? payable - paidAmount
            : 0.0;
    // رمز استلام فريد 4 أرقام — متطابق لكل فاتورة دون تكرار للفواتير المتتالية
    final pickupCode = ((invoiceNumber * 7 + 3) % 10000).toString().padLeft(
      4,
      '0',
    );

    // ─── رقم الفاتورة المعروض ───
    // المفتاح الأساسي `invoices_id` يبقى الرقم المتسلسل، وهذا حقل نصّي
    // منفصل للعرض/الطباعة: بادئة اختيارية + حشو أصفار، فلا يتأثر الترقيم
    // الداخلي ولا روابط الذمم بتغيير شكل الرقم.
    final settings = AppSettingsService.instance;
    final displayNumber =
        '${settings.invoiceNumberPrefix}'
        '${settings.invoiceNumberPadding > 0 ? invoiceNumber.toString().padLeft(settings.invoiceNumberPadding, '0') : invoiceNumber.toString()}';
    if (settings.invoiceRequireCustomer &&
        (customerId == null) &&
        name.trim().isEmpty) {
      Get.snackbar(
        'زبون مطلوب',
        'إعدادات النظام تُلزم تحديد زبون قبل إصدار الفاتورة.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.person_off_outlined, color: Colors.white),
      );
      return;
    }
    // ─── الحد الأدنى للفاتورة ───
    final minOrder = settings.minOrderAmount;
    if (minOrder > 0 && payable < minOrder) {
      Get.snackbar(
        'أقل من الحد الأدنى',
        'الحد الأدنى للفاتورة ${minOrder.toStringAsFixed(2)} ر.س.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.block, color: Colors.white),
      );
      return;
    }
    // إنشاء map_data وحفظه
    final mapData = jsonEncode({
      'payment': payment,
      'summation': summation,
      'customername': name,
      'date': DateFormat('yyyy-MM-dd hh:mm:ss a', 'ar').format(DateTime.now()),
    });

    try {
      // حماية من الاستبدال الصامت: لو الرقم مستخدم مسبقاً نوقف العملية
      // بدل كتابة الفاتورة الجديدة فوق القديمة.
      final duplicate = await db.countRows(
        'invoices',
        where: 'invoices_id = ?',
        whereArgs: [invoiceNumber],
      );
      if (duplicate > 0) {
        Get.snackbar(
          'رقم فاتورة مكرر',
          'الرقم #$invoiceNumber مستخدم بالفعل — لم يتم إصدار أي فاتورة. '
              'أعد المحاولة للحصول على رقم جديد.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.error_outline, color: Colors.white),
        );
        return;
      }

      // حفظ الفاتورة في قاعدة البيانات — إدراج آمن (parameterized)
      final userId = SessionManager.currentUserId;
      final saved = await db.safeInsert('invoices', {
        'invoices_id': invoiceNumber,
        'invoice_number_text': displayNumber,
        'shift_id': shiftController.activeShiftId.value,
        'customer_name': name,
        'customer_phone': phone,
        'customer_id': customerId,
        'total_price': grossAmount,
        'discount_amount': appliedDiscount,
        'discount_code': discountCode.isEmpty ? null : discountCode,
        // `final_amount` = **المستحق على الزبون** (شامل الضريبة). يبقى بهذه
        // الدلالة عمدًا: `remaining_amount` والذمة وإجمالي المشتريات كلها
        // مشتقّة منه، فتحويله إلى صافي الإيراد كان سيُفسد الديون.
        // أمّا الإيراد **صافي الضريبة** فهو `tax_base` (الضريبة التزام على
        // المنشأة لا إيراد لها).
        'final_amount': payable,
        'tax_amount': tax.tax,
        'tax_rate': tax.rate,
        'tax_base': tax.base,
        'paid_amount': paidAmount,
        'payment_method': payment,
        'remaining_amount': remainingAmount,
        'invoice_date': invoiceDate,
        'list_data': listData,
        'map_data': mapData,
        'pickup_code': pickupCode,
        'created_by': userId,
        if (isSubscriptionInvoice && subscriptionId != null)
          'subscription_id': subscriptionId,
      });

      if (saved <= 0) {
        throw Exception('فشل حفظ الفاتورة في قاعدة البيانات');
      }

      await db.logAudit(
        userId: userId,
        action: 'invoice_create',
        tableName: 'invoices',
        recordId: invoiceNumber,
        newValues:
            '{"total":$grossAmount,"discount":$appliedDiscount,'
            '"payable":$payable,"tax":${tax.tax},"payment":"$payment"}',
      );

      // ─── 🧾 لقطة بنود الفاتورة (التكلفة التاريخية) ───
      // تُكتب **الآن** لأن لحظة الإصدار هي الفرصة الوحيدة لتجميد تكلفة
      // الوحدة. فشلُها لا يُسقط الفاتورة: التقارير ترجع للربط بالاسم.
      await InvoiceItemsService.instance.writeSnapshot(
        invoiceNumber,
        invcontroller.invoice,
      );

      // ─── 🏷️ استهلاك كود الخصم: **بعد** نجاح الحفظ فقط ───
      // لو استُهلك قبله لضاع استخدامٌ من الكود على فاتورة لم تصدر.
      if (discountId != null && appliedDiscount > 0) {
        await DiscountService.instance.consume(discountId);
        await db.logAudit(
          userId: userId,
          action: 'discount_applied',
          tableName: 'discounts',
          recordId: discountId,
          newValues:
              '{"invoice_id":$invoiceNumber,"code":"$discountCode",'
              '"amount":$appliedDiscount}',
        );
      }

      // ─── 💰 تسجيل استهلاك الاشتراك: القيمة والقطع على الفاتورة + سجل التغطية ───
      // هذا ما يجعل الإيراد **مُعترفًا به** (خدمة قُدِّمت) بدل الاكتفاء
      // بالنقدية المقبوضة، ويُغذّي فحص السقف في الفواتير القادمة.
      if (isSubscriptionInvoice && subscriptionId != null) {
        await SubscriptionService.recordUsage(
          subscriptionId: subscriptionId,
          invoiceId: invoiceNumber,
          pieces: usedPieces,
          value: usedValue,
        );
        // فاتورة الاشتراك ليست نقدية جديدة: القيمة سُدِّدت عند تسجيل الدفعة.
        // نُصفّر `paid_amount` حتى لا يُحسب المبلغ مرتين في الصندوق
        // (مرة كدفعة اشتراك ومرة كفاتورة كاش).
        await db.safeUpdate(
          'invoices',
          {'paid_amount': 0, 'remaining_amount': 0},
          where: 'invoices_id = ?',
          whereArgs: [invoiceNumber],
        );
      }

      // ─── تطبيق رصيد الزبون الموجب (credit) على الفاتورة ───
      if (customerId != null && customerBalance > 0 && !isSubscriptionInvoice) {
        // الـ credit يُخصم من المتبقي (دين) وليس من المدفوع
        final creditUsed =
            customerBalance < remainingAmount
                ? customerBalance
                : remainingAmount;
        if (creditUsed > 0) {
          final newRemaining = remainingAmount - creditUsed;
          final newPaid = paidAmount + creditUsed;
          final newBalance = customerBalance - creditUsed;

          // ─── 🔴 قاعدة ذهبية: لا تُزاد `paid_amount` بلا صف في الدفتر ───
          // هنا زاد `paid_amount` **بلا نقدية** (استهلاك سلفة). بلا هذا
          // الصف يبقى دفتر الدفعات ناقصًا: كشف الحساب يعرض «مسدَّد» أعلى من
          // مجموع دفعاته، و«استهلاك السلفة» صفرًا — رقمان لا يُفسّران.
          // الوسم `credit_use` + طريقة «رصيد» يجعل `totalCashIn` يستثنيه
          // (لا نقدية دخلت الصندوق) وهو ما يمنع عجزًا وهميًا في الإقفال.
          await db.safeInsert('customer_payments', {
            'customer_id': customerId,
            'amount': creditUsed,
            'payment_method': 'رصيد',
            'source': 'credit_use',
            'payment_date': invoiceDate,
            'notes': 'استهلاك رصيد سلفة على الفاتورة #$invoiceNumber',
            'recorded_by': userId,
            'invoice_id': invoiceNumber,
          });

          // تحديث الفاتورة: المدفوع يشمل الكاش + الـ credit
          await db.safeUpdate(
            'invoices',
            {'paid_amount': newPaid, 'remaining_amount': newRemaining},
            where: 'invoices_id = ?',
            whereArgs: [invoiceNumber],
          );
          // تحديث رصيد الزبون
          await db.safeUpdate(
            'customers',
            {'balance': newBalance},
            where: 'customer_id = ?',
            whereArgs: [customerId],
          );
          await db.logAudit(
            userId: userId,
            action: 'customer_credit_used',
            tableName: 'customers',
            recordId: customerId,
            newValues: '{"credit_used":$creditUsed,"new_balance":$newBalance}',
          );
          await db.safeInsert('customer_balance_log', {
            'customer_id': customerId,
            'change_amount': -creditUsed,
            'balance_after': newBalance,
            'reason': 'invoice_credit_use',
            'reference_id': invoiceNumber,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': userId,
          });
        }
      }

      // ─── تحديث ملخّص الزبون: إجمالي المشتريات + نقاط الولاء + الرصيد ───
      // (كان `total_spent` عمودًا ميتًا لا يُحدَّث أبدًا، والنقاط لا تُكتسب)
      if (customerId != null) {
        try {
          final currentDebt = (summation -
                  paidAmount -
                  (customerBalance > 0 ? customerBalance : 0))
              .clamp(0.0, double.infinity);

          // 1. إجمالي المشتريات = مجموع كل الفواتير المرتبطة بالزبون
          await db.updateData(
            'UPDATE "customers" SET "total_spent" = ('
            '  SELECT COALESCE(SUM(i.final_amount), 0) FROM "invoices" i '
            '  WHERE i.customer_id = ? '
            ') WHERE "customer_id" = ?',
            [customerId, customerId],
          );

          // 2. نقاط الولاء: نقطة واحدة لكل مبلغ من قيمة الفاتورة، بشرط أن يكون
          //    الخيار مُفعَّلًا في الإعدادات (`loyalty_enabled`). التعطيل
          //    يوقف النقاط والترقيات تمامًا — لا حساب ولا كتابة.
          if (!isSubscriptionInvoice &&
              AppSettingsService.instance.loyaltyEnabled) {
            final perRiyal = AppSettingsService.instance.loyaltyRate;
            final earned = (summation / perRiyal).floor();
            if (earned > 0) {
              await db.updateData(
                'UPDATE "customers" '
                'SET "loyalty_points" = COALESCE("loyalty_points", 0) + ? '
                'WHERE "customer_id" = ?',
                [earned, customerId],
              );
              // ترقية الشريحة حسب النقاط الجديدة
              await db.updateData(
                'UPDATE "customers" SET "tier" = CASE '
                '  WHEN COALESCE("loyalty_points",0) >= 1000 THEN \'gold\' '
                '  WHEN COALESCE("loyalty_points",0) >= 500 THEN \'silver\' '
                '  ELSE \'bronze\' END '
                'WHERE "customer_id" = ?',
                [customerId],
              );
            }
          }

          // 3. أعِد اشتقاق الرصيد من الفواتير — يمنع أي تباعد
          await CustomerLedgerService.instance.syncBalance(customerId);

          // 4. سجل حركة الرصيد
          final balanceNow = await db.readData(
            'SELECT balance FROM customers WHERE customer_id = ?',
            [customerId],
          );
          await db.safeInsert('customer_balance_log', {
            'customer_id': customerId,
            'change_amount': currentDebt,
            'balance_after':
                ((balanceNow.firstOrNull?['balance'] ?? 0) as num).toDouble(),
            'reason': 'invoice_create',
            'reference_id': invoiceNumber,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': userId,
          });
        } catch (e) {
          debugPrint('customer summary update error: $e');
        }
      }

      // ─── حذف المسودة المُستعادة بعد نجاح الإصدار فعلًا ───
      // المسودة تبقى في القاعدة حتى يتم الإصدار، فلو فشل الحفظ أو أغلق
      // المستخدم الشاشة لم يضِع عملُه.
      await CustomDrafts.consumePendingDraft();

      Get.snackbar(
        'نجاح',
        'تم حفظ الفاتورة رقم #$invoiceNumber وإصدارها',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      Get.snackbar(
        'خطأ',
        'تعذر حفظ الفاتورة: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
      );
      return;
    }

    try {
      // جلب اسم المستخدم الذي يصدر الفاتورة
      var createdByName = '';
      try {
        final userId = SessionManager.currentUserId;
        if (userId != null) {
          final userRows = await db.safeRead(
            'users',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          if (userRows.isNotEmpty) {
            final fn = userRows.first['full_name']?.toString().trim() ?? '';
            createdByName =
                fn.isNotEmpty
                    ? fn
                    : (userRows.first['username']?.toString() ?? '');
          }
        }
      } catch (_) {}

      // ─── لقطة واحدة **قبل** الطباعة ───
      //
      // `onLayout` قد يُستدعى أكثر من مرة (معاينة ثم تأكيد الطباعة)، وبعد
      // الطباعة تُفرَّغ سلة الفاتورة (`deleteInvoice`). فلو بُني البيانات
      // داخل الـcallback لخرج المستند الثاني **فارغًا** — وهذا خطأ صامت
      // لا يظهر إلا على بعض الطابعات.
      final snapshot = await buildInvoicePdfData(
        payment,
        invoiceNumber,
        pickupCode: pickupCode,
        hidePrices: effectiveHidePrices,
        createdByName: createdByName,
        discountAmount: appliedDiscount,
        discountCode: discountCode,
        taxAmount: tax.tax,
        taxRate: tax.rate,
        taxBase: tax.base,
      );

      // بناء مستند PDF عادي (A4) ثم إرساله لنافذة الطباعة.
      final pdfBytes = await compute(PreparePDF.generatePdfData, snapshot);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);

      invcontroller.deleteInvoice();
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      Get.snackbar('خطأ', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
