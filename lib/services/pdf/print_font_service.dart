// تحميل خطّ الطباعة المختار وتخزينه مؤقتًا.
//
// نقطة واحدة: `PrintInvoiceController.arabicFont` صار يُقرأ من هنا، فتبديل
// الخطّ في الإعدادات ينعكس على **كل** مستند (فاتورة · كشف · وردية · مشاركة ·
// إعادة طباعة) بلا لمس أي مولّد.
//
// ⚠️ التخزين المؤقت **بالمفتاح** لا بمتغيّر واحد: تغيير الخطّ ثم الرجوع عنه
// لا يعيد قراءة الملفّ من القرص مرّتين.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/pdf/print_font.dart';
import 'package:laundry/services/settings/app_settings_service.dart';

class PrintFontService {
  PrintFontService._();

  /// المفتاح ⇒ الخطّ المحلَّل. الملفّ يُقرأ مرة واحدة لكل خطّ في عمر التشغيل.
  static final Map<String, pw.Font> _cache = <String, pw.Font>{};

  /// الخطّ المختار حاليًا (مع الافتراضي عند مفتاح مجهول).
  static PrintFont get selected =>
      PrintFonts.byKey(AppSettingsService.instance.printFontKey);

  /// هل المفتاح المختار موجود في السجلّ؟ (تنظيف قيمة قديمة في الإعدادات)
  static bool get isSelectionValid =>
      PrintFonts.isKnown(AppSettingsService.instance.printFontKey);

  /// يُرجع `pw.Font` للخطّ المختار، ويُحمّله إن لم يكن في الذاكرة.
  ///
  /// 🚨 **لا ترمي أبدًا**: فشل قراءة ملفّ خطّ (حزمة ناقصة · مسار خطأ) يجب
  /// ألا يمنع طباعة فاتورة — يُسقَط للخطّ الافتراضي، وإن فشل هو أيضًا يُرمى
  /// الخطأ لأن الطباعة بلا خطّ عربي مستحيلة أصلًا.
  static Future<pw.Font> resolve([String? key]) async {
    final font = PrintFonts.byKey(key ?? AppSettingsService.instance.printFontKey);
    final cached = _cache[font.key];
    if (cached != null) return cached;

    try {
      final data = await rootBundle.load(font.asset);
      final loaded = pw.Font.ttf(data);
      _cache[font.key] = loaded;
      return loaded;
    } catch (e) {
      debugPrint(
        trf(
          'PrintFontService: تعذّر تحميل «{0}» ({1}): {2}',
          [font.label, font.asset, e],
        ),
      );
      if (font.key == PrintFonts.defaultKey) rethrow;
      // خطّ بديل: الافتراضي.
      final fallback = PrintFonts.byKey(PrintFonts.defaultKey);
      final fb = _cache[fallback.key];
      if (fb != null) return fb;
      final data = await rootBundle.load(fallback.asset);
      final loaded = pw.Font.ttf(data);
      _cache[fallback.key] = loaded;
      return loaded;
    }
  }

  /// يُفرغ الذاكرة — يُستدعى عند تغيير الخطّ أو تبديل النسخة الاحتياطية.
  static void invalidate() => _cache.clear();

  /// هل الخطّ محمَّل؟ (للاختبارات والتشخيص)
  @visibleForTesting
  static bool isCached(String key) => _cache.containsKey(key);
}
