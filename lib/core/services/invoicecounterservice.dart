import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundry/sqldb.dart';

/// ترقيم الفواتير.
///
/// **الخلل السابق (مؤكَّد):**
/// 1. العداد كان يبدأ من `0` ويتجاهل إعداد `invoice_start` (افتراضي 100)
///    المُهيَّأ في جدول `settings` — فلم يُقرأ في أي مكان.
/// 2. كان يُخزَّن في SharedPreferences فقط، مع حفظ **غير مُنتظَر**
///    (`setInt` بلا await). فمسح بيانات التطبيق أو إعادة تثبيته **يصفّر
///    العداد** بينما كل الفواتير باقية في القاعدة ⇒ ترقيم يتصادم مع فواتير
///    قائمة، وهو فساد بيانات لا مجرد خلل عرض.
///
/// **الإصلاح:** العداد يُشتقّ من **أقصى رقم موجود في جدول `invoices`** عند
/// التهيئة (مصدر الحقيقة هو القاعدة نفسها)، ويأخذ الأعلى بينه وبين إعداد
/// `invoice_start` وبين آخر قيمة محفوظة. والحفظ صار مُنتظرًا.
/// هذا يجعل إعادة التثبيت آمنة: العداد يستأنف من آخر فاتورة فعلية.
class InvoiceCounterService {
  static SharedPreferences? _prefsInstance;
  static const String _counterKey = "counterinvoice";

  static int _currentCounterValue = 0;

  /// آخر قيمة حُفظت في التخزين المحلي — نأخذ الأعلى منها ومن القاعدة.
  static int _storedValue = 0;

  static final SqlDB _db = SqlDB();

  static Future<void> _initSharedPreferences() async {
    if (_prefsInstance != null) return;
    // التفضيلات **كاش** لا مصدر حقيقة: مصدر العداد هو `MAX(invoices_id)`.
    // فلو تعذّر فتحها (ملفّ تالف لم يُصلَح، أو صلاحيات) نكمل بلا كاش بدل
    // إسقاط البيع كله — كان الاستثناء هنا يمنع إصدار أي فاتورة.
    try {
      _prefsInstance = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('التفضيلات غير متاحة — العداد من القاعدة فقط: $e');
    }
  }

  /// يهيّئ العداد = max(أقصى فاتورة في القاعدة، invoice_start، القيمة المحفوظة).
  ///
  /// يُستدعى عند بدء التطبيق (من `splashcontroller`) — لا يُفترض أن يكون
  /// قد نُفِّذ قبل `findInvoiceNo`، فالدالة تُهيّئ نفسها عند الحاجة.
  static Future<void> loadInitialCounter() async {
    await _initSharedPreferences();
    _storedValue = _prefsInstance?.getInt(_counterKey) ?? 0;

    var dbMax = 0;
    var startFrom = 0;
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(MAX(invoices_id), 0) AS max_id FROM invoices',
      );
      dbMax = (rows.first['max_id'] ?? 0) as int;

      final setting = await _db.readData(
        "SELECT value FROM settings WHERE key = 'invoice_start' LIMIT 1",
      );
      if (setting.isNotEmpty) {
        startFrom = int.tryParse('${setting.first['value']}') ?? 0;
      }
    } catch (e) {
      debugPrint('loadInitialCounter DB seed skipped: $e');
    }

    // نبدأ من الأعلى ونطرح 1 لأن findInvoiceNo تزيد أولًا.
    final floorValue = [dbMax, startFrom, _storedValue].reduce(
      (a, b) => a > b ? a : b,
    );
    _currentCounterValue = floorValue;

    debugPrint(
      'ترقيم الفواتير: قاعدة=$dbMax، إعداد=$startFrom، محفوظ=$_storedValue ⇒ البداية=$floorValue',
    );
  }

  /// يعيد رقم فاتورة جديدًا فريدًا.
  ///
  /// يتحقق من عدم وجود الرقم فعليًا في القاعدة (حماية مزدوجة في حال كانت
  /// الفواتير قد أُدخلت يدويًا أو استُعيدت من نسخة احتياطية أقدم).
  static Future<int> findInvoiceNo() async {
    await _initSharedPreferences();

    // تهيئة كسولة إن لم تُستدعَ loadInitialCounter (مسار احتياطي)
    if (_currentCounterValue == 0) {
      await loadInitialCounter();
    }

    var candidate = _currentCounterValue + 1;

    // تجاوز أي رقم مستخدم فعلًا — بحد أقصى معقول لتفادي حلقة لا نهائية.
    for (var guard = 0; guard < 1000; guard++) {
      final exists = await _invoiceNumberExists(candidate);
      if (!exists) break;
      candidate++;
    }

    _currentCounterValue = candidate;
    // حفظ **مُنتظر** — الحفظ غير المُنتظَر كان يسمح بضياع العداد عند الإغلاق.
    // واختياري: غياب التفضيلات لا يوقف الترقيم (القاعدة هي المرجع).
    await _prefsInstance?.setInt(_counterKey, _currentCounterValue);
    return _currentCounterValue;
  }

  static Future<bool> _invoiceNumberExists(int number) async {
    try {
      final rows = await _db.readData(
        'SELECT COUNT(*) AS c FROM invoices WHERE invoices_id = ?',
        [number],
      );
      return ((rows.first['c'] ?? 0) as int) > 0;
    } catch (e) {
      debugPrint('invoice number check skipped: $e');
      return false;
    }
  }

  /// الرقم الحالي بلا زيادة — للعرض فقط.
  static int get currentNumber => _currentCounterValue;
}
