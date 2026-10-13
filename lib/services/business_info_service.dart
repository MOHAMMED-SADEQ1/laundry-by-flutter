import 'package:flutter/foundation.dart';
import 'package:laundry/sqldb.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة مركّزة لقراءة معلومات النشاط التجاري (اسم، هاتف، عنوان، موقع،
/// الرقم الضريبي). تقرأ من قاعدة البيانات وتُخزّن مؤقتاً في SharedPreferences.
class BusinessInfoService {
  BusinessInfoService._();
  static final BusinessInfoService instance = BusinessInfoService._();

  final SqlDB _db = SqlDB();

  String _name = '';
  String _phone = '';
  String _address = '';
  String _location = '';
  String _taxNumber = '';
  String _crNumber = '';
  String _shortAddress = '';
  bool _loaded = false;

  String get name => _name;
  String get phone => _phone;
  String get address => _address;
  String get location => _location;

  /// السجل التجاري — حقل اختياري يظهر على الفاتورة عند تفعيل خياره.
  String get crNumber => _crNumber;

  /// العنوان الوطني المختصر — يظهر على الفاتورة عند تفعيل خياره.
  String get shortAddress => _shortAddress;

  /// الرقم الضريبي (VAT) — إلزامي على الفاتورة الضريبية المبسّطة، ويُرمَّز
  /// داخل QR الهيئة. فارغه يعني نشاطًا غير مسجَّل في الضريبة.
  String get taxNumber => _taxNumber;

  bool get isLoaded => _loaded;

  /// هل النشاط مسجَّل ضريبيًا (له رقم ضريبي)؟
  bool get isVatRegistered => _taxNumber.trim().isNotEmpty;

  /// تحميل المعلومات من قاعدة البيانات (مرة واحدة فقط عادةً)
  Future<void> load() async {
    try {
      _name = (await _db.getSetting('business_name')) ?? '';
      _phone = (await _db.getSetting('business_phone')) ?? '';
      _address = (await _db.getSetting('business_address')) ?? '';
      _location = (await _db.getSetting('business_location')) ?? '';
      _taxNumber = (await _db.getSetting('business_tax_number')) ?? '';
      _crNumber = (await _db.getSetting('business_cr_number')) ?? '';
      _shortAddress = (await _db.getSetting('business_short_address')) ?? '';
      _loaded = true;

      // حفظ في SharedPreferences للوصول السريع
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_business_name', _name);
      await prefs.setString('cached_business_phone', _phone);
      await prefs.setString('cached_business_address', _address);
      await prefs.setString('cached_business_location', _location);
      await prefs.setString('cached_business_tax_number', _taxNumber);
      await prefs.setString('cached_business_cr_number', _crNumber);
      await prefs.setString('cached_business_short_address', _shortAddress);
    } catch (e) {
      debugPrint('BusinessInfoService.load error: $e');
      // محاولة القراءة من الكاش
      await _loadFromCache();
    }
  }

  /// تحميل من التخزين المؤقت (fallback)
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString('cached_business_name') ?? '';
      _phone = prefs.getString('cached_business_phone') ?? '';
      _address = prefs.getString('cached_business_address') ?? '';
      _location = prefs.getString('cached_business_location') ?? '';
      _taxNumber = prefs.getString('cached_business_tax_number') ?? '';
      _crNumber = prefs.getString('cached_business_cr_number') ?? '';
      _shortAddress = prefs.getString('cached_business_short_address') ?? '';
      _loaded = true;
    } catch (e) {
      debugPrint('BusinessInfoService._loadFromCache error: $e');
    }
  }

  /// تحديث قيمة في قاعدة البيانات والكاش
  Future<void> update(String key, String value) async {
    await _db.updateSetting(key, value);
    switch (key) {
      case 'business_name':
        _name = value;
        break;
      case 'business_phone':
        _phone = value;
        break;
      case 'business_address':
        _address = value;
        break;
      case 'business_location':
        _location = value;
        break;
      case 'business_tax_number':
        _taxNumber = value;
        break;
      case 'business_cr_number':
        _crNumber = value;
        break;
      case 'business_short_address':
        _shortAddress = value;
        break;
    }
    // تحديث الكاش.
    //
    // **إصلاح:** كان المفتاح `cached_business_$key` والمفتاح نفسه يبدأ بـ
    // `business_` ⇒ يُكتب `cached_business_business_name` بينما `load()`
    // يقرأ `cached_business_name`. أي أن الكاش كان **لا يُقرأ أبدًا** بعد
    // التعديل، فرجوع `_loadFromCache` يعطي قيمًا قديمة.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_$key', value);
  }

  /// التحقق مما إذا تم إعداد النشاط تجريبياً (أول تشغيل)
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  /// تحديد أن الإعداد الأولي تم
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }
}
