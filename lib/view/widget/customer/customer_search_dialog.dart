import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// 🔎 نافذة البحث عن زبون بالاسم أو رقم الجوال — من الشاشة الرئيسية.
///
/// **لماذا نافذة لا شاشة؟** لأن الهدف «اعثر على الزبون وافتح حسابه» بلا
/// مغادرة الفاتورة الجارية؛ فتظهر النتائج أثناء الكتابة، وبمجرد الاختيار
/// تُغلق النافذة ويُفتح حساب الزبون المختار.
///
/// البحث يمرّ عبر `CustomersNumberController.searchByText` والمنطق الخالص في
/// `services/customer/customer_search.dart` — فلا نسخة ثانية من المنطق هنا.
Future<void> showCustomerSearchDialog(BuildContext context) async {
  final customerId = await Get.dialog<int>(
    const _CustomerSearchDialog(),
    barrierColor: Colors.black54,
  );
  if (customerId == null) return;
  Get.toNamed(AppRoute.customerAccount, arguments: customerId);
}

/// أرقام الزبون غير الفارغة بالترتيب (`phone_1` ثم `phone_2`).
List<String> _phonesOf(Map<String, dynamic> customer) {
  final list = <String>[];
  for (final key in const ['phone_1', 'phone_2']) {
    final value = (customer[key] ?? '').toString().trim();
    if (value.isNotEmpty) list.add(value);
  }
  return list;
}

String _initialOf(dynamic value) {
  final name = value?.toString() ?? '';
  return name.isEmpty ? '؟' : name.substring(0, 1);
}

class _CustomerSearchDialog extends StatefulWidget {
  const _CustomerSearchDialog();

  @override
  State<_CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<_CustomerSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// نسخة محلية للبحث فقط (لا تُسجَّل في GetX حتى لا تزاحم حالة الشاشات).
  final CustomersNumberController _controller = CustomersNumberController();

  final List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  Timer? _debounce;
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // التركيز بعد الإطار: لا يمكن طلب التركيز أثناء البناء الأول.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _query = query);

    if (query.isEmpty) {
      setState(() {
        _results.clear();
        _loading = false;
      });
      return;
    }

    // مهلة قصيرة: لا استعلام على القاعدة لكل حرف يكتبه المستخدم.
    _debounce = Timer(const Duration(milliseconds: 220), () => _search(query));
  }

  void _clear() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() {
      _query = '';
      _loading = false;
      _results.clear();
    });
    _focus.requestFocus();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    List<Map<String, dynamic>> rows;
    try {
      rows = await _controller.searchByText(query, limit: 30);
    } catch (e) {
      debugPrint('customer search error: $e');
      rows = const <Map<String, dynamic>>[];
    }
    // نتيجة متأخرة لنصٍّ تغيّر ⇒ تُهمَل (وإلا ظهرت نتائج لا تطابق المكتوب).
    if (!mounted || _query != query) return;
    setState(() {
      _loading = false;
      _results
        ..clear()
        ..addAll(rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            _searchField(),
            const Divider(height: 1),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('البحث عن زبون'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            tooltip: tr('إغلاق'),
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
        textDirection: appTextDirection,
        decoration: InputDecoration(
          hintText: tr('الاسم أو رقم الجوال...'),
          hintStyle: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          suffixIcon:
              _query.isEmpty
                  ? null
                  : IconButton(
                    tooltip: tr('مسح'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clear,
                  ),
          filled: true,
          fillColor: AppColors.surfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_query.isEmpty) {
      return EmptyState(
        icon: Icons.person_search,
        title: tr('ابحث عن زبون'),
        subtitle: tr(
          'اكتب اسم الزبون أو رقم جواله — يعمل البحث بأي جزء من الرقم وبأي صيغة (مسافات أو أرقام عربية).',
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: tr('لا توجد نتائج'),
        subtitle: trf(
          tr('لم نجد زبونًا يطابق «{0}» — تحقق من الاسم أو رقم الجوال.'),
          [_query],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _results.length,
      itemBuilder: (context, i) => _ResultTile(customer: _results[i]),
    );
  }
}

/// صف نتيجة واحد: الحرف الأول + الاسم + أرقام الجوال. النقر يفتح الحساب.
class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _ResultTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final id = customer['customer_id'];
    final phones = _phonesOf(customer);

    return InkWell(
      // القيمة المُعادة تُمرَّر إلى `showCustomerSearchDialog` فتفتح الحساب.
      onTap: id == null ? null : () => Get.back(result: id as int),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initialOf(customer['customer_name']),
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (customer['customer_name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 11,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          phones.isEmpty ? tr('بلا رقم') : phones.join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.account_balance_wallet,
              color: AppColors.success,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
