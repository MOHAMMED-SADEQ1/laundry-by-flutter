import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/previousinvoicecontroller.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/core/services/invoice_share_service.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

class PreviousInvoice extends StatefulWidget {
  const PreviousInvoice({super.key});

  @override
  State<PreviousInvoice> createState() => _PreviousInvoiceState();
}

class _PreviousInvoiceState extends State<PreviousInvoice> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _paymentFilter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PreviousInvoiceController controller = Get.put(
      PreviousInvoiceController(),
    );

    return Scaffold(
      appBar: CustomAppbar(
        title: 'الفواتير السابقة',
        subtitle: 'سجل جميع الفواتير المصدرة',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: controller.refreshData,
          child: Obx(() {
            if (controller.isLoading.value && controller.invoices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل الفواتير...',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // ─── شريط البحث والفلترة ───
            Widget tree = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الفاتورة أو اسم الزبون...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _query.isEmpty
                              ? null
                              : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _FilterChipBtn(
                        label: 'الكل',
                        selected: _paymentFilter.isEmpty,
                        color: AppColors.primary,
                        onTap: () => setState(() => _paymentFilter = ''),
                      ),
                      const SizedBox(width: 6),
                      _FilterChipBtn(
                        label: 'كاش',
                        selected: _paymentFilter == 'كاش',
                        color: AppColors.success,
                        onTap: () => setState(() => _paymentFilter = 'كاش'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChipBtn(
                        label: 'شبكة',
                        selected: _paymentFilter == 'شبكة',
                        color: AppColors.info,
                        onTap: () => setState(() => _paymentFilter = 'شبكة'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChipBtn(
                        label: 'آجل',
                        selected: _paymentFilter == 'آجل',
                        color: AppColors.warning,
                        onTap: () => setState(() => _paymentFilter = 'آجل'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChipBtn(
                        label: 'اشتراك',
                        selected: _paymentFilter == 'اشتراك شهري',
                        color: AppColors.violet,
                        onTap: () => setState(
                          () => _paymentFilter = 'اشتراك شهري',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildInvoicesList(controller)),
              ],
            );

            if (controller.invoices.isEmpty && !controller.isLoading.value) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'لا توجد فواتير متاحة',
                subtitle: 'ستظهر هنا الفواتير بعد إصدارها من الشاشة الرئيسية',
              );
            }

            return tree;
          }),
        ),
      ),
    );
  }

  Widget _buildInvoicesList(PreviousInvoiceController controller) {
    // فلترة البحث والدفع
    final List<Map<String, dynamic>> visible = [];
    for (final inv in controller.invoices) {
      Map<String, dynamic> mapdata = {};
      try {
        mapdata = inv['map_data'] != null ? jsonDecode(inv['map_data']) : {};
      } catch (_) {}
      final payment = (mapdata['payment'] ?? '').toString();
      final customer = (mapdata['customername'] ?? '').toString();
      final num = inv['invoices_id']?.toString() ?? '';

      if (_paymentFilter.isNotEmpty && payment != _paymentFilter) continue;
      if (_query.isNotEmpty &&
          !num.contains(_query) &&
          !customer.contains(_query)) {
        continue;
      }
      visible.add({'invoice': inv, 'mapdata': mapdata});
    }

    if (visible.isEmpty) {
      return Expanded(
        child: EmptyState(
          icon: Icons.search_off,
          title: 'لا توجد نتائج مطابقة',
          subtitle: 'جرّب تغيير كلمة البحث أو الفلتر',
        ),
      );
    }

    return ListView.builder(
      controller: controller.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
      itemCount: visible.length + (controller.hasMore.value ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                controller.loadingMessage.value,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        final entry = visible[index];
        final invoice = entry['invoice'] as Map<String, dynamic>;
        final mapdata = entry['mapdata'] as Map<String, dynamic>;
        List<Map<String, dynamic>> listdata = [];
        try {
          listdata = List<Map<String, dynamic>>.from(
            json.decode(invoice['list_data']),
          );
        } catch (_) {}

        return FadeInUp(
          delayMs: (index % 10) * 40,
          child: _InvoiceCard(
            invoice: invoice,
            listdata: listdata,
            mapdata: mapdata,
          ),
        );
      },
    );
  }
}

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChipBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  )
                  : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// زر مشاركة الفاتورة عبر واتساب — يرسل مباشرة لرقم الزبون إن وُجد
