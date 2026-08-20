import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/sqldb.dart';

/// حفظ واستعادة مسودات الفواتير (فاتورة غير مكتملة)
class CustomDrafts extends StatelessWidget {
  final InvoiceController invcontroller;
  CustomDrafts({super.key, required this.invcontroller});

  final SqlDB db = SqlDB();

  Future<void> _saveDraft() async {
    if (invcontroller.invoice.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'الفاتورة فارغة — لا يوجد ما يُحفظ',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }
    final name = invcontroller.customername.text.trim();
    await db.safeInsert('invoice_drafts', {
      'customer_name': name.isEmpty ? 'بدون زبون' : name,
      'items_json': jsonEncode(List<dynamic>.from(invcontroller.invoice)),
      'total_price': invcontroller.summation.value,
      'created_at': DateTime.now().toIso8601String(),
    });
    Get.snackbar(
      'تم الحفظ',
      'حُفظت المسودة بنجاح — يمكنك استعادتها لاحقاً',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
    );
  }

  Future<void> _openDrafts() async {
    final drafts = await db.safeRead(
      'invoice_drafts',
      orderBy: 'created_at DESC',
      limit: 30,
    );
    if (drafts.isEmpty) {
      Get.snackbar(
        'لا توجد مسودات',
        'لم تحفظ أي مسودات بعد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.info,
        colorText: Colors.white,
      );
      return;
    }
    Get.dialog(
      _DraftsDialog(invcontroller: invcontroller, db: db, drafts: drafts),
      barrierColor: Colors.black54,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Get.bottomSheet(
                _DraftActionsSheet(onSave: _saveDraft, onRestore: _openDrafts),
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 6),
                Text(
                  "مسودات",
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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

class _DraftActionsSheet extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onRestore;
  const _DraftActionsSheet({required this.onSave, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: AppColors.successGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.save, color: Colors.white, size: 20),
            ),
            title: const Text(
              'حفظ المسودة الحالية',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'احفظ الفاتورة الحالية للاستكمال لاحقاً',
              style: TextStyle(fontFamily: 'cairo', fontSize: 11.5),
            ),
            onTap: () {
              Get.back();
              onSave();
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restore, color: Colors.white, size: 20),
            ),
            title: const Text(
              'استعادة مسودة محفوظة',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'اختر مسودة سابقة وتابع العمل عليها',
              style: TextStyle(fontFamily: 'cairo', fontSize: 11.5),
            ),
            onTap: () {
              Get.back();
              onRestore();
            },
          ),
        ],
      ),
    );
  }
}

class _DraftsDialog extends StatelessWidget {
  final InvoiceController invcontroller;
  final SqlDB db;
  final List<Map<String, dynamic>> drafts;

  const _DraftsDialog({
    required this.invcontroller,
    required this.db,
    required this.drafts,
  });

  void _restore(Map<String, dynamic> draft) {
    Get.back();
    try {
      final items = List<Map<String, dynamic>>.from(
        jsonDecode(draft['items_json'].toString()),
      );
      invcontroller.invoice
        ..clear()
        ..addAll(items);
      invcontroller.customername.text =
          draft['customer_name']?.toString() ?? '';
      invcontroller.update();
      db.safeDelete(
        'invoice_drafts',
        where: 'draft_id = ?',
        whereArgs: [draft['draft_id']],
      );
      Get.snackbar(
        'تم الاستعادة',
        'استُعيدت المسودة بكل بنودها',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر استعادة المسودة',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.playlist_add_check,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'المسودات المحفوظة',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: drafts.length,
                itemBuilder: (context, i) {
                  final d = drafts[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _restore(d),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.saved_search,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['customer_name'] ?? 'بدون زبون',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${d['created_at']?.toString().split('T').first ?? ''} — '
                                  '${(double.tryParse('${d['total_price'] ?? 0}') ?? 0).toStringAsFixed(2)} ر.س',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_back_ios_new,
                            size: 14,
                            color: AppColors.primary,
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
    );
  }
}
