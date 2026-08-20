import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/home/customviewcaregory.dart';

class Category extends StatelessWidget {
  Category({super.key});
  GlobalKey<FormState> formstate = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: "حذف - تعديل صنف لبس",
        subtitle: 'إدارة الأسعار والخدمات',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: SectionHeaderCard(
              title: 'قائمة الأصناف والأسعار',
              icon: Icons.price_change_outlined,
            ),
          ),
          // ─── رأس الجدول ───
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              boxShadow: AppColors.softShadow(blur: 8, y: 3),
            ),
            child: const Row(
              children: [
                _HeaderCell(text: '', width: 2),
                _HeaderCell(text: 'سعر الكوي مستعجل', width: 1),
                _HeaderCell(text: 'سعر الكوي عادي', width: 1),
                _HeaderCell(text: 'سعر الغسيل مستعجل', width: 1),
                _HeaderCell(text: 'سعر الغسيل عادي', width: 1),
                _HeaderCell(text: 'اسم اللبس', width: 1, noBorder: true),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow(),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomViewCategory(),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeaderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  const SectionHeaderCard({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int width;
  final bool noBorder;
  const _HeaderCell({
    required this.text,
    required this.width,
    this.noBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: width,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            left:
                noBorder
                    ? BorderSide.none
                    : const BorderSide(color: Colors.white24),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
