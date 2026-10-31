// منطق بنود الفاتورة — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// ═══════════════════════════════════════════════════════════════════════════
// العيب الذي وُجد هذا الملف لأجله
// ═══════════════════════════════════════════════════════════════════════════
// كان كل ضغط على صنف يُضيف **صفًّا جديدًا** إلى الفاتورة. فمن يُدخل عشرة
// أثواب بيضاء يرى عشرة أسطر متطابقة، والمجموع صحيح لكن الفاتورة المطبوعة
// تُقرأ كأنها عشرة أصناف مختلفة، والمرتجع والجرد يُحسبان سطرًا سطرًا.
//
// المطلوب محاسبيًّا: **سطر واحد بكمية عشرة** — ما دام الصنف والخدمة
// والسعر والملاحظة والصورة هي نفسها.
//
// ═══════════════════════════════════════════════════════════════════════════
// لماذا ليست الهوية «الاسم + الخدمة» فقط؟
// ═══════════════════════════════════════════════════════════════════════════
// لأن الثوب الذي عليه **بقعة** ليس نفس الثوب النظيف: الملاحظة والصورة
// تُلزمان العامل بمعالجة مختلفة، ودمجهما يُخفي إحداهما بلا رجعة. وكذلك
// **سعر الوحدة**: لو تغيّر سعر الصنف في القائمة أثناء الفاتورة، فدمج السطر
// الجديد في القديم يكتب سعرًا لم يوافق عليه الزبون. لذلك:
//
//   • تطابق تامّ (خمسة عناصر) ⇒ زيادة كمية.
//   • اختلاف الملاحظة/الصورة/السعر ⇒ **سطر منفصل**، مع سبب مُعلَن للمستخدم
//     (`LineMismatch`) حتى لا يظنّ أن الدمج تعطّل.

/// أنواع الخدمات الأربع — **مصدر واحد** للتسمية العربية المخزَّنة في البند.
///
/// التسمية تُخزَّن عربية في `content` لأن الطباعة تترجمها بـ`tr(content)`
/// وقت العرض؛ وتغيير حرف هنا يكسر الترجمة **بصمت**. لذلك تُجمع هنا ويُمنع
/// تكرارها في المتحكّمات (يحرسه `tool/verify_invoice_lines.dart`).
class ServiceKind {
  ServiceKind._();

  static const String normalWash = 'غسيل وكوي عادي';
  static const String urgentWash = 'غسيل وكوي مستعجل';
  static const String normalIron = 'كوي عادي';
  static const String urgentIron = 'كوي مستعجل';

  /// الخدمات بترتيب العرض (نفس ترتيب بطاقات الحوار 2×2).
  static const List<String> all = <String>[
    normalWash,
    urgentWash,
    normalIron,
    urgentIron,
  ];

  /// مفاتيح الحوار (`ShowDialogController.typerequest`) ⇒ التسمية المخزَّنة.
  static const Map<String, String> keyToLabel = <String, String>{
    'normalwashingironing': normalWash,
    'urgentwashingironing': urgentWash,
    'normalironing': normalIron,
    'urgentironing': urgentIron,
  };

  /// التسمية ⇒ مفتاح الحوار (لتمييز الخدمة الحالية في حوار التعديل).
  static String keyOf(String label) {
    for (final entry in keyToLabel.entries) {
      if (entry.value == label) return entry.key;
    }
    return '';
  }

  /// عمود السعر المقابل في جدول `clothing`.
  ///
  /// يُستخدم لتسعير **تغيير الخدمة** في حوار التعديل من قائمة الأسعار
  /// الرسمية بدل ترك السعر القديم على خدمة جديدة.
  static String priceColumn(String label) => switch (label) {
    urgentWash => 'urgent_washing_and_ironing_price',
    normalIron => 'normal_ironing_price',
    urgentIron => 'urgent_ironing_price',
    _ => 'normal_washing_and_ironing_price',
  };
}

/// سبب **عدم** الدمج رغم تطابق الصنف والخدمة.
enum LineMismatch { none, note, photo, price }

/// نتيجة البحث عن بند مطابق.
class LineProbe {
  /// فهرس البند المطابق — `-1` لا يوجد.
  final int index;

  /// لماذا لم يُطابَق (أو `none` إذا طابَق أو إذا كان صنفًا جديدًا تمامًا).
  final LineMismatch reason;

