import 'package:flutter/material.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/view/screen/invoice.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/home/customdrawer.dart';
import 'package:laundry/view/widget/home/catalog_refresh_button.dart';
import 'package:laundry/view/widget/home/clothing_sort_menu.dart';
import 'package:laundry/view/widget/home/customshowdialog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/widget/customer/customer_search_dialog.dart';
import 'package:laundry/services/permission/permission_catalog.dart';

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
                    Text(
                      tr("وردية مفتوحة"),
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
              // `Flexible` + الحذف: الشريط صار يحمل 4 أزرار، فلا يتجاوز الاسم
              // عرض الشاشة ويُفسد التوسيط على الهواتف الضيقة.
              Flexible(
                child: Text(
                  BusinessInfoService.instance.name.isNotEmpty
                      ? BusinessInfoService.instance.name
                      : 'نظام المغاسل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 🔄 إعادة جلب الأصناف والخدمات من القاعدة دون إعادة فتح الشاشة.
          // كل صفّ صنف يحمل خدماته الأربع، فطلب واحد يحدّث الاثنين.
          const CatalogRefreshButton(),
          // 🔎 بحث سريع عن زبون بالاسم أو رقم الجوال ← يفتح حساب الزبون.
          // الصلاحية هي نفسها صلاحية قائمة الزبائن (انظر `CustomDrawer`).
          if (PermissionService.can(PermissionKeys.customerManage))
            IconButton(
              tooltip: tr('بحث عن زبون'),
              onPressed: () => showCustomerSearchDialog(context),
              icon: const Icon(Icons.person_search, color: Colors.white),
            ),
          if (PermissionService.can(PermissionKeys.dashboardView))
            IconButton(
              tooltip: tr('لوحة التحكم'),
              onPressed: () => Get.toNamed('/dashboard'),
              icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
            ),
          IconButton(
            tooltip: tr('الفواتير السابقة'),
            onPressed: () => Get.toNamed('/invoices'),
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: IconButton(
              tooltip: tr('القائمة الجانبية'),
              onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
      endDrawer: const CustomDrawer(),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: LayoutBuilder(
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
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
                Flexible(
                  fit: FlexFit.loose,
                  child: SectionHeader(
                    title: tr('الأصناف والخدمات'),
                    icon: Icons.local_laundry_service_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    onChanged: (v) {
                      setState(() => _query = v.trim());
                    },
                    decoration: InputDecoration(
                      hintText: tr('ابحث عن صنف...'),
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
                const SizedBox(width: 8),
                // ─── ترتيب الأصناف (الفرز في القاعدة) ───
                const ClothingSortMenu(),
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
                  Expanded(
                    child: Text(
                      tr(
                        'لا توجد وردية مفتوحة — افتح الوردية أولاً لإصدار الفواتير',
                      ),
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          tr('فتح وردية'),
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
          Expanded(
            // نقرأ من الحالة التفاعلية للأصناف، فأي إضافة/تعديل/حذف ينعكس فوراً
            child: Obx(() {
              final catController = Get.put(AddCategoryController());
              // التحميل مؤجّل لما بعد الإطار: تعديل حالة تفاعلية أثناء البناء
              // داخل Obx يرفع خطأ في GetX.
              if (catController.clothing.isEmpty &&
                  !catController.isLoading.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (catController.clothing.isEmpty &&
                      !catController.isLoading.value) {
                    catController.loadClothing();
                  }
                });
              }
              final data =
                  catController.clothing
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
              // 🚨 البحث بالإنجليزية يجب أن يكون **غير حسّاس لحالة الأحرف**،
              // وإلا كتب المستخدم `thobe` فلم يجد `Thobe` المعروض أمامه.
              // نُحسب المفتاح مرّة واحدة خارج `where` لا لكل صنف.
              final q = _query.toLowerCase();
              final filtered =
                  _query.isEmpty
                      ? data
                      : data
                          .where(
                            // البحث في الاسم المعروض بلغة الواجهة، وإلا لم
                            // يجد المستخدم بالإنجليزية صنفًا يراه أمامه.
                            (item) =>
                                localized(
                                  item,
                                  'clothing_name',
                                ).toLowerCase().contains(q) ||
                                (item['clothing_name'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(q),
                          )
                          .toList();

              if (catController.isLoading.value && data.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                );
              }

              if (filtered.isEmpty) {
                return EmptyState(
                  icon:
                      _query.isEmpty
                          ? Icons.inventory_2_outlined
                          : Icons.search_off,
                  title:
                      _query.isEmpty
                          ? tr('لا توجد أصناف')
                          : tr('لا توجد نتائج'),
                  subtitle:
                      _query.isEmpty
                          ? tr('أضف الأصناف من قائمة الإضافة لبس')
                          : trf('لم نجد صنفاً يطابق البحث "{0}"', [_query]),
                  action:
                      _query.isEmpty
                          ? GradientButton(
                            label: tr('إضافة لبس'),
                            icon: Icons.add,
                            gradient: AppColors.primaryGradient,
                            onPressed: () => Get.toNamed('/addcategory'),
                          )
                          : null,
                );
              }

              return LayoutBuilder(
                builder: (context, cons) {
                  final cols = (cons.maxWidth / 210).floor().clamp(2, 6);
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
            }),
          ),
        ],
      ),
    );
  }
}
