import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/sqldb.dart';

// abstract class HomeController extends GetxController {}

class HomeController extends GetxController {
  late String pathfile;

  /// علَم يضمن تنفيذ تنظيف الفواتير القديمة مرة واحدة فقط لكل تشغيل،
  /// بدل تنفيذه مع كل إعادة بناء للشاشة الرئيسية.
  static bool _cleanupDone = false;

  /// آخر نتيجة تنظيف — تُعرَض مرة واحدة في الشاشة الرئيسية.
  final Rxn<InvoiceCleanupResult> lastCleanup = Rxn<InvoiceCleanupResult>();

  Future<List<Map<String, dynamic>>> readData() async {
    SqlDB db = SqlDB();
    List<Map<String, dynamic>> response = await db.readData(
      'SELECT * FROM "clothing" WHERE is_active = 1',
    );
    if (!_cleanupDone) {
      _cleanupDone = true;
      try {
        final result = await db.deleteOldInvoices();
        if (result.hasChanges) {
          lastCleanup.value = result;
          // إشعار **مرئي** بدل الحذف الصامت — المستخدم يعرف أن فواتير
          // قديمة أُزيلت ومقدارها، فيفسّر أي فرق في التقارير.
          Get.snackbar(
            'تنظيف تلقائي للفواتير',
            'أُزيلت ${result.count} فاتورة قديمة بإجمالي '
            '${NumberFormat('#,##0.00').format(result.totalAmount)} ر.س '
            'وفق سياسة الاحتفاظ بالفواتير.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.warning,
            colorText: Colors.white,
            duration: const Duration(seconds: 6),
            icon: const Icon(Icons.info_outline, color: Colors.white),
          );
        }
      } catch (e) {
        debugPrint('invoice cleanup error: $e');
      }
    }
    return response;
  }

  // ملاحظة: `emailLauncher` و`whatsappLauncher` أُزيلتا من هنا.
  // كانتا مكرّرتين: معلومات التواصل صارت في `AppInfo` (مصدر وحيد)، وفتح
  // البريد/واتساب يتم في `showDeveloperDialog` — وكانتا تُستدعيان فقط من
  // ملف ميّت (`customappdevloper.dart`) أُزيل.

  @override
  void onInit() async {
    // SqlDB db = SqlDB();
    //   int response = await db.insertData('''INSERT INTO clothing
    //   ("clothing_name","normal_washing_and_ironing_price","urgent_washing_and_ironing_price","normal_ironing_price","urgent_ironing_price")
    //    VALUES ('ثوب أبيص',5.00,7.00,3.00,3.00),
    //    ('ثوب ملون',6.00,8.00,3.00,3.00),
    //    ('ثوب صوف',7.00,10.00,3.00,3.00),
    //    ('غترة',4.00,6.00,3.00,3.00),
    //    ('شماغ',4.00,6.00,3.00,3.00),
    //    ('طاقية',1.00,2.00,1.00,1.00),
    //    ('فانيلة داخلية',3.00,5.00,1.00,2.00),
    //    ('سروال قصير',3.00,5.00,1.00,2.00),
    //    ('سروال طويل',3.00,5.00,1.00,2.00),
    //    ('جوارب',1.00,2.00,1.00,1.00),
    //    ('بدلة عسكرية',8.00,10.00,3.00,4.00),
    //    ('بدلة افرنجي',15.00,17.00,3.00,5.00),
    //    ('بدلة صوف',20.00,25.00,5.00,7.00),
    //    ('بدلة سفاري',20.00,25.00,5.00,7.00),
    //    ('بدلة رياضية',9.00,11.00,3.00,3.00),
    //    ('بدلة باكستاني',10.00,12.00,4.00,5.00),
    //    ('جاكيت',10.00,12.00,4.00,5.00),
    //    ('بنطلون',5.00,6.00,2.00,3.00),
    //    ('بنطلون صوف',6.00,8.00,2.00,3.00),
    //    ('قايش/قبعة',0.00,0.00,0.00,0.00),
    //    ('طماق',0.00,0.00,0.00,0.00),
    //    ('معطف/بالطو',5.00,7.00,2.00,3.00),
    //    ('قميص',5.00,7.00,2.00,3.00),
    //    ('بلوزة حرير',10.00,12.00,3.00,5.00),
    //    ('فستان',25.00,30.00,8.00,10.00),
    //    ('فستان حرير',40.00,45.00,10.00,12.00),
    //    ('فستان قطعتين',30.00,35.00,10.00,12.00),
    //    ('تنورة',15.00,20.00,5.00,8.00),
    //    ('بشت/فروة',4.00,6.00,3.00,3.00),
    //    ('قميص حرير',25.00,30.00,5.00,8.00),
    //    ('عباية',25.00,30.00,5.00,8.00),
    //    ('قميص نوم',5.00,7.00,2.00,3.00),
    //    ('شرشف مزدوج',7.00,10.00,2.00,3.00),
    //    ('كيس مخدة',3.00,5.00,3.00,3.00),
    //    ('شرشف مفرد',7.00,10.00,3.00,3.00),
    //    ('روب حمام',15.00,20.00,3.00,4.00),
    //    ('بيجامة',8.00,10.00,3.00,5.00),
    //    ('فانيلة صوف',5.00,6.00,2.00,3.00),
    //    ('منشفة/منديل',10.00,13.00,3.00,3.00),
    //    ('بطانية',25.00,30.00,3.00,3.00),
    //    ('مفرش',25.00,30.00,3.00,3.00),
    //    ('ستائر',25.00,30.00,3.00,3.00),
    //    ('سجاد',15.00,20.00,3.00,3.00)
    //    ''');
    super.onInit();
  }
}