  const LineProbe(this.index, this.reason);

  bool get isDuplicate => index >= 0;

  static const LineProbe none = LineProbe(-1, LineMismatch.none);
}

/// ما حدث فعلًا عند محاولة إضافة بند أو تعديله.
enum LineAddOutcome {
  /// صنف جديد تمامًا — أُضيف سطرًا.
  added,

  /// بند مطابق موجود ⇒ **زادت كميته** ولم يُضف سطر جديد.
  merged,

  /// نفس الصنف والخدمة لكن **الملاحظة** مختلفة ⇒ سطر مستقلّ (بقعة/تلف).
  separateByNote,

  /// نفس الصنف والخدمة لكن **الصورة** مختلفة ⇒ سطر مستقلّ.
  separateByPhoto,

  /// نفس الصنف والخدمة لكن **سعر الوحدة** مختلف ⇒ سطر مستقلّ.
  separateByPrice,

  /// تعديل بند جعلَه مطابقًا لبند آخر ⇒ دُمجا.
  mergedByEdit,
}

/// نتيجة إضافة/تعديل بند — تُستخدم لإبلاغ المستخدم بما جرى بدقة.
class LineAddResult {
  final LineAddOutcome outcome;

  /// فهرس البند في القائمة **بعد** العملية (`-1` = لا بند).
  final int index;

  /// الكمية في السطر بعد العملية.
  final int quantity;

  /// اسم الصنف (عربي) — للعرض في الرسالة.
  final String name;

  /// اسم الصنف الإنجليزي إن وُجد — تبقى الرسالة مقروءة في الواجهة الإنجليزية.
  final String? nameEn;

  /// الخدمة (عربي) — للعرض في الرسالة.
  final String service;

  const LineAddResult({
    required this.outcome,
    required this.index,
    required this.quantity,
    required this.name,
    required this.service,
    this.nameEn,
  });

  bool get merged =>
      outcome == LineAddOutcome.merged ||
      outcome == LineAddOutcome.mergedByEdit;
}

/// قائمة بنود جديدة + ما حدث — **لا تُعدَّل القائمة المُمرَّرة**.
///
/// الفصل بين «القرار» (هذا الملف) و«الحالة» (المتحكّم) مقصود: القرار
/// محاسبي ويجب أن يُختبر على قوائم حقيقية بلا Flutter ولا قاعدة بيانات.
class LineApply {
  final List<Map<String, dynamic>> items;
  final LineAddResult result;

  const LineApply(this.items, this.result);
}

/// هوية البند + عملياته الحسابية.
class InvoiceLines {
  InvoiceLines._();

  static const int minQuantity = 1;

  /// سقف الكمية في سطر واحد. ليس قيدًا محاسبيًّا بل حماية من إدخال خاطئ
  /// (ضغط زرّ عشرات المرات) يجعل الفاتورة غير قابلة للقراءة.
  static const int maxQuantity = 999;

  /// تطبيع نصّ للمقارنة **لا للتخزين**: التشكيل والتطويل يُحذفان، والألف
  /// والياء والتاء المربوطة والهمزات تُوحَّد، والمسافات تُطوى، واللاتيني
  /// يُصبغ صغيرًا.
  ///
  /// بدون هذا، «ثوب أبيض» و«ثوب أبيض » (بمسافة) و«ثوب ابيض» ثلاثة أصناف.
  static String normalize(Object? raw) {
    final text = (raw ?? '').toString();
    if (text.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (_diacritics.hasMatch(ch)) continue;
      buffer.write(_folded[ch] ?? ch);
    }
    return buffer.toString().replaceAll(_whitespace, ' ').trim().toLowerCase();
  }

  /// التشكيل والتطويل — لا معنى لها في المقارنة.
  static final RegExp _diacritics = RegExp(r'[\u064B-\u0652\u0670\u0640]');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// حروف تُكتب بأشكال مختلفة وتُقرأ شيئًا واحدًا.
  static const Map<String, String> _folded = <String, String>{
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ئ': 'ي',
    'ؤ': 'و',
    'ة': 'ه',
  };

  /// مبلغ مقرَّب إلى قرشين — يمنع `16.499999999999996` في الفاتورة.
  static double money(Object? raw) {
    final value = _num(raw);
    return double.parse(value.toStringAsFixed(2));
  }

