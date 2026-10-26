import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/controller/subscriptions_controller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/customer/credit_guard.dart';
import 'package:laundry/services/discount/discount_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/subscription/subscriber_match.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// زر السداد مع اختيار نوع الدفع — تصميم عصري وآمن من الأعطال
class CustomPayInvoice extends StatelessWidget {
  final InvoiceController invcontroller;
  const CustomPayInvoice({super.key, required this.invcontroller});

  @override
  Widget build(BuildContext context) {
    final PrintInvoiceController controllerprint = Get.put(
      PrintInvoiceController(),
    );
    final ShiftController shiftController = Get.find<ShiftController>();

    return Expanded(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.successGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.softShadow(
            color: AppColors.success.withValues(alpha: 0.35),
            blur: 10,
            y: 4,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              // ─── الشرط الأول: لا بيع بدون وردية مفتوحة ───
              if (!shiftController.isShiftActive.value) {
                _showShiftRequiredDialog(shiftController);
                return;
              }

              if (invcontroller.invoice.isEmpty) {
                Get.snackbar(
                  tr('تنبيه'),
                  tr('الفاتورة فارغة — أضف أصنافاً أولاً'),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.warning,
                  colorText: Colors.white,
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                );
                return;
              }

              final int invoiceNumber =
                  await InvoiceCounterService.findInvoiceNo();

              Get.dialog(
                _PaymentMethodDialog(
                  invoiceNumber: invoiceNumber,
                  // المجموع يُحسب من البنود مباشرة (وليس من حقل مخزَّن)
                  total: invcontroller.totalValue(),
                  invoiceCustomerName: invcontroller.customername.text,
                  // القطع تُمرَّر لأن الحوار يفحص سقف الاشتراك قبل الإصدار
                  itemPieces: invcontroller.invoice.fold<int>(
                    0,
                    (s, it) =>
                        s + (int.tryParse('${it['count'] ?? 0}') ?? 0),
                  ),
                ),
                barrierColor: Colors.black54,
              ).then((result) async {
                if (result != null && result is Map<String, dynamic>) {
                  final method = result['method'] as String;
                  final paid = (result['paid'] as num).toDouble();
                  final customerId = result['customerId'] as int?;
                  final customerBalance =
                      (result['customerBalance'] as num?)?.toDouble() ?? 0;
                  final discount =
                      (result['discount'] as num?)?.toDouble() ?? 0;
                  final discountCode =
                      (result['discountCode'] as String?) ?? '';
                  final discountId = result['discountId'] as int?;

                  // فاتورة اشتراك شهري: نتحقق من التغطية النشطة ونجد الاشتراك
                  int? subscriptionId;
                  int? effectiveCustomerId = customerId;
                  String? effectiveCustomerName = result['customerName'] as String?;
                  if (method == PaymentMethod.subscription.key) {
                    final subs = Get.isRegistered<SubscriptionsController>()
                        ? Get.find<SubscriptionsController>()
                        : Get.put(SubscriptionsController());
                    await subs.loadSubscriptions();
                    final sub = subs.activeSubscriptionFor(customerId);
                    if (sub == null) {
                      Get.snackbar(
                        tr('لا يوجد اشتراك نشط'),
                        tr(
                          'هذا الزبون ليس لديه اشتراك شهري بتغطية مدفوعة — اختر طريقة دفع أخرى أو سجّل دفعة له من شاشة الاشتراكات',
                        ),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.danger,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 4),
                      );
                      return;
                    }
                    subscriptionId = sub['subscription_id'] as int;
                    // ضمان ربط الفاتورة بصاحب الاشتراك正确
                    effectiveCustomerId = sub['customer_id'] as int;
                    effectiveCustomerName = sub['customer_name']?.toString();
                  }

                  controllerprint.printPDF(
                    method,
                    invoiceNumber,
                    paid: paid,
                    customerId: effectiveCustomerId,
                    customerName: effectiveCustomerName,
                    subscriptionId: subscriptionId,
                    hidePrices: method == PaymentMethod.subscription.key,
                    customerBalance: customerBalance,
                    discountAmount: discount,
                    discountCode: discountCode,
                    discountId: discountId,
                  );
                }
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  tr('سداد'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// حوار يمنع البيع قبل فتح الوردية
  void _showShiftRequiredDialog(ShiftController shiftController) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.amberGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('لا يوجد وردية مفتوحة'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('لا يمكن إصدار أي فاتورة أو تسجيل بيع قبل فتح وردية جديدة.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        tr('إلغاء'),
                        style: TextStyle(fontFamily: 'cairo', fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: () {
                        Get.back();
                        shiftController.startShift();
                      },
                      child: Text(
                        tr('فتح وردية الآن'),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }
}

/// حوار الدفع — كاش بشبكة — آجل — مع مبالغ سريعة
class _PaymentMethodDialog extends StatefulWidget {
  final int invoiceNumber;
  final double total;
  final String invoiceCustomerName;

  /// عدد القطع في هذه الفاتورة — يُستخدم لفحص سقف الاشتراك قبل الإصدار،
  /// لأن الحوار لا يملك وصولًا إلى بنود الفاتورة الأصلية.
  final int itemPieces;

  const _PaymentMethodDialog({
    required this.invoiceNumber,
    required this.total,
    required this.invoiceCustomerName,
    this.itemPieces = 0,
  });

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  /// الطريقة المحدَّدة عند **كل** فتح للحوار.
  ///
  /// تُقرأ من إعداد «طريقة الدفع الافتراضية» الذي افتراضه الآن «شبكة»، ولا
  /// تُورَّث من جلسة سابقة: الحالة تُبنى من جديد مع كل `Get.dialog`، فيعود
  /// التحديد إلى الافتراضي مهما اختار الموظف في المرة السابقة.
  String _method = PaymentMethods.keyOf(
    AppSettingsService.instance.posDefaultPaymentMethod,
    fallback: PaymentMethod.card.key,
  );
  double _paid = 0;
  late final TextEditingController _paidCtrl;
  final SqlDB _db = SqlDB();

  // ─── العميل (إلزامي في الآجل، وفي الاشتراك لصاحب التغطية) ───
  final List<Map<String, dynamic>> _customers = [];
  bool _customersLoading = false;
  int? _debtCustomerId;
  String? _debtCustomerName;
  double _customerBalance = 0; // رصيد الزبون (موجب = له رصيد credit)

  // ─── اشتراكات الزبائن: معرّف الزبون → صفّ الاشتراك وحالته المحسوبة ───
  //
  // كنا نحتفظ بأصحاب **التغطية المدفوعة** فقط، والاشتراك المسجَّل بلا دفعة لا
  // تغطية له ⇒ كان صاحبه يختفي من القائمة تمامًا كأنه غير مسجَّل. الآن نحتفظ
  // بكل من له اشتراك نشط ونعرض حالته، ويبقى الحسم عند الإصدار.
  final Map<int, Map<String, dynamic>> _subsByCustomer =
      <int, Map<String, dynamic>>{};
  final Map<int, SubStatus> _subStatusByCustomer = <int, SubStatus>{};
  bool _subsLoading = false;

  // ─── الخصم ───
  //
  // يُطبَّق **قبل** الضريبة وبعد جمع البنود: الترتيب محاسبي — الضريبة على
  // الصافي بعد الخصم، وإلا دفع الزبون ضريبة مبلغ لم يشتره.
  final TextEditingController _discountCtrl = TextEditingController();
  double _discount = 0;
  String _discountCode = '';
  int? _discountId;
  String _discountNote = '';
  bool _discountBusy = false;
  bool _discountInvalid = false;

  /// المستحق على الزبون بعد الخصم.
  double get _payable {
    final v = widget.total - _discount;
    return v > 0 ? v : 0;
  }

  double get _remaining => (_payable - _paid) > 0 ? _payable - _paid : 0;

  /// هل طريقة الدفع الحالية اشتراك شهري؟
  bool get _isSubscription => _method == PaymentMethod.subscription.key;

  /// الزبائن المتاحون للاختيار حسب طريقة الدفع:
  /// في الاشتراك نُظهر **كل** من له اشتراك شهري مسجَّل — لا أصحاب التغطية
  /// وحدهم — لأن إخفاء غير المدفوع يجعله في عين الموظف «غير موجود»، بينما هو
  /// موجود ويحتاج فقط تسجيل دفعة أو تجديدًا.
  List<Map<String, dynamic>> get _selectableCustomers {
    if (!_isSubscription) return _customers;
    return _customers
        .where((c) => _subsByCustomer.containsKey(c['customer_id']))
        .toList();
  }

  /// حالة اشتراك الزبون المحدَّد (null = ليس من أصحاب الاشتراكات).
  SubStatus? get _selectedSubStatus =>
      _debtCustomerId == null ? null : _subStatusByCustomer[_debtCustomerId];

  /// لاحقة حالة الاشتراك داخل قائمة الاختيار — ليعرف الموظف فورًا من يمكنه
  /// إصدار فاتورة عليه ومن يحتاج دفعة أو تجديدًا قبل أن يختار.
  String _subSuffix(int? customerId) {
    if (!_isSubscription || customerId == null) return '';
    return switch (_subStatusByCustomer[customerId]) {
      SubStatus.active => tr(' — مغطّى'),
      SubStatus.capped => tr(' — بلغ سقفه'),
      SubStatus.pending => tr(' — بلا دفعة'),
      SubStatus.overdue => tr(' — منتهي'),
      SubStatus.cancelled => tr(' — ملغى'),
      null => '',
    };
  }

  /// اسم الزبون من المعرّف — بلا رمي استثناء لو غاب الصف.
  String? _customerNameOf(int? id) {
    if (id == null) return null;
    for (final c in _customers) {
      if (c['customer_id'] == id) return c['customer_name']?.toString();
    }
    return null;
  }

  /// ربط الفاتورة تلقائيًا بالزبون المكتوب — مطابقة مرنة لا حرفية فقط،
  /// والمنطق نفسه مختبَر في `SubscriberMatcher` لأنه خطأ صامت إن أخطأ.
  void _autoLinkTypedCustomer() {
    final typed = widget.invoiceCustomerName.trim();
    if (typed.isEmpty) return;
    final id = SubscriberMatcher.matchCustomerId(typed, _customers);
    if (id == null) return;
    _debtCustomerId = id;
    _debtCustomerName = _customerNameOf(id) ?? typed;
  }

  /// هل التحديد الحالي صالح للطريقة الحالية؟ (يمنع أخطاء القائمة المنسدلة)
  bool get _selectionValid =>
      _debtCustomerId != null &&
      _selectableCustomers.any((c) => c['customer_id'] == _debtCustomerId);

  /// هل الطريقة الحالية تتطلب عميلاً محدداً؟ (الآجل والاشتراك)
  bool get _needsCustomer => _method == PaymentMethod.credit.key || _isSubscription;

  /// لون حالة اختيار العميل
  Color get _customerColor {
    if (_isSubscription) {
      final st = _selectedSubStatus;
      if (_debtCustomerId == null || st == null) return AppColors.danger;
      if (st == SubStatus.active) return AppColors.success;
      if (st == SubStatus.capped) return AppColors.warning;
      return AppColors.danger;
    }
    if (_selectionValid) return AppColors.success;
    if (_needsCustomer) return AppColors.danger;
    return AppColors.info;
  }

  /// أيقونة حالة اختيار العميل
  IconData get _customerIcon {
    if (_isSubscription) {
      final st = _selectedSubStatus;
      if (_debtCustomerId == null || st == null) {
        return Icons.warning_amber_rounded;
      }
      if (st == SubStatus.active) return Icons.verified_user;
      if (st == SubStatus.capped) return Icons.speed;
      return Icons.event_busy;
    }
    if (_selectionValid) return Icons.verified_user;
    if (_needsCustomer) return Icons.warning_amber_rounded;
    return Icons.person_search;
  }

  /// نص توضيحي لحالة اختيار العميل — في الاشتراك يشرح **سبب** المنع والخطوة
  /// التالية بدل رسالة عامة تُترك الموظف يخمّن.
  String get _customerHint {
    if (_isSubscription) {
      final name = _debtCustomerName ?? '';
      return switch (_selectedSubStatus) {
        SubStatus.active => trf('تُحسم من تغطية اشتراك: {0}', [name]),
        SubStatus.capped => trf(
          '«{0}» بلغ سقف استهلاكه — التجاوز يحتاج موافقة الإدارة أو تجديدًا',
          [name],
        ),
        SubStatus.pending => trf(
          '«{0}» اشتراكه مسجَّل ولم تُسجَّل له دفعة — التغطية تبدأ من أول دفعة',
          [name],
        ),
        SubStatus.overdue =>
          trf('انتهت تغطية «{0}» — جدّد الاشتراك ليمتدّ فورًا', [name]),
        SubStatus.cancelled =>
          trf('اشتراك «{0}» ملغى بتسوية — لا تغطية سارية', [name]),
        null => tr('الاشتراك الشهري يتطلب اختيار صاحب الاشتراك من القائمة'),
      };
    }
    if (_selectionValid) {
      if (_method == PaymentMethod.credit.key) {
        return trf('سيُسجل الدين على: {0}', ['$_debtCustomerName']);
      }
      if (_customerBalance > 0) {
        return trf('الزبون: {0} — رصيد موجب: {1} ر.س', [
          '$_debtCustomerName',
          _customerBalance.toStringAsFixed(2),
        ]);
      }
      return trf('الفاتورة مرتبطة بالزبون: {0}', ['$_debtCustomerName']);
    }
    if (_method == PaymentMethod.credit.key) {
      return tr('الآجل يتطلب عميلاً محدداً من سجل الزبائن');
    }
    return tr('اختياري: اربط الفاتورة بزبون مسجّل ليظهر في كشف حسابه وواتساب');
  }

  @override
  void initState() {
    super.initState();
    _paid = widget.total;
    _paidCtrl = TextEditingController(text: widget.total.toStringAsFixed(2));
    _bootstrap();
  }

  /// تحميل الزبائن ثم اشتراكاتهم (لنعرف من يملك تغطية مدفوعة نشطة)
  Future<void> _bootstrap() async {
    await _loadCustomers();
    await _loadSubscriptions();
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  /// يتحقق من كود الخصم ويطبّقه على الفاتورة.
  ///
  /// التحقق عبر `DiscountService` (القواعد الخالصة في `DiscountRules`) لا
  /// هنا — فتكرار قواعد الصلاحية في الواجهة يجعل الواجهة والخدمة تفترقان.
  Future<void> _applyDiscount() async {
    final code = _discountCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _discountInvalid = true;
        _discountNote = tr('أدخل كود الخصم أولًا');
      });
      return;
    }
    if (!PermissionService.can(PermissionKeys.invoiceDiscountApply)) {
      setState(() {
        _discountInvalid = true;
        _discountNote = trf(
          'دورك ({0}) لا يمنح صلاحية تطبيق الخصومات',
          [tr(PermissionService.roleLabel)],
        );
      });
      return;
    }

    setState(() => _discountBusy = true);
    final check = await DiscountService.instance.check(code, widget.total);

    if (!mounted) return;
    setState(() {
      _discountBusy = false;
      _discountInvalid = !check.valid;
      if (check.valid) {
        _discount = check.amount;
        _discountCode = check.code;
        _discountId = check.discountId;
        _discountNote = check.message;
        // إعادة ضبط المدفوع على المستحق الجديد: بلا هذا يبقى المدفوع على
        // الإجمالي القديم فيظهر «مدفوع زائد» وهمي في الفاتورة.
        _paid = _method == PaymentMethod.credit.key || _isSubscription ? 0 : _payable;
        _paidCtrl.text = _paid.toStringAsFixed(2);
      } else {
        _discount = 0;
        _discountCode = '';
        _discountId = null;
        _discountNote = check.message.isEmpty
            ? tr('كود غير صالح')
            : check.message;
      }
    });
  }

  /// إلغاء الخصم وإعادة المبالغ إلى الإجمالي.
  void _clearDiscount() {
    setState(() {
      _discount = 0;
      _discountCode = '';
      _discountId = null;
      _discountNote = '';
      _discountInvalid = false;
      _discountCtrl.clear();
      _paid = _method == PaymentMethod.credit.key || _isSubscription ? 0 : _payable;
      _paidCtrl.text = _paid.toStringAsFixed(2);
    });
  }

  /// تحميل الزبائن + محاولة الربط التلقائي بالاسم المكتوب في الفاتورة
  Future<void> _loadCustomers() async {
    setState(() => _customersLoading = true);
    final rows = await _db
        .safeRead(
          'customers',
          where: 'is_active = 1',
          orderBy: 'customer_name COLLATE NOCASE ASC',
        )
        .catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    setState(() {
      _customers
        ..clear()
        ..addAll(rows);
      _customersLoading = false;
    });
    // الربط التلقائي: الزبون المكتوب في الفاتورة يُختار مسبقًا هنا، فتصبح
    // خطوة اختياره في الآجل/الاشتراك جاهزة بلا بحث يدوي.
    _autoLinkTypedCustomer();
  }

  /// تحميل كل اشتراكات الزبائن مع حالتها المحسوبة.
  ///
  /// الفرق الجوهري: كنا نجمع أصحاب **التغطية المدفوعة** فقط
  /// (`hasActiveCoverage`) فمن له اشتراك مسجَّل بلا دفعة كان يختفي من القائمة
  /// كأنه غير مسجَّل. الآن نحتفظ بالاشتراك وحالته
  /// (`active`/`capped`/`pending`/`overdue`/`cancelled`)، ونعرض الحالة في
  /// القائمة، ويبقى المنع عند الإصدار لمن لا تغطية سارية له.
  Future<void> _loadSubscriptions() async {
    setState(() => _subsLoading = true);
    try {
      final subs = Get.isRegistered<SubscriptionsController>()
          ? Get.find<SubscriptionsController>()
          : Get.put(SubscriptionsController());
      await subs.loadSubscriptions();

      final byCustomer = <int, Map<String, dynamic>>{};
      final statusByCustomer = <int, SubStatus>{};
      for (final s in subs.subscriptions) {
        final id = s['customer_id'] as int?;
        if (id == null) continue;
        final status = SubStatusX.fromCode(s['status']?.toString());
        // اشتراكان لزبون واحد (حالة يمنعها التسجيل، لكن البيانات القديمة قد
        // تحملها): نُبقي الساري أولًا حتى لا يُحجب صاحب تغطية سليمة باشتراك
        // منتهٍ أو بلا دفعة.
        if (statusByCustomer[id]?.hasLiveCoverage == true &&
            !status.hasLiveCoverage) {
          continue;
        }
        byCustomer[id] = s;
        statusByCustomer[id] = status;
      }
      if (!mounted) return;
      setState(() {
        _subsByCustomer
          ..clear()
          ..addAll(byCustomer);
        _subStatusByCustomer
          ..clear()
          ..addAll(statusByCustomer);
        _subsLoading = false;
      });
    } catch (e) {
      debugPrint('loadSubscriptions error: $e');
      if (mounted) setState(() => _subsLoading = false);
    }
  }

  void _selectMethod(String method) {
    setState(() {
      _method = method;
      if (method == PaymentMethod.card.key) {
        _paid = _payable;
      } else if (method == PaymentMethod.credit.key ||
          method == PaymentMethod.subscription.key) {
        _paid = 0;
      } else {
        _paid = _payable;
      }
      _paidCtrl.text = _paid.toStringAsFixed(2);
    });
  }

  void _applyPaid(double value) {
    _paid = value.clamp(0.0, _payable);
    _paidCtrl.text = _paid.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _confirm() async {
    // ─── البيع الآجل صلاحية مستقلّة (منح ائتمان = مخاطرة مالية) ───
    // نُمنع قبل أي فحص آخر حتى لا يُبني على أساس غير مصرّح به.
    if (_method == PaymentMethod.credit.key && !_isSubscription) {
      if (!PermissionService.can(PermissionKeys.invoiceSellOnCredit)) {
        Get.dialog(
          Directionality(
            textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      color: AppColors.danger, size: 21),
                  const SizedBox(width: 8),
                  Text(
                    tr('البيع الآجل غير مصرّح'),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 15,
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
                      'دورك الحالي ({0}) لا يمنح صلاحية تسجيل ذمة على زبون.',
                      [tr(PermissionService.roleLabel)],
                    ),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12.5,
                      height: 1.65,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 16, color: AppColors.info),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            tr(
                              'البدائل: اختر الدفع كاش أو شبكة، أو راجع مديرًا ليُسجّل الفاتورة الآجلة.',
                            ),
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11,
                              height: 1.55,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                  ),
                  onPressed: () => Get.back(),
                  child: Text(
                    tr('حسنًا'),
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
        return;
      }
    }

    // ─── الآجل والاشتراك يتطلبان عميلاً محدداً من سجل الزبائن ───
    if ((_method == PaymentMethod.credit.key || _isSubscription) && !_selectionValid) {
      Get.snackbar(
        tr('مطلوب تحديد العميل'),
        _isSubscription
            ? tr(
                'فاتورة الاشتراك تُحسم من تغطية الزبون — اختر صاحب الاشتراك من القائمة',
              )
            : tr(
                'لا يمكن تسجيل فاتورة آجلة دون اختيار عميل محدد من سجل الزبائن',
              ),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    // في الاشتراك: نتأكد أن للزبون تغطية مدفوعة نشطة، ثم نفحص **السقف**
    // قبل إصدار الفاتورة. الفحص المبكر أفضل من المنع لحظة الطباعة: الزبون
    // واقف على الكاشير، والكاشير أتمّ إدخال كل البنود بالفعل.
    if (_isSubscription) {
      final subs = Get.isRegistered<SubscriptionsController>()
          ? Get.find<SubscriptionsController>()
          : Get.put(SubscriptionsController());
      final sub = subs.activeSubscriptionFor(_debtCustomerId);
      if (sub == null) {
        // السبب معروف من الحالة المحمّلة ⇒ نقول للموظف الخطوة التالية بالضبط
        // بدل رسالة عامة تُبقيه في حيرة أمام الزبون.
        final who = _debtCustomerName ?? '';
        final reason = switch (_selectedSubStatus) {
          SubStatus.pending => trf(
            'اشتراك «{0}» مسجَّل ولم تُسجَّل له أي دفعة بعد — التغطية تبدأ من أول دفعة تُسجَّل من شاشة الاشتراكات الشهرية.',
            [who],
          ),
          SubStatus.overdue => trf(
            'انتهت تغطية اشتراك «{0}» — جدّده من شاشة الاشتراكات ليمتدّ فورًا وتستطيع إصدار فاتورته.',
            [who],
          ),
          SubStatus.capped => trf(
            'استهلك «{0}» سقف اشتراكه — جدّد الاشتراك أو ارفع السقف بموافقة الإدارة ثم أعد المحاولة.',
            [who],
          ),
          SubStatus.cancelled => trf(
            'اشتراك «{0}» أُلغي بتسوية — لا تغطية سارية له. أنشئ اشتراكًا جديدًا أو اختر طريقة دفع أخرى.',
            [who],
          ),
          _ => trf(
            'الزبون «{0}» ليس لديه اشتراك شهري بتغطية مدفوعة — سجّل دفعة له من شاشة الاشتراكات أو اختر طريقة دفع أخرى.',
            [who],
          ),
        };
        Get.snackbar(
          tr('لا يمكن إصدار فاتورة اشتراك'),
          reason,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // الكمية المستهلكة: القطع تُمرَّر من المستدعي (الحوار لا يملك بنود
      // الفاتورة)، والقيمة = إجمالي الفاتورة — وهو أدقّ من جمع `total_price`
      // لأنه يشمل أي تسعير خاص أو خصم مُطبَّق على البند.
      final addPieces = widget.itemPieces;
      // القيمة المُستهلكة = **المستحق بعد الخصم** لا الإجمالي: الاشتراك
      // يُحاسب على ما يُستهلك فعلًا، والخصم يُخفّض الاستهلاك لا السعر فقط.
      final addValue = _payable;

      final ok = await _passesUsageCheck(sub, addPieces, addValue);
      if (!ok) return;
    }
    final entered = double.tryParse(_paidCtrl.text.replaceAll(',', '.')) ?? 0;
    _paid = entered.clamp(0.0, _payable);

    // ─── فحص حدّ الائتمان قبل إتمام البيع الآجل ───
    // القاعدة: الضبط الوقائي يمنع تكوّن الدين المعدوم، لا يسجّله بعده.
    // الفحص يقع هنا — النقطة الوحيدة التي يمرّ بها كل بيع آجل.
    if (_method == PaymentMethod.credit.key && !_isSubscription && _debtCustomerId != null) {
      final remainingAfter = (_payable - _paid).clamp(0.0, _payable);
      if (remainingAfter > 0) {
        final ok = await _passesCreditCheck(remainingAfter);
        if (!ok) return;
      }
    }

    Get.back(
      result: {
        'method': _method,
        'paid': _paid,
        'customerId': _debtCustomerId,
        'customerName': _debtCustomerName,
        'customerBalance': _customerBalance,
        // الخصم يُمرَّر للفاتورة: هو ما يُحفظ ويُطبع ويُستهلك منه الكود
        'discount': _discount,
        'discountCode': _discountCode,
        'discountId': _discountId,
      },
    );
  }

  /// يفحص حدّ الائتمان ويعرض القرار. يرجع `true` إن جاز المتابعة.
  ///
  /// ثلاث حالات:
  ///   • ضمن الحد → يمرّ صامتًا (لا نُزعج المستخدم بلا سبب)
  ///   • تجاوز بصلاحية مدير → نافذة تأكيد صريحة تُبرز مبلغ التجاوز
  ///   • تجاوز بلا صلاحية → منع قاطع مع بيان السبب
  Future<bool> _passesCreditCheck(double remainingAmount) async {
    final result = await CreditGuard.check(
      customerId: _debtCustomerId!,
      remainingAmount: remainingAmount,
    );

    // ضمن الحد، أو تحذير بلا تجاوز: نمضي دون مقاطعة
    if (result.exceededBy <= 0) {
      if (result.message.isNotEmpty) {
        Get.snackbar(
          tr('تنبيه ائتماني'),
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
      return true;
    }

    // تجاوز الحد بلا صلاحية تجاوز → منع
    if (!result.allowed) {
      Get.dialog(
        Directionality(
          textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(Icons.block, color: AppColors.danger, size: 21),
                SizedBox(width: 8),
                Text(
                  tr('تجاوز حدّ الائتمان'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
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
                  result.message,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    height: 1.65,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tr(
                            'الحلول: خفّض المبلغ الآجل، أو حصّل دفعة نقدية، أو ارفع حدّ الائتمان من شاشة حساب الزبون، أو راجع مديرًا للتصديق.',
                          ),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            height: 1.55,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed(AppRoute.customerAccount, arguments: {
                    'customerId': _debtCustomerId,
                  });
                },
                child: Text(
                  tr('فتح حساب الزبون'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Get.back(),
                child: Text(
                  tr('حسنًا'),
                  style: TextStyle(
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
      return false;
    }

    // تجاوز مسموح بصلاحية مدير → تأكيد صريح
    final confirmed = await Get.dialog<bool>(
      Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 21),
              SizedBox(width: 8),
              Text(
                tr('تأكيد تجاوز حدّ الائتمان'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
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
                result.message,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12.5,
                  height: 1.65,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _creditRow(
                'الذمة الحالية',
                result.currentDebt,
                AppColors.textPrimary,
              ),
              _creditRow(
                'هذه الفاتورة الآجلة',
                result.newDebtAmount,
                AppColors.textPrimary,
              ),
              const Divider(height: 16),
              _creditRow(
                'الذمة المتوقّعة',
                result.debtAfter,
                AppColors.danger,
              ),
              _creditRow(
                'حدّ الائتمان',
                result.limit,
                AppColors.info,
              ),
              _creditRow(
                'مبلغ التجاوز',
                result.exceededBy,
                AppColors.warning,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  tr(
                    'التجاوز يُسجَّل في سجل التدقيق باسمك — تأكد أن هناك موافقة من الإدارة قبل المتابعة.',
                  ),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                tr('إلغاء'),
                style: TextStyle(fontFamily: 'cairo', fontSize: 13),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              onPressed: () => Get.back(result: true),
              child: Text(
                tr('أوافق وأُكمل البيع'),
                style: TextStyle(
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

    if (confirmed == true) {
      // أثر تدقيقي: من تجاوز، ولمن، وبكم — شرط أي رقابة ائتمانية فعّالة
      await SqlDB().logAudit(
        userId: SessionManager.currentUserId,
        action: 'credit_limit_override',
        tableName: 'customers',
        recordId: _debtCustomerId,
        newValues:
            '{"exceeded_by":${result.exceededBy},"debt_after":${result.debtAfter},"limit":${result.limit}}',
      );
      return true;
    }
    return false;
  }

  /// يفحص سقف الاشتراك ويعرض القرار. يرجع `true` إن جاز المتابعة.
  ///
  /// نفس فلسفة [_passesCreditCheck] لكن بطبقتين مركّبتين (قطع + قيمة):
  ///   • ضمن السقف → يمرّ، مع تحذير مبكّر عند 80%
  ///   • تجاوز بصلاحية مدير → تأكيد صريح يُبرز مقدار التجاوز
  ///   • تجاوز بلا صلاحية → منع قاطع، وإرشاد إلى التجديد/الترقية
  Future<bool> _passesUsageCheck(
    Map<String, dynamic> sub,
    int addPieces,
    double addValue,
  ) async {
    final subs = Get.isRegistered<SubscriptionsController>()
        ? Get.find<SubscriptionsController>()
        : Get.put(SubscriptionsController());
    final result = await subs.checkUsage(
      sub: sub,
      addPieces: addPieces,
      addValue: addValue,
    );

    // بلا سقف أو ضمن الحد: نمضي، مع تحذير غير مُعطِّل عند الاقتراب
    if (!result.willExceed) {
      if (result.isNearLimit) {
        Get.snackbar(
          tr('قارب سقف الاشتراك'),
          trf(
            'استهلك «{0}» {1}% من سقف اشتراكه. المتبقّي: {2} قطعة{3}.',
            [
              _debtCustomerName ?? '',
              '${(result.usageRatio * 100).round()}',
              '${result.limitPieces - result.usedPieces}',
              result.limitValue > 0
                  ? trf('{0} ر.س', [
                      (result.limitValue - result.usedValue).toStringAsFixed(2),
                    ])
                  : '',
            ],
          ),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
      return true;
    }

    // تجاوز بلا صلاحية → منع قاطع
    if (!result.allowed) {
      Get.dialog(
        Directionality(
          textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(Icons.block, color: AppColors.danger, size: 21),
                SizedBox(width: 8),
                Text(
                  tr('تجاوز سقف الاشتراك'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
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
                  result.message,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    height: 1.65,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (result.limitPieces > 0)
                  _usageRow(
                    tr('القطع'),
                    '${result.usedPieces} / ${result.limitPieces}',
                    '(+${result.addPieces})',
                    AppColors.info,
                  ),
                if (result.limitValue > 0)
                  _usageRow(
                    tr('القيمة'),
                    '${result.usedValue.toStringAsFixed(2)} / ${result.limitValue.toStringAsFixed(2)}',
                    '(+${result.addValue.toStringAsFixed(2)})',
                    AppColors.violet,
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tr(
                            'الحلول: سجّل تجديدًا للاشتراك من شاشة الاشتراكات (سيمدّد التغطية ويفتح سقفًا جديدًا)، أو ارفع سقف الاستخدام بموافقة الإدارة، أو اختر طريقة دفع أخرى لهذه الفاتورة.',
                          ),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Get.back(),
                child: Text(
                  tr('حسنًا'),
                  style: TextStyle(
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
      return false;
    }

    // تجاوز مسموح بصلاحية مدير → تأكيد صريح
    final confirmed = await Get.dialog<bool>(
      Directionality(
        textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 21),
              SizedBox(width: 8),
              Text(
                tr('تأكيد تجاوز سقف الاشتراك'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
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
                result.message,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12.5,
                  height: 1.65,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (result.limitPieces > 0)
                _usageRow(
                  tr('القطع'),
                  '${result.usedPieces} / ${result.limitPieces}',
                  result.exceededPieces > 0
                      ? trf('تجاوز {0}', ['${result.exceededPieces}'])
                      : '(+${result.addPieces})',
                  result.exceededPieces > 0
                      ? AppColors.danger
                      : AppColors.info,
                ),
              if (result.limitValue > 0)
                _usageRow(
                  tr('القيمة'),
                  '${result.usedValue.toStringAsFixed(2)} / ${result.limitValue.toStringAsFixed(2)}',
                  result.exceededValue > 0
                      ? trf('تجاوز {0}', [
                          result.exceededValue.toStringAsFixed(2),
                        ])
                      : '(+${result.addValue.toStringAsFixed(2)})',
                  result.exceededValue > 0
                      ? AppColors.danger
                      : AppColors.violet,
                ),
              if (result.piecesIsBinding && !result.hasNoLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    tr('الحدّ الفعلي هو عدد القطع — هو ما استُنفد أولًا.'),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  tr(
                    'التجاوز يُسجَّل في سجل التدقيق باسمك — تأكد أن هناك موافقة من الإدارة قبل المتابعة.',
                  ),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                tr('إلغاء'),
                style: TextStyle(fontFamily: 'cairo', fontSize: 13),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              onPressed: () => Get.back(result: true),
              child: Text(
                tr('أوافق وأُكمل الفاتورة'),
                style: TextStyle(
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
    return confirmed == true;
  }

  /// سطر استهلاك (مستخدم/سقف) في نافذة السقف
  Widget _usageRow(String label, String value, String hint, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(label),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            hint,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// سطر مبلغ في نافذة التأكيد
  Widget _creditRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(label),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            trf('{0} ر.س', [value.toStringAsFixed(2)]),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // المبالغ السريعة تُبنى على **المستحق بعد الخصم** لا الإجمالي، وإلا
    // اقترحت «بالضبط» مبلغًا أكبر من المطلوب فعلًا.
    final amt = _payable;
    final quick = [
      (tr('بالضبط'), amt),
      (tr('الأقرب 5'), ((amt + 4) / 5).floor() * 5.0),
      ('+10', (_paid + 10).clamp(0.0, amt)),
      ('+20', (_paid + 20).clamp(0.0, amt)),
      ('+50', (_paid + 50).clamp(0.0, amt)),
    ];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr('طريقة الدفع'),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trf('فاتورة رقم #{0} — الإجمالي {1} ر.س', [
                '${widget.invoiceNumber}',
                amt.toStringAsFixed(2),
              ]),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            // ─── سطر الخصم: يُعرض فقط عند تطبيقه ───
            if (_discount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          trf(
                            'خصم {0} ر.س{1} — الإجمالي قبل الخصم {2} ر.س',
                            [
                              _discount.toStringAsFixed(2),
                              _discountCode.isEmpty
                                  ? ''
                                  : ' ($_discountCode)',
                              widget.total.toStringAsFixed(2),
                            ],
                          ),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ─── عرض رصيد الزبون如果有 ───
            if (_customerBalance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.savings,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        trf(
                          'رصيد الزبون: {0} ر.س — سيُخصم من الفاتورة',
                          [_customerBalance.toStringAsFixed(2)],
                        ),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            // ─── طرق الدفع ───
            Row(
              children: [
                Expanded(
                  child: _PayOption(
                    label: PaymentMethod.cash.label,
                    icon: Icons.payments,
                    color: AppColors.success,
                    selected: _method == PaymentMethod.cash.key,
                    onTap: () => _selectMethod(PaymentMethod.cash.key),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PayOption(
                    label: PaymentMethod.card.label,
                    icon: Icons.credit_card,
                    color: AppColors.info,
                    selected: _method == PaymentMethod.card.key,
                    onTap: () => _selectMethod(PaymentMethod.card.key),
                  ),
                ),
                const SizedBox(width: 8),
                // الآجل يظهر فقط لمن يملك صلاحية منح الائتمان — إخفاء الخيار
                // غير المصرّح به أوضح من إظهاره ثم رفضه بعد الملء.
                if (PermissionService.can(PermissionKeys.invoiceSellOnCredit))
                  Expanded(
                    child: _PayOption(
                      label: PaymentMethod.credit.label,
                      icon: Icons.event_repeat,
                      color: AppColors.warning,
                      selected: _method == PaymentMethod.credit.key,
                      onTap: () => _selectMethod(PaymentMethod.credit.key),
                    ),
                  ),
                if (PermissionService.can(PermissionKeys.invoiceSellOnCredit)) const SizedBox(width: 8),
                Expanded(
                  child: _PayOption(
                    label: PaymentMethod.subscription.label,
                    icon: Icons.card_membership,
                    color: AppColors.violet,
                    selected: _isSubscription,
                    onTap: () => _selectMethod(PaymentMethod.subscription.key),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ─── عميل الفاتورة: إلزامي في الآجل والاشتراك، واختياري للكاش ───
            ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _customerColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _customerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_customerIcon, size: 16, color: _customerColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _customerHint,
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _customerColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _customersLoading
                        ? Padding(
                          padding: EdgeInsets.all(6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                tr('جاري تحميل الزبائن...'),
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                        : DropdownButtonFormField<int>(
                          // حماية: لو لم يعد التحديد ضمن العناصر (تغيير الطريقة)
                          // نمرّر null حتى لا تتعطّل القائمة المنسدلة
                          initialValue:
                              _selectionValid ? _debtCustomerId : null,
                          isExpanded: true,
                          hint: Text(
                            _isSubscription
                                ? (_selectableCustomers.isEmpty
                                      ? tr('لا يوجد زبون له اشتراك شهري مسجَّل')
                                      : tr('اختر صاحب الاشتراك (تُعرض حالته)'))
                                : (_customers.isEmpty
                                      ? tr('لا يوجد زبائن — أضفهم من صفحة الزبائن')
                                      : _method == PaymentMethod.credit.key
                                      ? tr('اختر العميل الذي سيسدد لاحقاً')
                                      : tr('اختر الزبون (اختياري)')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 12,
                            ),
                          ),
                          items:
                              _selectableCustomers
                                  .map(
                                    (c) => DropdownMenuItem<int>(
                                      value: c['customer_id'],
                                      child: Text(
                                        '${c['customer_name']} (${c['phone_1'] ?? '-'})${_subSuffix(c['customer_id'] as int?)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) async {
                            setState(() {
                              _debtCustomerId = v;
                              _debtCustomerName = _customerNameOf(v);
                              _customerBalance = 0;
                            });
                            // جلب رصيد الزبون
                            if (v != null) {
                              try {
                                final rows = await _db.safeRead(
                                  'customers',
                                  where: 'customer_id = ?',
                                  whereArgs: [v],
                                );
                                if (rows.isNotEmpty) {
                                  final balance =
                                      ((rows.first['balance'] ?? 0) as num)
                                          .toDouble();
                                  setState(() {
                                    _customerBalance = balance;
                                  });
                                }
                              } catch (_) {}
                            } else {
                              setState(() {
                                _customerBalance = 0;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            prefixIcon: const Icon(
                              Icons.person_search,
                              size: 17,
                              color: AppColors.warning,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                    if (!_customersLoading &&
                        !_subsLoading &&
                        _selectableCustomers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _isSubscription
                              ? tr(
                                  'لا يوجد زبون له اشتراك شهري مسجّل — سجّل اشتراكًا من شاشة الاشتراكات الشهرية',
                                )
                              : tr(
                                  'اذهب لصفحة الزبائن → أضف زبوناً ثم عد لهذا الحوار',
                                ),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ─── كود الخصم ───
            // يظهر فقط لمن يملك صلاحية الخصم: إخفاء الخيار غير المصرّح به
            // أوضح من إظهاره ثم رفضه بعد أن يُدخل الكاشير الكود أمام الزبون.
            if (PermissionService.can(PermissionKeys.invoiceDiscountApply) && !_isSubscription) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_discountInvalid
                          ? AppColors.danger
                          : AppColors.success)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_discountInvalid
                            ? AppColors.danger
                            : AppColors.success)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_offer_outlined,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tr('كود الخصم (اختياري)'),
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_discount > 0)
                          TextButton(
                            onPressed: _clearDiscount,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize: const Size(0, 28),
                            ),
                            child: Text(
                              tr('إلغاء الخصم'),
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _discountCtrl,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            onSubmitted: (_) => _applyDiscount(),
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: tr('مثال: WASH10'),
                              prefixIcon: const Icon(
                                Icons.confirmation_number_outlined,
                                size: 17,
                                color: AppColors.success,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 9,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            onPressed: _discountBusy ? null : _applyDiscount,
                            child: _discountBusy
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    tr('تطبيق'),
                                    style: TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (_discountNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _discountNote,
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _discountInvalid
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ─── المبالغ السريعة (كاش / آجل جزئي) ───
            if (_method == PaymentMethod.cash.key || _method == PaymentMethod.credit.key) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  tr('المبلغ المدفوع الآن:'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    quick.map((q) {
                      return _QuickChip(
                        label: q.$1,
                        onTap: () => _applyPaid(q.$2),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _remaining > 0
                        ? trf('المتبقي: {0} ر.س', [
                            _remaining.toStringAsFixed(2),
                          ])
                        : tr('تم سداد الإجمالي ✓'),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          _remaining > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  if (_remaining > 0)
                    Text(
                      tr('سيُسجل كذمة على الزبون'),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // ─── التأكيد ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(
                      tr('إلغاء'),
                      style: TextStyle(fontFamily: 'cairo', fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _method == PaymentMethod.credit.key
                              ? AppColors.warning
                              : _method == PaymentMethod.card.key
                              ? AppColors.info
                              : _isSubscription
                              ? AppColors.violet
                              : AppColors.success,
                    ),
                    onPressed: _confirm,
                    child: Text(
                      tr('تأكيد الإصدار'),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PayOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.78)],
                  )
                  : null,
          color: selected ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 24),
            const SizedBox(height: 6),
            Text(
              tr(label),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
