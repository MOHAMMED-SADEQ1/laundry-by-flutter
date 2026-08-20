import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';

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
                  'تنبيه',
                  'الفاتورة فارغة — أضف أصنافاً أولاً',
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
                  total: invcontroller.summation.value,
                  invoiceCustomerName: invcontroller.customername.text,
                ),
                barrierColor: Colors.black54,
              ).then((result) {
                if (result != null && result is Map<String, dynamic>) {
                  final method = result['method'] as String;
                  final paid = (result['paid'] as num).toDouble();
                  controllerprint.printPDF(
                    method,
                    invoiceNumber,
                    paid: paid,
                    customerId: result['customerId'] as int?,
                    customerName: result['customerName'] as String?,
                  );
                }
              });
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  "سداد",
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
                "لا يوجد وردية مفتوحة",
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لا يمكن إصدار أي فاتورة أو تسجيل بيع قبل فتح وردية جديدة.',
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
                      child: const Text(
                        'إلغاء',
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
                      child: const Text(
                        'فتح وردية الآن',
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
  const _PaymentMethodDialog({
    required this.invoiceNumber,
    required this.total,
    required this.invoiceCustomerName,
  });

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  String _method = 'كاش';
  double _paid = 0;
  late final TextEditingController _paidCtrl;
  final SqlDB _db = SqlDB();

  // ─── العميل (ضروري للآجل) ───
  final List<Map<String, dynamic>> _customers = [];
  bool _customersLoading = false;
  int? _debtCustomerId;
  String? _debtCustomerName;

  double get _remaining =>
      (widget.total - _paid) > 0 ? widget.total - _paid : 0;

  /// هل يوجد عميل محدد صالح للذمة؟
  bool get _hasDebtCustomer => _debtCustomerId != null;

  @override
  void initState() {
    super.initState();
    _paid = widget.total;
    _paidCtrl = TextEditingController(text: widget.total.toStringAsFixed(2));
    _loadCustomers();
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
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
    final typedName = widget.invoiceCustomerName.trim();
    if (typedName.isNotEmpty) {
      final match = _customers.where(
        (c) => (c['customer_name']?.toString() ?? '').trim() == typedName,
      );
      if (match.isNotEmpty) {
        _debtCustomerId = match.first['customer_id'];
        _debtCustomerName = typedName;
      }
    }
  }

  void _selectMethod(String method) {
    setState(() {
      _method = method;
      if (method == 'شبكة') {
        _paid = widget.total;
      } else if (method == 'آجل') {
        _paid = 0;
      } else {
        _paid = widget.total;
      }
      _paidCtrl.text = _paid.toStringAsFixed(2);
    });
  }

  void _applyPaid(double value) {
    _paid = value.clamp(0.0, widget.total);
    _paidCtrl.text = _paid.toStringAsFixed(2);
    setState(() {});
  }

  void _confirm() {
    // ─── الآجل يتطلب عميلاً محدداً من سجل الزبائن ───
    if (_method == 'آجل' && !_hasDebtCustomer) {
      Get.snackbar(
        'مطلوب تحديد العميل',
        'لا يمكن تسجيل فاتورة آجلة دون اختيار عميل محدد من سجل الزبائن',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    final entered = double.tryParse(_paidCtrl.text.replaceAll(',', '.')) ?? 0;
    _paid = entered.clamp(0.0, widget.total);
    Get.back(
      result: {
        'method': _method,
        'paid': _paid,
        'customerId': _debtCustomerId,
        'customerName': _debtCustomerName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final amt = widget.total;
    final quick = [
      ('بالضبط', amt),
      ('الأقرب 5', ((amt + 4) / 5).floor() * 5.0),
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
              "طريقة الدفع",
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "فاتورة رقم #${widget.invoiceNumber} — الإجمالي ${amt.toStringAsFixed(2)} ر.س",
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            // ─── طرق الدفع ───
            Row(
              children: [
                Expanded(
                  child: _PayOption(
                    label: "كاش",
                    icon: Icons.payments,
                    color: AppColors.success,
                    selected: _method == 'كاش',
                    onTap: () => _selectMethod('كاش'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PayOption(
                    label: "شبكة",
                    icon: Icons.credit_card,
                    color: AppColors.info,
                    selected: _method == 'شبكة',
                    onTap: () => _selectMethod('شبكة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PayOption(
                    label: "آجل",
                    icon: Icons.event_repeat,
                    color: AppColors.warning,
                    selected: _method == 'آجل',
                    onTap: () => _selectMethod('آجل'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ─── العميل المحدد للذمة (إلزامي في الآجل) ───
            if (_method == 'آجل') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      _hasDebtCustomer
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _hasDebtCustomer
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasDebtCustomer
                              ? Icons.verified_user
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color:
                              _hasDebtCustomer
                                  ? AppColors.success
                                  : AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _hasDebtCustomer
                                ? 'سيُسجل الدين على: $_debtCustomerName'
                                : 'الآجل يتطلب عميلاً محدداً من سجل الزبائن',
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color:
                                  _hasDebtCustomer
                                      ? AppColors.success
                                      : AppColors.danger,
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
                                'جاري تحميل الزبائن...',
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
                          initialValue: _debtCustomerId,
                          isExpanded: true,
                          hint: Text(
                            _customers.isEmpty
                                ? 'لا يوجد زبائن — أضفهم من صفحة الزبائن'
                                : 'اختر العميل الذي سيسدد لاحقاً',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 12,
                            ),
                          ),
                          items:
                              _customers
                                  .map(
                                    (c) => DropdownMenuItem<int>(
                                      value: c['customer_id'],
                                      child: Text(
                                        '${c['customer_name']} (${c['phone_1'] ?? '-'})',
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
                          onChanged: (v) {
                            setState(() {
                              _debtCustomerId = v;
                              final c = _customers.firstWhere(
                                (x) => x['customer_id'] == v,
                              );
                              _debtCustomerName =
                                  c['customer_name']?.toString() ?? '';
                            });
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
                    if (!_customersLoading && _customers.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'اذهب لصفحة الزبائن → أضف زبوناً ثم عد لهذا الحوار',
                          style: TextStyle(
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
            // ─── المبالغ السريعة (كاش / آجل جزئي) ───
            if (_method != 'شبكة') ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'المبلغ المدفوع الآن:',
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
                        ? 'المتبقي: ${_remaining.toStringAsFixed(2)} ر.س'
                        : 'تم سداد الإجمالي ✓',
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
                      'سيُسجل كذمة على الزبون',
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
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontFamily: 'cairo', fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _method == 'آجل'
                              ? AppColors.warning
                              : _method == 'شبكة'
                              ? AppColors.info
                              : AppColors.success,
                    ),
                    onPressed: _confirm,
                    child: const Text(
                      'تأكيد الإصدار',
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
              label,
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