  static double _num(Object? raw) {
    if (raw is num) return raw.toDouble();
    var text = '${raw ?? ''}'.trim();
    if (text.isEmpty) return 0;
    text = _westernDigits(text).replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  /// أرقام عربية/هندية ⇒ لاتينية (لوحة مفاتيح عربية تُدخل «٢» لا «2»).
  static String _westernDigits(String raw) {
    if (!_arabicDigits.hasMatch(raw)) return raw;
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(ch);
      if (arabic >= 0) {
        buffer.write(arabic);
        continue;
      }
      final extended = '۰۱۲۳۴۵۶۷۸۹'.indexOf(ch);
      if (extended >= 0) {
        buffer.write(extended);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  static final RegExp _arabicDigits = RegExp(r'[٠-٩۰-۹]');

  /// الكمية الفعّالة للبند (مقروءة من `count` أكان رقمًا أم نصًّا).
  static int quantityOf(Map<String, dynamic> item) {
    final qty = _num(item['count']).round();
    if (qty < minQuantity) return minQuantity;
    if (qty > maxQuantity) return maxQuantity;
    return qty;
  }

  static double priceOf(Map<String, dynamic> item) => money(item['price']);

  /// إجمالي السطر = سعر الوحدة × الكمية (مقرَّبًا)، لا يُقرأ من `total_price`
  /// المخزَّن لأنه قد يكون قديمًا بعد تعديل الكمية.
  ///
  /// الاستثناء الوحيد: بند بلا `price` صالح (فاتورة قديمة/بند مجاني بسعر
  /// محذوف) وله مبلغ مخزَّن — نُعيد المخزَّن بدل إسقاط المال من المجموع.
  static double lineTotal(Map<String, dynamic> item) {
    final price = priceOf(item);
    if (price <= 0) {
      final stored = money(item['total_price']);
      if (stored > 0) return stored;
    }
    return money(price * quantityOf(item));
  }

  /// مجموع كميات خدمة معيّنة لصنف معيّن — لعرض «في الفاتورة: 3» في الحوار.
  static int quantityOfService(
    List<Map<String, dynamic>> items, {
    required Object? name,
    required Object? service,
  }) {
    final target = normalize(name);
    final wanted = normalize(service);
    var total = 0;
    for (final item in items) {
      if (normalize(item['vestments']) != target) continue;
      if (normalize(item['content']) != wanted) continue;
      total += quantityOf(item);
    }
    return total;
  }

  /// يبحث عن بند مطابق تمامًا لِـ[candidate].
  ///
  /// [ignoreIndex] يُستخدم عند **تعديل** بند: البند نفسه لا يُطابق نفسه.
  static LineProbe probe(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> candidate, {
    int ignoreIndex = -1,
  }) {
    final name = normalize(candidate['vestments']);
    final service = normalize(candidate['content']);
    final note = normalize(candidate['note']);
    final photo = '${candidate['photo'] ?? ''}'.trim();
    final price = priceOf(candidate);

    var sawNote = false;
    var sawPhoto = false;
    var sawPrice = false;

    for (var i = 0; i < items.length; i++) {
      if (i == ignoreIndex) continue;
      final item = items[i];
      if (normalize(item['vestments']) != name) continue;
      if (normalize(item['content']) != service) continue;

      final sameNote = normalize(item['note']) == note;
      final samePhoto = '${item['photo'] ?? ''}'.trim() == photo;
      final samePrice = (priceOf(item) - price).abs() < 0.005;

      if (sameNote && samePhoto && samePrice) {
        return LineProbe(i, LineMismatch.none);
      }
      if (!sameNote) sawNote = true;
      if (!samePhoto) sawPhoto = true;
      if (!samePrice) sawPrice = true;
    }

    // الأولوية للملاحظة: هي السبب الأكثر شيوعًا الذي **يجب** أن يفصل السطر
    // (بقعة/تلف)، فيُعلَن للمستخدم بدل أن يظنّ الدمج تعطّل.
    if (sawNote) return const LineProbe(-1, LineMismatch.note);
    if (sawPhoto) return const LineProbe(-1, LineMismatch.photo);
    if (sawPrice) return const LineProbe(-1, LineMismatch.price);
    return LineProbe.none;
  }

  /// نسخة من البند بكمية جديدة وإجمالي مُعاد حسابه — **لا يُعدَّل الأصل**.
  static Map<String, dynamic> withQuantity(
    Map<String, dynamic> item,
    int quantity,
  ) {
    final safe = quantity.clamp(minQuantity, maxQuantity);
    final copy = Map<String, dynamic>.from(item);
    copy['count'] = safe;
    copy['total_price'] = money(priceOf(item) * safe);
    return copy;
  }

  /// نسخة من البند بسعر وحدة جديد وإجمالي مُعاد حسابه.
  static Map<String, dynamic> withPrice(
    Map<String, dynamic> item,
    Object? price,
  ) {
    final copy = Map<String, dynamic>.from(item);
    final safe = money(price);
    copy['price'] = safe;
    copy['total_price'] = money(safe * quantityOf(item));
    return copy;
  }

  /// دمج بندين متطابقين: الكميات تُجمع والإجمالي يُعاد حسابه من السعر.
  static Map<String, dynamic> merge(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) => withQuantity(
    existing,
    quantityOf(existing) + quantityOf(incoming),
  );

  /// تطبيق **إضافة** بند على قائمة: يزيد كمية المطابق أو يُضيف سطرًا.
  ///
  /// القاعدة كاملةً هنا — لا في المتحكّم ولا في الواجهة — فتُختبر وحدها.
  static LineApply applyAdd(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> candidate,
  ) {
    final hit = probe(items, candidate);
    final next = List<Map<String, dynamic>>.from(items);

    if (hit.isDuplicate) {
      final merged = merge(next[hit.index], candidate);
      next[hit.index] = merged;
      return LineApply(
        next,
        _resultOf(merged, LineAddOutcome.merged, hit.index),
      );
    }

    next.add(candidate);
    return LineApply(
      next,
      _resultOf(
        candidate,
        switch (hit.reason) {
          LineMismatch.note => LineAddOutcome.separateByNote,
          LineMismatch.photo => LineAddOutcome.separateByPhoto,
          LineMismatch.price => LineAddOutcome.separateByPrice,
          LineMismatch.none => LineAddOutcome.added,
        },
        next.length - 1,
      ),
    );
  }

  /// تطبيق **تعديل** بند: يستبدله، ثم يفحص التكرار من جديد.
  ///
  /// لو صار البند بعد التعديل مطابقًا لبند آخر يُدمجان وتُحذف النسخة
  /// الزائدة — وإلا بقيت الفاتورة تحمل سطرين متطابقين من الباب الخلفي.
  static LineApply applyUpdate(
    List<Map<String, dynamic>> items,
    int index,
    Map<String, dynamic> updated,
  ) {
    if (index < 0 || index >= items.length) {
      return LineApply(
        items,
        const LineAddResult(
          outcome: LineAddOutcome.added,
          index: -1,
          quantity: 0,
          name: '',
          service: '',
        ),
      );
    }

    // حماية من **خريطة ناقصة**: لو جاء التعديل بلا `count` أو بلا `price`
    // (مستدعٍ جديد لم يقرأ العقد) لا تُصفَّر الكمية ولا يُصفَّر السعر — يُحفظ
    // القديم. تصفير الكمية يجعل السطر يختفي من الحساب بصمت.
    final quantity = updated.containsKey('count')
        ? quantityOf(updated)
        : quantityOf(items[index]);
    final price = updated.containsKey('price')
        ? updated['price']
        : items[index]['price'];
    final prepared = withQuantity(withPrice(updated, price), quantity);
    final next = List<Map<String, dynamic>>.from(items);
    final hit = probe(next, prepared, ignoreIndex: index);

    if (hit.isDuplicate) {
      final target = hit.index;
      final merged = merge(next[target], prepared);
      next[target] = merged;
      next.removeAt(index);
      return LineApply(
        next,
        _resultOf(
          merged,
          LineAddOutcome.mergedByEdit,
          target > index ? target - 1 : target,
        ),
      );
    }

    next[index] = prepared;
    return LineApply(next, _resultOf(prepared, LineAddOutcome.added, index));
  }

  static LineAddResult _resultOf(
    Map<String, dynamic> item,
    LineAddOutcome outcome,
    int index,
  ) => LineAddResult(
    outcome: outcome,
    index: index,
    quantity: quantityOf(item),
    name: '${item['vestments'] ?? ''}',
    nameEn: item['vestments_en']?.toString(),
    service: '${item['content'] ?? ''}',
  );
}
