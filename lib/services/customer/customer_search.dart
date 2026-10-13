/// استعلام بحث جاهز لقاعدة البيانات: `where` بمعاملات `?` حصرًا.
///
/// **قاعدة المشروع:** لا تُدمج قيمة بحث في نص SQL أبدًا — كل قيمة تمرّ في
/// `args`، وهذا الكائن هو ما يحمل الاثنين معًا فلا يفترقان.
class CustomerSearchQuery {
  final String where;
  final List<dynamic> args;

  const CustomerSearchQuery({required this.where, required this.args});
}

/// منطق البحث عن زبون بالاسم أو رقم الجوال — **خالص** (بلا Flutter وبلا قاعدة
/// بيانات) ليكون قابلًا للاختبار بـ`dart run` كما تقتضي قاعدة المشروع.
///
/// **لماذا ملف مستقل؟** لأن البحث يُستدعى من ثلاثة مواضع: اقتراحات شريط
/// الفاتورة، شريط قائمة الزبائن، ونافذة البحث السريع. وتكرار المنطق في كل
/// موضع أنتج فعلًا خللًا حقيقيًا: قائمة الزبائن ينصّ تلميحها على
/// «ابحث عن زبون بالاسم أو الرقم» بينما الفلترة كانت **بالاسم وحده**، فلا
/// نتيجة لمن يبحث برقم الجوال.
///
/// مطابقة الرقم متسامحة عن قصد:
///   • `0555 123 456` يُطابق `0555123456` (الفواصل تُهمَل في الطرفين).
///   • `٠٥٥٥…` بالأرقام العربية يُطابق `0555…` (لوحة مفاتيح عربية).
class CustomerSearch {
  CustomerSearch._();

  /// حقول الجوال في جدول `customers`.
  static const List<String> phoneFields = <String>['phone_1', 'phone_2'];

  /// فواصل الأرقام الشائعة التي تُكتب عند إدخال الرقم.
  static const List<String> _phoneSeparators = <String>[
    ' ',
    '-',
    '+',
    '(',
    ')',
  ];

  /// تعبيرات SQL لأعمدة الجوال **بعد تجريد الفواصل داخل القاعدة نفسها**.
  ///
  /// **لماذا؟** لأن الرقم قد يكون مخزَّنًا `0509 999 999` ويسأل المستخدم عنه
  /// `0509999999` — و`LIKE` وحدها لا تُطابقهما. فنجرّد الفواصل في الطرفين.
  /// ⚠️ الرموز المدمجة هنا **ثوابت** (فواصل)، وكل قيمة بحث تبقى في `?`.
  static final List<String> phoneExpressions = <String>[
    for (final field in phoneFields) _normalizedPhoneExpr(field),
  ];

  static String _normalizedPhoneExpr(String column) {
    var expr = column;
    for (final separator in _phoneSeparators) {
      expr = "REPLACE($expr, '$separator', '')";
    }
    return expr;
  }

  static const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const String _extendedArabicIndicDigits = '۰۱۲۳۴۵۶۷۸۹';

  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// نص يبدو رقم جوال: أرقام (لاتينية أو عربية) وفواصل فقط — بلا حروف.
  static final RegExp _phoneLike = RegExp(r'^[0-9٠-٩۰-۹+\-()\s]+$');

  /// هل النص يبدو رقم جوال؟ (بعد `normalize`).
  ///
  /// **لماذا هذا الحرس؟** لأن مطابقة «الأرقام المجرّدة» إن طُبقت على أي نص
  /// فيه رقم جعلت `محمد 5` يُطابق **كل زبون رقمه فيه 5** — نتائج كاذبة تُغرق
  /// القائمة. فتُخصَّص مطابقة الأرقام لما يُكتب كرقم جوال فعلًا.
  static bool looksLikePhone(String normalized) =>
      normalized.isNotEmpty && _phoneLike.hasMatch(normalized);

  /// تطبيع نص البحث: إزالة فراغات الطرفين وتوحيد الفراغات الداخلية.
  static String normalize(String raw) => raw.trim().replaceAll(_spaces, ' ');

  /// تحويل الأرقام العربية/الهندية إلى لاتينية.
  static String toWesternDigits(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      final arabic = _arabicIndicDigits.indexOf(ch);
      if (arabic >= 0) {
        buffer.write(arabic);
        continue;
      }
      final extended = _extendedArabicIndicDigits.indexOf(ch);
      if (extended >= 0) {
        buffer.write(extended);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  /// أرقام الجوال وحدها: بعد التحويل اللاتيني تُحذف المسافات والشرطات
  /// والأقواس و`+`، فيتطابق ما يكتبه المستخدم مع أي صيغة تخزين.
  static String phoneDigits(String raw) =>
      toWesternDigits(raw).replaceAll(_nonDigits, '');

  /// مطابقة زبون واحد — للفلترة المحلية في أي قائمة زبائن محمّلة.
  static bool matches(Map<String, dynamic> customer, String query) {
    final norm = normalize(query);
    if (norm.isEmpty) return true;
    final needle = norm.toLowerCase();

    final name = (customer['customer_name'] ?? '').toString();
    if (name.toLowerCase().contains(needle)) return true;

    final wantedDigits = looksLikePhone(norm) ? phoneDigits(norm) : '';
    for (final key in phoneFields) {
      final phone = (customer[key] ?? '').toString();
      if (phone.isEmpty) continue;
      // 1) مطابقة النص كما كتبه المستخدم (تلتقط أي جزء من الرقم).
      if (phone.toLowerCase().contains(needle)) return true;
      // 2) مطابقة الأرقام بعد التطبيع (اختلاف الفواصل/الأرقام العربية).
      if (wantedDigits.isNotEmpty &&
          phoneDigits(phone).contains(wantedDigits)) {
        return true;
      }
    }
    return false;
  }

  /// فلترة قائمة زبائن (بلا قاعدة بيانات) — تُحفظ الحالة الفارغة كما هي.
  static List<Map<String, dynamic>> filter(
    Iterable<Map<String, dynamic>> rows,
    String query,
  ) {
    final norm = normalize(query);
    if (norm.isEmpty) return rows.toList();
    return rows.where((c) => matches(c, norm)).toList();
  }

  /// بناء شرط SQL للبحث المباشر عن الزبائن (الاسم أو أي من الرقمين).
  ///
  /// كل قيم البحث بمعاملات `?` — والمُدمَج في النص ثوابت (أسماء الأعمدة
  /// ودالة `REPLACE` وفواصلها) لا تتغيّر أبدًا.
  static CustomerSearchQuery buildQuery(String query) {
    final norm = normalize(query);

    final clauses = <String>['customer_name LIKE ?'];
    final args = <dynamic>['%$norm%'];

    // 1) مطابقة نصّية كما كتبه المستخدم (تُغطّي أي صيغة مطابقة للمخزَّن).
    for (final expr in phoneExpressions) {
      clauses.add('$expr LIKE ?');
      args.add('%$norm%');
    }

    // 2) صيغة الأرقام المجرّدة (تُغطّي اختلاف الفواصل والأرقام العربية في
    //    المُدخَل) — **للنص الذي يُكتب كرقم جوال وحده** (انظر `looksLikePhone`).
    final wantedDigits = looksLikePhone(norm) ? phoneDigits(norm) : '';
    if (wantedDigits.isNotEmpty && wantedDigits != norm) {
      for (final expr in phoneExpressions) {
        clauses.add('$expr LIKE ?');
        args.add('%$wantedDigits%');
      }
    }

    return CustomerSearchQuery(where: clauses.join(' OR '), args: args);
  }
}
