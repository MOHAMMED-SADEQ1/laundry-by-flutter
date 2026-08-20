import 'package:shared_preferences/shared_preferences.dart';

class InvoiceCounterService {
  // استخدام لاحق لـ SharedPreferences لضمان تهيئته مرة واحدة فقط
  static SharedPreferences? _prefsInstance;
  static const String _counterKey = "counterinvoice";

  // تهيئة SharedPreferences مرة واحدة
  static Future<void> _initSharedPreferences() async {
    _prefsInstance ??= await SharedPreferences.getInstance();
  }

  // استخدام متغير في الذاكرة لتخزين القيمة الحالية
  // ومزامنتها مع SharedPreferences بشكل دوري أو عند الحاجة
  static int _currentCounterValue = 0;

  // تهيئة قيمة العداد من SharedPreferences عند بدء التطبيق/الخدمة
  static Future<void> loadInitialCounter() async {
    await _initSharedPreferences();
    _currentCounterValue = _prefsInstance!.getInt(_counterKey) ?? 0;
  }

  static Future<int> findInvoiceNo() async {
    // التأكد من تهيئة SharedPreferences و تحميل القيمة الأولية
    // (يمكن استدعاء loadInitialCounter مرة واحدة عند بدء التطبيق)
    await _initSharedPreferences();

    // زيادة العداد في الذاكرة أولاً
    _currentCounterValue++;

    // حفظ القيمة الجديدة في SharedPreferences بشكل غير متزامن
    // هذا لا يمنع عودة الدالة بالقيمة الجديدة فورًا
    _prefsInstance!.setInt(_counterKey, _currentCounterValue);

    // إرجاع القيمة الجديدة فورًا
    return _currentCounterValue;
  }
}
