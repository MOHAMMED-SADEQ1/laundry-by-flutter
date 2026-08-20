import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/processing_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// لوحة المصنعية — تتبع حالة الفواتير من الاستلام حتى التسليم
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final ProcessingController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ProcessingController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: 'لوحة المصنعية',
        subtitle: 'تتبع الغسيل من الاستلام حتى التسليم',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Column(
          children: [
            // ─── البحث برمز الاستلام ───
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => controller.query.value = v.trim(),
                decoration: InputDecoration(
                  hintText:
                      'ابحث برمز الاستلام أو رقم الفاتورة أو اسم الزبون...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Obx(
                    () =>
                        controller.query.value.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                controller.query.value = '';
                              },
                            ),
                  ),
                ),
              ),
            ),
            // ─── التبويبات ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Obx(
                () => Row(
                  children: [
                    _TabChip(
                      label: 'قيد التنفيذ',
                      color: AppColors.info,
                      selected: controller.tab.value == 'قيد التنفيذ',
                      onTap: () => controller.tab.value = 'قيد التنفيذ',
                    ),
                    const SizedBox(width: 6),
                    _TabChip(
                      label: 'جاهز للاستلام',
                      color: AppColors.success,
                      selected: controller.tab.value == 'جاهز للاستلام',
                      onTap: () => controller.tab.value = 'جاهز للاستلام',
                    ),
                    const SizedBox(width: 6),
                    _TabChip(
                      label: 'غير مستلمة 1+ يوم',
                      color: AppColors.violet,
                      selected: controller.tab.value == 'unpicked',
                      onTap: () => controller.tab.value = 'unpicked',
                    ),
                    const SizedBox(width: 6),
                    _TabChip(
                      label: 'متأخر 3+ أيام',
                      color: AppColors.warning,
                      selected: controller.tab.value == 'overdue',
                      onTap: () => controller.tab.value = 'overdue',
                    ),
                  ],
                ),
              ),
            ),
            // ─── ملخص سريع ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FutureBuilder(
                future: controller.computeAvgCompletion(),
                builder: (context, snap) {
                  final avg = snap.data ?? '';
                  return Row(
                    children: [
                      Obx(
                        () => Text(
                          'قيد التنفيذ: ${controller.invoices.where((i) => i['status'] == 'قيد التنفيذ').length}  •  '
                          'جاهز: ${controller.invoices.where((i) => i['status'] == 'جاهز للاستلام').length}',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (avg.isNotEmpty) ...[
                        const Icon(
                          Icons.speed,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'متوسط الإنجاز: $avg',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.invoices.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  );
                }
                if (controller.invoices.isEmpty) {
                  return const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'لا توجد فواتير قيد التنفيذ',
                    subtitle:
                        'عند إصدار فواتير جديدة ستظهر هنا في لوحة المصنعية',
                  );
                }
                final list = controller.tabInvoices;
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.filter_alt_off,
                    title: 'لا توجد نتائج في هذا التبويب',
                    subtitle: 'جرّب تغيير التبويب أو كلمة البحث',
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.loadInvoices,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return FadeInUp(
                        delayMs: (index % 10) * 40,
                        child: _ProcessingCard(
                          controller: controller,
                          invoice: list[index],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  )
                  : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final ProcessingController controller;
  final Map<String, dynamic> invoice;

  const _ProcessingCard({required this.controller, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final items = controller.itemsOf(invoice);
    final status = invoice['status']?.toString() ?? 'تم الاستلام';
    final code = invoice['pickup_code']?.toString() ?? '';
    final worker = controller.workerName(invoice['assigned_to']);
    final time = controller.timeInStatus(invoice);
    final remaining =
        double.tryParse('${invoice['remaining_amount'] ?? 0}') ?? 0;
    final total = double.tryParse('${invoice['total_price'] ?? 0}') ?? 0;

    final statusColor = switch (status) {
      'قيد التنفيذ' => AppColors.info,
      'جاهز للاستلام' => AppColors.success,
      'تم التسليم' => AppColors.slate,
      _ => AppColors.warning,
    };

    return SoftCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── الرأس: الرمز + الحالة ───
          Row(
            children: [
              if (code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'رمز الاستلام: $code',
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const Spacer(),
              LabelChip(
                text: status,
                color: statusColor,
                icon: Icons.local_laundry_service,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ─── الفاتورة والزبون ───
          Row(
            children: [
              Icon(Icons.receipt_long, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'فاتورة #${invoice['invoices_id']}',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              if ((invoice['customer_name'] ?? '') != '') ...[
                Icon(
                  Icons.person_outline,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${invoice['customer_name']}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // ─── الأصناف ───
          if (items.isNotEmpty)
            Text(
              items
                      .take(3)
                      .map((i) => '${i['vestments']} ×${i['count']}')
                      .join('، ') +
                  (items.length > 3 ? ' +${items.length - 3}' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          const SizedBox(height: 6),
          // ─── معلومات الوقت والعامل ───
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 13,
                color: time.isEmpty ? AppColors.textMuted : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                time.isEmpty ? '—' : 'مدة الانتظار: $time',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: time.isEmpty ? AppColors.textMuted : AppColors.warning,
                ),
              ),
              const Spacer(),
              Text(
                'الإجمالي: ${total.toStringAsFixed(2)} ر.س',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (remaining > 0) ...[
                const SizedBox(width: 8),
                LabelChip(
                  text: 'متبقي ${remaining.toStringAsFixed(0)}',
                  color: AppColors.danger,
                  icon: Icons.error_outline,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // ─── أزرار الإجراءات ───
          Row(
            children: [
              // تعيين العامل
              Expanded(
                child: _WorkerPicker(
                  controller: controller,
                  invoice: invoice,
                  worker: worker,
                ),
              ),
              const SizedBox(width: 8),
              if (status == 'تم الاستلام')
                Expanded(
                  child: _ActionBtn(
                    label: 'بدء التنفيذ',
                    icon: Icons.play_arrow,
                    color: AppColors.info,
                    onTap:
                        () => controller.updateStatus(
                          invoice['invoices_id'],
                          'قيد التنفيذ',
                        ),
                  ),
                )
              else if (status == 'قيد التنفيذ')
                Expanded(
                  child: _ActionBtn(
                    label: 'جاهز للاستلام',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    onTap:
                        () => controller.updateStatus(
                          invoice['invoices_id'],
                          'جاهز للاستلام',
                        ),
                  ),
                )
              else if (status == 'جاهز للاستلام')
                Expanded(
                  child: _ActionBtn(
                    label: 'تسليم ${remaining > 0 ? 'وسداد $remaining' : ''}',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.success,
                    onTap: () {
                      if (remaining > 0) {
                        Get.defaultDialog(
                          title: 'سداد المتبقي',
                          middleText:
                              'على الزبون سداد ${remaining.toStringAsFixed(2)} ر.س نقداً عند الاستلام.\nهل تريد تأكيد التسليم والسداد؟',
                          textConfirm: 'تأكيد التسليم',
                          textCancel: 'إلغاء',
                          confirmTextColor: Colors.white,
                          buttonColor: AppColors.success,
                          onConfirm: () {
                            Get.back();
                            controller.deliver(invoice['invoices_id'], invoice);
                          },
                        );
                      } else {
                        controller.updateStatus(
                          invoice['invoices_id'],
                          'تم التسليم',
                        );
                      }
                    },
                  ),
                ),
              if (status == 'جاهز للاستلام' &&
                  (invoice['customer_phone'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: _NotifyWaBtn(invoice: invoice),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkerPicker extends StatelessWidget {
  final ProcessingController controller;
  final Map<String, dynamic> invoice;
  final String worker;

  const _WorkerPicker({
    required this.controller,
    required this.invoice,
    required this.worker,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return DropdownButtonFormField<int>(
        initialValue:
            invoice['assigned_to'] != null
                ? int.tryParse('${invoice['assigned_to']}')
                : null,
        isExpanded: true,
        hint: Text(
          worker.isEmpty ? 'اختر العامل' : 'العامل: $worker',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'cairo', fontSize: 11),
        ),
        items:
            controller.workers
                .map(
                  (w) => DropdownMenuItem<int>(
                    value: int.tryParse('${w['user_id']}'),
                    child: Text(
                      w['full_name']?.toString() ??
                          w['username']?.toString() ??
                          '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                )
                .toList(),
        onChanged: (v) => controller.assignWorker(invoice['invoices_id'], v),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          prefixIcon: const Icon(
            Icons.badge_outlined,
            size: 16,
            color: AppColors.secondary,
          ),
          filled: true,
          fillColor: AppColors.surfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
      );
    });
  }
}

/// إشعار واتساب للعميل عند اكتمال الغسيل
class _NotifyWaBtn extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _NotifyWaBtn({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final phone = (invoice['customer_phone'] ?? '').toString().trim();
    final code = invoice['pickup_code']?.toString() ?? '';
    return _ActionBtn(
      label: 'إشعار العميل بالجاهزية (واتساب)',
      icon: Icons.chat,
      color: const Color(0xFF25D366),
      onTap: () async {
        final msg = Uri.encodeComponent(
          '🧺 مغاسل النظارة\n'
          'السلام عليكم ${invoice['customer_name'] ?? ''}،\n'
          'غسيلكم جاهز للاستلام 💯\n'
          '📌 فاتورة #${invoice['invoices_id']}\n'
          '🔑 رمز الاستلام: $code\n'
          'ننتظركم — ر.س ${invoice['total_price']}',
        );
        final uri = Uri.parse('https://wa.me/$phone?text=$msg');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          Get.snackbar(
            'خطأ',
            'تعذر فتح واتساب — تأكد من حفظ رقم العميل',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.danger,
            colorText: Colors.white,
          );
        }
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