class _WhatsAppShareBtn extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> listdata;
  final Map<String, dynamic> mapdata;

  const _WhatsAppShareBtn({
    required this.invoice,
    required this.listdata,
    required this.mapdata,
  });

  Future<void> _share() async {
    // نستخدم خدمة المشاركة المركزية: تُنظّف الرقم لصيغة واتساب الدولية
    // (05xxxxxxxx → 9665xxxxxxxx) وتبني الرسالة موحّدة مع بقية الشاشات.
    //
    // **الخطأ السابق:** كان يرسل `wa.me/$cleanPhone` بالأرقام الخام بلا
    // رمز الدولة. واتساب يتجاهل الرقم المحلي بلا كود دولي فلا تُسلَّم
    // الرسالة — وهي المشكلة الجوهرية في زر الواتساب.
    await InvoiceShareService.sendInvoiceToCustomer(invoice);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _share,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF25D366), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, color: Color(0xFF25D366), size: 13),
            SizedBox(width: 4),
            Text(
              'واتساب',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: Color(0xFF25D366),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> listdata;
  final Map<String, dynamic> mapdata;

  const _InvoiceCard({
    required this.invoice,
    required this.listdata,
    required this.mapdata,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = mapdata['payment'] == 'كاش';
    final paymentColor = isCash ? AppColors.success : AppColors.info;
    final total = double.tryParse(mapdata['summation']?.toString() ?? '0') ?? 0;

    return SoftCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── الشريط الجانبي ───
            Container(
              width: 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [paymentColor, paymentColor.withValues(alpha: 0.4)],
                ),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(16),
                ),
              ),
            ),
            // ─── المحتوى ───
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.receipt,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'فاتورة #${invoice['invoices_id']}',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        LabelChip(
                          text: mapdata['payment'] ?? 'كاش',
                          color: paymentColor,
                          icon: isCash ? Icons.payments : Icons.credit_card,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          mapdata['date'] ?? '',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if ((mapdata['customername'] ?? '') != '') ...[
                          const SizedBox(width: 14),
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              mapdata['customername'],
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ─── البنود ───
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child:
                            listdata.isEmpty
                                ? const SizedBox.shrink()
                                : ListView(
                                  children:
                                      listdata.take(3).map((item) {
                                          return Text(
                                            '• ${item['vestments']} (${item['content']}) — ${item['count']} × ${item['price']}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'cairo',
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                              height: 1.4,
                                            ),
                                          );
                                        }).toList()
                                        ..addAll(
                                          listdata.length > 3
                                              ? [
                                                Text(
                                                  '... و${listdata.length - 3} أصناف أخرى',
                                                  style: TextStyle(
                                                    fontFamily: 'cairo',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ]
                                              : const [],
                                        ),
                                ),
                      ),
                    ),
                    // ─── التذييل ───
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final data = {
                              'payment': mapdata['payment'],
                              'logoImage':
                                  PrintInvoiceController.logoImageBytes!,
                              'riyalImage':
                                  PrintInvoiceController.riyalImageBytes!,
                              'arabicFont': PrintInvoiceController.arabicFont!,
                              'invoiceItems': listdata,
                              'summation': mapdata['summation'],
                              'invoiceNumber': invoice['invoices_id'],
                              'customername': mapdata['customername'],
                              'date': mapdata['date'],
                              'bizName': BusinessInfoService.instance.name,
                              'bizPhone': BusinessInfoService.instance.phone,
                              'bizAddress': BusinessInfoService.instance.address,
                              'createdByName': '',
                            };
                            Get.find<PreviousInvoiceController>().printPDF(
                              data,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.print,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'طباعة',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        _WhatsAppShareBtn(
                          invoice: invoice,
                          listdata: listdata,
                          mapdata: mapdata,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${total.toStringAsFixed(2)} ر.س',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'cairo',
                            color: paymentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
