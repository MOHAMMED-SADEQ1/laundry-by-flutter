// ترتيب أصناف اللبس في شاشة البيع — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// مصدر واحد لكل ترتيب يمكن اختياره. لا جملة `ORDER BY` تُكتب في أي مكان
// آخر: المتحكّم يطلب `query` من هنا، والواجهة تقرأ `label` من هنا.
//
// ═══════════════════════════════════════════════════════════════════════════
// لماذا الفرز **في القاعدة** لا في Dart؟
// ═══════════════════════════════════════════════════════════════════════════
// 1. «بدون فرز» يجب أن تعني **ترتيب الإدخال الحقيقي** — ولا يوجد ترتيب إدخال
//    بعد أن تُفرز القائمة في الذاكرة (تصير الذاكرة هي المرجع، والترتيب الأصلي
//    يضيع نهائيًا بعد أول فرز).
// 2. «الأكثر مبيعًا» يحتاج تجميعًا على `invoice_items` — لا يُحسب في الواجهة
//    بلا تحميل كل بنود الفواتير إلى الذاكرة.
// 3. الترتيب الأبجدي بمقارنة Dart يخالف ترتيب SQLite في الحالات الحدّية
//    (المسافات، الأرقام، اللاتيني) ⇒ مصدران يتناقضان. مصدر واحد أوضح.
//
// ═══════════════════════════════════════════════════════════════════════════
// ملاحظة عن الترتيب الأبجدي العربي في SQLite (BINARY)
// ═══════════════════════════════════════════════════════════════════════════
// كتلة الحروف العربية في Unicode مرتّبة **أبجديًا** أصلًا
// (ا 0627 · ب 0628 · ت 062A · ث 062B … ي 064A)، فالترتيب الثنائي يعطي ترتيبًا
// عربيًا مقبولًا. الفروق المعروفة والمقبولة:
//   • `أ إ آ` (0622–0625) تأتي **قبل** `ا` (0627) — وهو ما يتوقّعه المستخدم.
//   • `ة` (0629) تأتي بين `ب` و`ت`، لكنها لا تبدأ كلمة أبدًا فلا أثر لها.
//   • `ى` (0649) قبل `ي` (064A) — مطابق للعرف.
// لذلك لا حاجة إلى `COLLATE` مخصّص (ولا يدعمه مسار `sqflite` بسهولة).

/// طريقة ترتيب أصناف اللبس في شاشة البيع.
class ClothingSort {
  const ClothingSort({
    required this.key,
    required this.label,
    required this.description,
    required this.orderBy,
    this.grouped = false,
  });

  /// المفتاح المخزَّن في `settings.clothing_sort` — **ثابت لا يُغيَّر**
  /// (تغييره يُفقد اختيار المستخدم بصمت).
  final String key;

  /// ما يراه المستخدم في القائمة.
  final String label;

  /// سطر توضيحي صغير تحت التسمية.
  final String description;

  /// جملة `ORDER BY` الكاملة، أو `null` = **بلا فرز** (ترتيب القاعدة كما هو).
  final String? orderBy;

  /// يحتاج تجميعًا على مبيعات البند (`invoice_items`) ⇒ استعلام مختلف تمامًا.
  final bool grouped;

  /// الافتراضي = الترتيب الأبجدي الصاعد — **سلوك ما قبل الميزة**، فلا يتغيّر
  /// ترتيب شاشة أي عميل بعد التحديث.
  static const String defaultKey = 'name_asc';

  /// الاستعلام الكامل لهذا الترتيب — نقطة البناء الوحيدة.
  ///
  /// `SELECT *` مقصود: الواجهة تقرأ صفّ `clothing` كاملًا، وأي عمود جديد
  /// في الجدول يصل تلقائيًا بلا تعديل هنا.
  String get query {
    if (grouped) {
      // `LEFT JOIN` لا `JOIN`: الصنف الذي لم يُبع قط يجب أن يظهر (بعدد صفر)
      // لا أن يختفي من الشاشة.
      return 'SELECT c.* FROM "clothing" c LEFT JOIN "invoice_items" i ON i."clothing_id" = c."clothing_id" WHERE c."is_active" = 1 GROUP BY c."clothing_id" ORDER BY COALESCE(SUM(i."qty"), 0) DESC, c."clothing_name" ASC';
    }
    const base = 'SELECT * FROM "clothing" WHERE "is_active" = 1';
    final order = orderBy;
    return order == null ? base : '$base ORDER BY $order';
  }

  // ─── الأنماط ───────────────────────────────────────────────────────────

  static const ClothingSort unsorted = ClothingSort(
    key: 'unsorted',
    label: 'بدون فرز',
    description: 'ترتيب الإدخال في القاعدة — الأسرع',
    orderBy: null,
  );

  static const ClothingSort nameAsc = ClothingSort(
    key: 'name_asc',
    label: 'الاسم: أ ← ي',
    description: 'أبجدي صاعد',
    orderBy: '"clothing_name" ASC',
  );

  static const ClothingSort nameDesc = ClothingSort(
    key: 'name_desc',
    label: 'الاسم: ي ← أ',
    description: 'أبجدي نازل',
    orderBy: '"clothing_name" DESC',
  );

  static const ClothingSort priceAsc = ClothingSort(
    key: 'price_asc',
    label: 'السعر: الأقل أولًا',
    description: 'الأرخص أولًا — سعر الغسيل والكوي العادي',
    orderBy: '"normal_washing_and_ironing_price" ASC, "clothing_name" ASC',
  );

  static const ClothingSort priceDesc = ClothingSort(
    key: 'price_desc',
    label: 'السعر: الأعلى أولًا',
    description: 'الأغلى أولًا — سعر الغسيل والكوي العادي',
    orderBy: '"normal_washing_and_ironing_price" DESC, "clothing_name" ASC',
  );

  static const ClothingSort bestSelling = ClothingSort(
    key: 'best_selling',
    label: 'الأكثر مبيعًا',
    description: 'مجموع القطع المباعة من كل صنف',
    // `grouped` يتجاوز `orderBy` — الاستعلام المجمَّع يبني ترتيبه بنفسه.
    orderBy: null,
    grouped: true,
  );

  static const ClothingSort newest = ClothingSort(
    key: 'newest',
    label: 'الأحدث إضافة',
    description: 'آخر ما أضفته أولًا',
    orderBy: '"clothing_id" DESC',
  );

  static const ClothingSort oldest = ClothingSort(
    key: 'oldest',
    label: 'الأقدم',
    description: 'أول ما أضفته أولًا',
    orderBy: '"clothing_id" ASC',
  );

  /// كل الأنماط بترتيب العرض في القائمة.
  static const List<ClothingSort> all = <ClothingSort>[
    nameAsc,
    nameDesc,
    unsorted,
    priceAsc,
    priceDesc,
    bestSelling,
    newest,
    oldest,
  ];

  /// النمط المسجَّل بمفتاحه، والافتراضي عند مفتاح مجهول أو فارغ.
  ///
  /// **لا يرمي ولا يعيد `null`**: قيمة تالفة في القاعدة (أو مفتاح من إصدار
  /// سابق حُذف) يجب أن تُنتج قائمة مرتّبة لا شاشة فارغة.
  static ClothingSort byKey(String? key) {
    final k = (key ?? '').trim();
    for (final s in all) {
      if (s.key == k) return s;
    }
    return nameAsc;
  }

  static List<String> get keys =>
      all.map((s) => s.key).toList(growable: false);

  static Map<String, String> get labels => <String, String>{
    for (final s in all) s.key: s.label,
  };

  @override
  String toString() => 'ClothingSort($key)';
}
