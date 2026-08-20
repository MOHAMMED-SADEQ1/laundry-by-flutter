import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/controller/homecontroller.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/screen/invoice.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/home/customdrawer.dart';
import 'package:laundry/view/widget/home/customshowdialog.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final ShiftController shiftController = Get.put(ShiftController());
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        title: Obx(() {
          if (shiftController.isShiftActive.value) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_clock,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "وردية مفتوحة",
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  "منذ: ${shiftController.shiftStartTime.value}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontFamily: 'cairo',
                  ),
                ),
              ],
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_laundry_service, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                "مغاسل النظارة",
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'لوحة التحكم',
            onPressed: () => Get.toNamed('/dashboard'),
            icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'الفواتير السابقة',
            onPressed: () => Get.toNamed('/invoices'),
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: IconButton(
              tooltip: 'القائمة الجانبية',
              onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
      endDrawer: const CustomDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final invoice = const Invoice();
          final itemsArea = const _ItemsArea();
          final isWide = constraints.maxWidth >= 980;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: invoice),
                Expanded(flex: 5, child: itemsArea),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: itemsArea),
              const SizedBox(height: 6),
              Expanded(flex: 4, child: invoice),
            ],
          );
        },
      ),
    );
  }
}

/// منطقة الأصناف: بحث + شبكة بطاقات مع حركات دخول
class _ItemsArea extends StatefulWidget {
  const _ItemsArea();

  @override
  State<_ItemsArea> createState() => _ItemsAreaState();
}

class _ItemsAreaState extends State<_ItemsArea> {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _customerSuggestions = [];
  String _query = '';
  bool _loadingSuggestions = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── اقتراحات أسماء الزبائن من قاعدة البيانات ───
  Future<void> _loadSuggestions(String value) async {
    if (value.trim().isEmpty) {
      if (_customerSuggestions.isNotEmpty || _loadingSuggestions) {
        setState(() {
          _customerSuggestions.clear();
          _loadingSuggestions = false;
        });
      }
      return;
    }
    setState(() => _loadingSuggestions = true);
    final results = await CustomersNumberController().searchSuggestions(value);
    if (!mounted) return;
    setState(() {
      _loadingSuggestions = false;
      if (_query == value.trim()) {
        _customerSuggestions
          ..clear()
          ..addAll(results);
      }
    });
  }

  // ─── تعيين اسم الزبون المختار في الفاتورة ───
  void _selectCustomer(Map<String, dynamic> customer) {
    final invoiceCtrl =
        Get.isRegistered<InvoiceController>()
            ? Get.find<InvoiceController>()
            : Get.put(InvoiceController());
    invoiceCtrl.customername.text = customer['customer_name'];
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _customerSuggestions.clear();
      _loadingSuggestions = false;
    });
    Get.snackbar(
      'تم الاختيار',
      'تم تعيين اسم الزبون: ${customer['customer_name']}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(),
      ),
      child: Column(
        children: [
          // ─── شريط الحالة والبحث ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Flexible(
                  fit: FlexFit.loose,
                  child: SectionHeader(
                    title: 'الأصناف والخدمات',
                    icon: Icons.local_laundry_service_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      setState(() => _query = v.trim());
                      _loadSuggestions(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث عن صنف...',
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
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ─── تنبيه: لا بيع بدون وردية مفتوحة ───
          Obx(() {
            final shiftController = Get.find<ShiftController>();
            if (shiftController.isShiftActive.value) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'لا توجد وردية مفتوحة — افتح الوردية أولاً لإصدار الفواتير',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: shiftController.startShift,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          'فتح وردية',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // ─── اقتراحات أسماء الزبائن ───
          if (_customerSuggestions.isNotEmpty || _loadingSuggestions)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              constraints: const BoxConstraints(maxHeight: 210),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow(),
              ),
              child:
                  _loadingSuggestions
                      ? Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'جارٍ البحث عن الزبائن...',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              'الزبائن المقترحون — اضغط لتعيين الاسم',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _customerSuggestions.length,
                              itemBuilder: (context, i) {
                                final customer = _customerSuggestions[i];
                                final phone =
                                    customer['phone_1']?.toString() ?? '';
                                return InkWell(
                                  onTap: () => _selectCustomer(customer),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            gradient: AppColors.violetGradient,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            customer['customer_name'],
                                            style: TextStyle(
                                              fontFamily: 'cairo',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (phone.isNotEmpty)
                                          Text(
                                            phone,
                                            style: TextStyle(
                                              fontFamily: 'cairo',
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.add_circle_outline,
                                          color: AppColors.success,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
            ),
          Expanded(
            child: GetBuilder<HomeController>(
              init: HomeController(),
              builder:
                  (controller) => FutureBuilder(
                    future: controller.readData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        );
                      }
                      if (snapshot.hasError) {
                        return EmptyState(
                          icon: Icons.error_outline,
                          title: 'حدث خطأ في جلب البيانات',
                          color: AppColors.danger,
                        );
                      }
                      final data = List<Map<String, dynamic>>.from(
                        snapshot.data ?? [],
                      );
                      final filtered =
                          _query.isEmpty
                              ? data
                              : data
                                  .where(
                                    (item) => (item['clothing_name'] ?? '')
                                        .toString()
                                        .contains(_query),
                                  )
                                  .toList();

                      if (filtered.isEmpty) {
                        return EmptyState(
                          icon:
                              _query.isEmpty
                                  ? Icons.inventory_2_outlined
                                  : Icons.search_off,
                          title:
                              _query.isEmpty
                                  ? 'لا توجد أصناف'
                                  : 'لا توجد نتائج',
                          subtitle:
                              _query.isEmpty
                                  ? 'أضف الأصناف من قائمة الإضافة لبس'
                                  : 'لم نجد صنفاً يطابق البحث "$_query"',
                          action:
                              _query.isEmpty
                                  ? GradientButton(
                                    label: 'إضافة لبس',
                                    icon: Icons.add,
                                    gradient: AppColors.primaryGradient,
                                    onPressed:
                                        () => Get.toNamed('/addcategory'),
                                  )
                                  : null,
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, cons) {
                          final cols = (cons.maxWidth / 210).floor().clamp(
                            2,
                            6,
                          );
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  childAspectRatio: 2.3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return FadeInUp(
                                delayMs: (index % 12) * 40,
                                child: CustomShowDialog(data: filtered[index]),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
