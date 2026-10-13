import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/customer_account_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/customer/credit_guard.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customer/customer_statement_sheet.dart';

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  late final CustomerAccountController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(CustomerAccountController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: 'حساب الزبون',
        actions: Obx(() {
          if (controller.customer.value == null) return const SizedBox();
          return IconButton(
            tooltip: 'كشف الحساب',
            onPressed: () => _showStatementSheet(context),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
          );
        }),
      ),
      floatingActionButton: Obx(() {
        if (controller.customer.value == null) return const SizedBox();
        return FloatingActionButton.extended(
          onPressed: () => _showPaymentDialog(context),
          icon: const Icon(Icons.payment, color: Colors.white),
          label: const Text(
            'تسجيل دفعة',
            style: TextStyle(fontFamily: 'cairo', color: Colors.white),
          ),
          backgroundColor: AppColors.success,
        );
      }),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final cust = controller.customer.value;
          if (cust == null) {
            return const Center(
              child: Text('لا توجد بيانات', style: TextStyle(fontFamily: 'cairo')),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── معلومات الزبون ───
              _CustomerHeader(customer: cust, controller: controller),
              const SizedBox(height: 16),
              // ─── الفواتير الآجلة ───
              _DebtInvoices(invoices: controller.invoices),
              const SizedBox(height: 16),
              // ─── الأصناف التي أخذها (مجمَّعة من كل فواتيره) ───
              _ItemsTaken(controller: controller),
              // ─── سجل قطع الاشتراك الشهري ───
              _SubscriptionUsage(controller: controller),
              // ─── سجل الدفعات ───
              _PaymentHistory(payments: controller.payments),
              const SizedBox(height: 80),
            ],
          );
        }),
      ),
    );
  }

  /// كشف الحساب: طباعة · مشاركة PDF · إرسال ملخّص نصّي.
  ///
  /// القائمة نفسها مشتركة مع قائمة الزبائن وأعمار الديون عبر
  /// `showCustomerStatementSheet` — لا تُعِد بناءها هنا.
  void _showStatementSheet(BuildContext context) {
    final cust = controller.customer.value;
    final customerId = cust?['customer_id'] as int?;
    if (customerId == null) return;
    showCustomerStatementSheet(
      context,
      customerId,
      customerName: cust?['customer_name']?.toString(),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    String method = 'كاش';
    final notesCtrl = TextEditingController();

    Get.defaultDialog(
      title: 'تسجيل دفعة',
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      content: StatefulBuilder(
        builder: (context, setState) {
          final remaining = controller.totalRemaining;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المتبقي: ${remaining.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: 'ريال',
                  ),
                  style: const TextStyle(fontFamily: 'cairo'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodChip(
                        label: 'كاش',
                        icon: Icons.money,
                        selected: method == 'كاش',
                        color: AppColors.success,
                        onTap: () => setState(() => method = 'كاش'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PaymentMethodChip(
                        label: 'شبكة',
                        icon: Icons.credit_card,
                        selected: method == 'شبكة',
                        color: AppColors.info,
                        onTap: () => setState(() => method = 'شبكة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                  style: const TextStyle(fontFamily: 'cairo'),
                ),
              ],
            ),
          );
        },
      ),
      textConfirm: 'تسجيل',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.success,
      onConfirm: () async {
        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
        if (amount <= 0) {
          Get.snackbar('خطأ', 'أدخل مبلغ صحيح',
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        // إغلاق الحوار أولاً
        if (Get.isDialogOpen == true) {
          Get.back();
        }
        await controller.recordPayment(
          customerId: controller.customer.value!['customer_id'],
          amount: amount,
          paymentMethod: method,
          notes: notesCtrl.text.isNotEmpty ? notesCtrl.text.trim() : null,
        );
      },
    );
  }
}

// ─── رأس الزبون ───
class _CustomerHeader extends StatelessWidget {
  final Map<String, dynamic> customer;
  final CustomerAccountController controller;

  const _CustomerHeader({required this.customer, required this.controller});

  @override
  Widget build(BuildContext context) {
    final name = customer['customer_name']?.toString() ?? '';
    final phone = customer['phone_1']?.toString() ?? '';
    final balance = ((customer['balance'] ?? 0) as num).toDouble();

    // ─── إصلاح العرض المحاسبي ───
    // balance < 0 ⇒ الزبون مدين لنا بمقدار |balance|  (يُعرض بالأحمر)
    // balance > 0 ⇒ له سلفة عندنا (credit)              (يُعرض بالأخضر)
    // balance = 0 ⇒ مُسدَّد بالكامل
    final isDebtor = balance < 0;
    final isCreditor = balance > 0;
    final balanceLabel = isDebtor
        ? 'عليه دين'
        : isCreditor
        ? 'له رصيد (سلفة)'
        : 'الرصيد';
    final balanceValue = balance.abs();
    final limit = controller.creditLimit;
    final overLimit = controller.isOverLimit;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isCreditor
              ? AppColors.successGradient
              : isDebtor
              ? AppColors.primaryGradient
              : AppColors.successGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (phone.isNotEmpty)
                        Text(
                          phone,
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      if (limit > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            overLimit
                                ? 'تجاوز حدّ الدين (${limit.toStringAsFixed(0)} ر.س)'
                                : 'حدّ الدين: ${limit.toStringAsFixed(0)} ر.س',
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 11,
                              fontWeight:
                                  overLimit ? FontWeight.bold : FontWeight.normal,
                              color: overLimit
                                  ? const Color(0xFFFFE082)
                                  : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل حدّ الدين',
                  onPressed: () => _showCreditLimitDialog(context),
                  icon: const Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _BalanceItem(
                  label: 'الذمة الحالية',
                  value: controller.totalRemaining.toStringAsFixed(2),
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                _BalanceItem(
                  label: 'المدفوع',
                  value: controller.totalPaid.toStringAsFixed(2),
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 12),
                _BalanceItem(
                  label: balanceLabel,
                  value: balanceValue.toStringAsFixed(2),
                  color: Colors.white,
                  bold: true,
                ),
              ],
            ),

            // ─── إجمالي المشتريات + نقاط الولاء ───
            // (`total_spent` كان عمودًا في القاعدة لا يُعرض في أي شاشة —
            //  صار الآن يُحدَّث عند كل فاتورة ويُعرَض هنا كمؤشّر ولاء.)
            if (controller.totalSpent > 0 || controller.loyaltyPoints > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'إجمالي المشتريات: '
                      '${controller.totalSpent.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${controller.loyaltyPoints} نقطة',
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (controller.availableCredit > 0 &&
                controller.totalRemaining > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () => controller.applyCreditToDebts(
                    customer['customer_id'] as int,
                  ),
                  icon: const Icon(Icons.savings, size: 17),
                  label: Text(
                    'استخدم الرصيد (${controller.availableCredit.toStringAsFixed(2)}) لسداد الذمم',
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// حوار تعديل حدّ الدين الآجل
  void _showCreditLimitDialog(BuildContext context) {
    final ctrl = TextEditingController(
      text: controller.creditLimit > 0
          ? controller.creditLimit.toStringAsFixed(0)
          : '',
    );
    Get.defaultDialog(
      title: 'حدّ الدين الآجل',
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اتركه فارغًا أو صفرًا لإلغاء الحدّ',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'الحدّ الأقصى للدين',
                labelStyle: const TextStyle(fontFamily: 'cairo'),
                suffixText: 'ريال',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.speed),
              ),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      textConfirm: 'حفظ',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () async {
        final value = double.tryParse(ctrl.text.trim()) ?? 0;
        Get.back();
        // تمرير القرار عبر CreditGuard حتى يُسجَّل التغيير الائتماني في
        // سجل التدقيق (من غيّر الحدّ ومن أي قيمة إلى أي قيمة).
        final ok = await CreditGuard.setLimit(
          customerId: customer['customer_id'] as int,
          limit: value,
          userId: SessionManager.currentUserId,
        );
        if (ok) {
          await controller.loadCustomerAccount(
            customer['customer_id'] as int,
          );
          Get.snackbar(
            'تم الحفظ',
            value > 0
                ? 'حُدّد سقف الدين الآجل بمبلغ ${value.toStringAsFixed(2)} ر.س'
                : 'أُلغي سقف الدين الآجل لهذا الزبون',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            icon: const Icon(Icons.check_circle, color: Colors.white),
          );
        } else {
          Get.snackbar(
            'فشل',
            'تعذر حفظ حدّ الائتمان — أعد المحاولة',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.danger,
            colorText: Colors.white,
          );
        }
      },
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _BalanceItem({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value ريال',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── الفواتير الآجلة ───
class _DebtInvoices extends StatelessWidget {
  final List<Map<String, dynamic>> invoices;
  const _DebtInvoices({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Text(
                  'الفواتير الآجلة (${invoices.length})',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد فواتير آجلة',
                    style: TextStyle(fontFamily: 'cairo', color: Colors.grey)),
              ),
            )
          else
            ...invoices.map((inv) => _InvoiceRow(inv: inv)),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Map<String, dynamic> inv;
  const _InvoiceRow({required this.inv});

  @override
  Widget build(BuildContext context) {
    final id = inv['invoices_id'] ?? '';
    final total = ((inv['total_price'] ?? 0) as num).toDouble();
    final paid = ((inv['paid_amount'] ?? 0) as num).toDouble();
    final remaining = ((inv['remaining_amount'] ?? 0) as num).toDouble();
    final date = _formatDate(inv['invoice_date']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$id',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإجمالي: ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'مدفوع: ${paid.toStringAsFixed(2)}  ·  متبقي: ${remaining.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            date,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── سجل الدفعات ───
class _PaymentHistory extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  const _PaymentHistory({required this.payments});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.payments, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'سجل الدفعات (${payments.length})',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد دفعات مسجلة',
                    style: TextStyle(fontFamily: 'cairo', color: Colors.grey)),
              ),
            )
          else
            ...payments.map((p) => _PaymentRow(payment: p)),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final amount = ((payment['amount'] ?? 0) as num).toDouble();
    final method = payment['payment_method']?.toString() ?? 'كاش';
    final user = payment['user_name']?.toString() ?? '';
    final date = _formatDate(payment['payment_date']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              method == 'كاش' ? Icons.money : Icons.credit_card,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${amount.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      method,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (user.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.person, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        user,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            date,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── شريحة طريقة الدفع ───
class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── الأصناف التي أخذها الزبون (مجمَّعة من كل فواتيره) ───
class _ItemsTaken extends StatelessWidget {
  final CustomerAccountController controller;
  const _ItemsTaken({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.statement.value?.itemSummary ?? const [];
      if (items.isEmpty) return const SizedBox();
      final totalPieces = controller.statement.value?.totalPieces ?? 0;

      return _Panel(
        icon: Icons.checkroom,
        color: AppColors.indigo,
        title: 'الأصناف التي أخذها',
        trailing: '$totalPieces قطعة',
        child: Column(
          children: [
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        it.name,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '×${it.count}',
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 86,
                      child: Text(
                        '${it.value.toStringAsFixed(2)} ر.س',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ─── سجل قطع الاشتراك الشهري (ما غُسل فعلًا) ───
class _SubscriptionUsage extends StatelessWidget {
  final CustomerAccountController controller;
  const _SubscriptionUsage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final st = controller.statement.value;
      if (st == null || st.usages.isEmpty) return const SizedBox();

      return _Panel(
        icon: Icons.local_laundry_service,
        color: AppColors.violet,
        title: 'سجل الاشتراك الشهري',
        trailing:
            '${st.totalSubscriptionPieces} قطعة · '
            '${st.totalSubscriptionValue.toStringAsFixed(2)} ر.س',
        child: Column(
          children: [
            for (final u in st.usages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_formatDate(u.date)}  ·  اشتراك #${u.subscriptionId}'
                        '${u.invoiceId == null ? '' : '  ·  فاتورة #${u.invoiceId}'}',
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${u.pieces} قطعة',
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.violet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 86,
                      child: Text(
                        '${u.value.toStringAsFixed(2)} ر.س',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Text(
              'الاشتراك يُخصم من السقف عند كل غسلة — القطع أعلاه هي المُستهلكة فعلًا.',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─── لوحة موحّدة الشكل ───
class _Panel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String trailing;
  final Widget child;

  const _Panel({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  trailing,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── دالة مساعدة ───
String _formatDate(String? dateTimeStr) {
  if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
  try {
    final dt = DateTime.parse(dateTimeStr);
    return DateFormat('dd/MM/yyyy').format(dt);
  } catch (_) {
    return '';
  }
}
