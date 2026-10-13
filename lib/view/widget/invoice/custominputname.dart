import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/customer/customer_search.dart';
import 'package:laundry/view/widget/customer/customaddcustomer.dart';

/// الرقمان غير الفارغين في صف واحد (`phone_1` · `phone_2`) لعرضهما في الاقتراح.
///
/// **لماذا الاثنان؟** لأن البحث يشمل حقلي الرقم، فعرض حقل واحد فقط يجعل
/// الزبون الذي طابقه الرقم الثاني يبدو «بلا رقم» في القائمة.
String _phonesLabel(Map<String, dynamic> customer) => const ['phone_1', 'phone_2']
    .map((key) => (customer[key] ?? '').toString().trim())
    .where((value) => value.isNotEmpty)
    .join('  ·  ');

/// شارة عضو مميز
class _MemberBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MemberBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل اسم الزبون مع اقتراحات حية من قاعدة البيانات
class CustomInputName extends StatefulWidget {
  final TextEditingController valueinput;
  const CustomInputName({super.key, required this.valueinput});

  @override
  State<CustomInputName> createState() => _CustomInputNameState();
}

class _CustomInputNameState extends State<CustomInputName> {
  final List<Map<String, dynamic>> _suggestions = [];
  final FocusNode _focusNode = FocusNode();
  bool _loading = false;
  /// بعد اختيار زبون نخفي لوحة الاقتراحات حتى لا تظهر «إضافة زبون» باسمه
  bool _suppressPanel = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions(String value) async {
    _suppressPanel = false;
    if (value.trim().isEmpty) {
      if (_suggestions.isNotEmpty || _loading) {
        setState(() {
          _suggestions.clear();
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    final results = await CustomersNumberController()
        .searchSuggestions(value)
        .catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted || widget.valueinput.text.trim() != value.trim()) return;
    setState(() {
      _loading = false;
      _suggestions
        ..clear()
        ..addAll(results);
    });
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    _focusNode.unfocus();
    widget.valueinput.text = customer['customer_name'];
    setState(() {
      _suggestions.clear();
      _loading = false;
      _suppressPanel = true;
    });
  }

  /// الزبون المكتوب غير مسجّل؟ نفتح نافذة إضافته ثم نعيّنه في الفاتورة
  Future<void> _addTypedCustomer() async {
    final typed = widget.valueinput.text.trim();
    if (typed.isEmpty) return;
    // لو كان النص أرقاماً نعتبره رقم هاتف، وإلا فهو اسم الزبون.
    // المنطق من `CustomerSearch` (خالص) حتى تُقبل الأرقام العربية والفواصل
    // (`٠٥٥٥-١٢٣` كان يُعامل سابقًا كاسم زبون لضيق التعبير النمطي القديم).
    final normalized = CustomerSearch.normalize(typed);
    final digits = CustomerSearch.phoneDigits(normalized);
    final isPhone =
        CustomerSearch.looksLikePhone(normalized) && digits.length >= 6;
    await showAddCustomerDialog(
      initialName: isPhone ? '' : typed,
      initialPhone: isPhone ? CustomerSearch.toWesternDigits(typed) : '',
      onAdded: (name, phone) {
        widget.valueinput.text = name;
        if (mounted) {
          setState(() {
            _suggestions.clear();
            _loading = false;
            _suppressPanel = true;
          });
        }
        Get.snackbar(
          'تمت الإضافة',
          'أُضيف الزبون «$name» وتم تعيينه في الفاتورة',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        children: [
          TextField(
            controller: widget.valueinput,
            focusNode: _focusNode,
            style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
            onChanged: _loadSuggestions,
            decoration: InputDecoration(
              hintText: 'ابحث عن الزبون بالاسم أو رقم الجوال...',
              hintStyle: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
              prefixIcon: const Icon(
                Icons.person_search,
                color: AppColors.primary,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'مسح',
                onPressed: () {
                  widget.valueinput.clear();
                  setState(() {
                    _suggestions.clear();
                    _loading = false;
                  });
                },
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
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.8,
                ),
              ),
            ),
            textAlign: TextAlign.start,
            textDirection: TextDirection.rtl,
          ),
          // ─── لوحة الاقتراحات ───
          if ((_suggestions.isNotEmpty || _loading || (widget.valueinput.text.trim().isNotEmpty && !_suppressPanel))) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow(),
              ),
              child:
                  _loading
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
                                fontSize: 11.5,
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
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              _suggestions.isEmpty
                                  ? 'لا يوجد زبون مطابق'
                                  : 'الزبائن المقترحون — اضغط للاختيار',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          // ─── زر إضافة زبون جديد عندما لا توجد نتائج ───
                          if (_suggestions.isEmpty)
                            InkWell(
                              onTap: _addTypedCustomer,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.06),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.successGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person_add_alt_1,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'إضافة "${widget.valueinput.text.trim()}" كزبون جديد',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'cairo',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          const Text(
                                            'اضغط هنا لإضافة الزبون بالاسم المكتوب',
                                            style: TextStyle(
                                              fontFamily: 'cairo',
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.add_circle,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_suggestions.isNotEmpty)
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                itemBuilder: (context, i) {
                                  final customer = _suggestions[i];
                                  // الرقمان معًا (جوال + موبايل) كما يبحث بهما
                                  // المستخدم — لا `phone_1` وحده.
                                  final phone = _phonesLabel(customer);
                                  return InkWell(
                                    onTap: () => _selectCustomer(customer),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
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
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              gradient: AppColors.violetGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              customer['customer_name'],
                                              style: TextStyle(
                                                fontFamily: 'cairo',
                                                fontSize: 12.5,
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
                                                fontSize: 10.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          if ((customer['tier'] ?? '') ==
                                              'gold') ...[
                                            const SizedBox(width: 6),
                                            const _MemberBadge(
                                              label: 'ذهبي',
                                              color: Color(0xFFF59E0B),
                                            ),
                                          ] else if ((customer['tier'] ?? '') ==
                                              'silver') ...[
                                            const SizedBox(width: 6),
                                            const _MemberBadge(
                                              label: 'فضي',
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ],
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.check_circle_outline,
                                            color: AppColors.success,
                                            size: 17,
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
          ],
        ],
      ),
    );
  }
}
