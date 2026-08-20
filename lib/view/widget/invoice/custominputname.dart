import 'package:flutter/material.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';

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
  bool _loading = false;

  Future<void> _loadSuggestions(String value) async {
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
    widget.valueinput.text = customer['customer_name'];
    setState(() {
      _suggestions.clear();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        children: [
          TextField(
            controller: widget.valueinput,
            style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
            onChanged: _loadSuggestions,
            decoration: InputDecoration(
              hintText: 'ابحث عن الزبون بالاسم أو أضفه يدوياً...',
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
          if (_suggestions.isNotEmpty || _loading) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 168),
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
                              'الزبائن المقترحون — اضغط للاختيار',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, i) {
                                final customer = _suggestions[i];
                                final phone =
                                    customer['phone_1']?.toString() ?? '';
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
