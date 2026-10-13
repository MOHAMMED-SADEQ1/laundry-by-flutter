// مطابقة نصّ الزبون المكتوب في الفاتورة بأرجح زبون مسجّل.
//
// **لماذا دالة نقية مستقلة لا كود داخل حوار السداد؟** لأن الخطأ هنا **صامت**:
// مطابقة خاطئة تربط الفاتورة بشخص آخر، فيُخصم من اشتراكه أو يُسجَّل الدين على
// حسابه، ولا يظهر أي خطأ يلفت النظر. لذلك أُخرجت إلى دالة بلا حالة (stateless)
// تُختبر مباشرة — نفس سبب فصل `InvoiceShareService.resolveTotal`.
//
// القاعدة الحاكمة: **عند الشكّ لا نُطابق**. ربط الفاتورة يدويًا خطوة واحدة
// ينساها الموظف، أما الربط الخاطئ فخطأ محاسبي يُكتشف متأخرًا.

class SubscriberMatcher {
  SubscriberMatcher._();

  /// الحدّ الأدنى لطول الرقم قبل قبول مطابقة الهاتف.
  ///
  /// بدونه كان رقم مكتوب ناقصًا — أو حقل هاتف تالف قصير مثل `"5"` — يُطابق
  /// أي رقم ينتهي به، فتُربط الفاتورة بزبون لا علاقة له بها.
  static const int minPhoneDigits = 7;

  /// تطبيع الاسم للمقارنة: بلا تشكيل ولا تطويل ولا اختلاف حال أحرف، مع توحيد
  /// صيغ الألف والياء والتاء المربوطة — أسماء الزبائن تُكتب يدويًا وتتغيّر
  /// صورتها بين موظف وموظف («أحمد»/«احمد»، «فاطمة»/«فاطمه»).
  static String normalizeName(String raw) => raw
      .trim()
      .toLowerCase()
      // تشكيل (ً-ْ) + تطويل (ـ)
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// أرقام فقط — لمقارنة الهاتف بأي صيغة يكتبها الموظف (05… / 9665… / +966…).
  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  /// مفتاح مقارنة الهاتف: أرقام فقط، بلا صفر البادئة المحلي (05… ⇒ 5…) وبلا
  /// صفرَي `00` الدوليين.
  ///
  /// السبب: الزبون نفسه يُكتب في الفاتورة محليًا (`0551234567`) وفي السجل دوليًا
  /// (`966551234567`)؛ الاختلاف في البادئة وحدها كان يمنع المطابقة فيفشل الربط
  /// التلقائي بلا سبب ظاهر للموظف.
  static String phoneKey(String raw) {
    var digits = digitsOnly(raw);
    if (digits.startsWith('00')) digits = digits.substring(2);
    while (digits.length > 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// معرّف أرجح زبون يطابق [typed] ضمن [customers]، أو `null` إن لم توجد
  /// مطابقة موثوقة.
  ///
  /// الترتيب مقصود من الأخصّ إلى الأعمّ:
  ///   1. تطابق تام للاسم (بعد التطبيع) — الأدقّ فلا يُسبق بغيره
  ///   2. الهاتف — لأن الزبون يُكتب أحيانًا برقمه لا باسمه
  ///   3. احتواء فريد (اسم واحد فقط يطابق) — لا نخمّن عند التعدّد
  static int? matchCustomerId(
    String typed,
    List<Map<String, dynamic>> customers,
  ) {
    final key = normalizeName(typed);
    if (key.isEmpty) return null;

    for (final c in customers) {
      if (normalizeName('${c['customer_name'] ?? ''}') == key) {
        return c['customer_id'] as int?;
      }
    }

    final typedKey = phoneKey(typed);
    if (typedKey.length >= minPhoneDigits) {
      for (final c in customers) {
        for (final field in const ['phone_1', 'phone_2']) {
          final stored = phoneKey('${c[field] ?? ''}');
          if (stored.length < minPhoneDigits) continue;
          if (stored == typedKey ||
              stored.endsWith(typedKey) ||
              typedKey.endsWith(stored)) {
            return c['customer_id'] as int?;
          }
        }
      }
    }

    if (key.length >= 3) {
      final hits = customers
          .where(
            (c) => normalizeName('${c['customer_name'] ?? ''}').contains(key),
          )
          .toList();
      if (hits.length == 1) return hits.first['customer_id'] as int?;
    }
    return null;
  }
}
