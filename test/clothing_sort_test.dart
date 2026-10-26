// اختبار انحدار: ترتيب أصناف اللبس في شاشة البيع.
//
// **الخطأ الذي يحرسه:** «خيار فرز» يعرض قائمة مرتّبة في الذاكرة فقط، فيعود
// الترتيب القديم عند إعادة فتح الشاشة (أو عند أول إضافة صنف) — لأن الترتيب
// في `ORDER BY` لا في `List.sort`. لذلك كل اختبار هنا ينفّذ **الاستعلام
// الحقيقي** على SQLite حقيقية (sqflite_common_ffi) ويقرأ ترتيب الصفوف الناتج،
// ولا يثق في شكل النصّ.
//
// بيانات الاختبار مختارة لتكشف الأخطاء الشائعة:
//   • «بنطلون» بلا أي مبيعة  ⇒ يكشف `JOIN` بدل `LEFT JOIN` (كان سيختفي).
//   • «جوارب قديمة» معطَّلة  ⇒ يكشف نسيان `is_active = 1` (كانت ستظهر).
//   • سعران متساويان (4)    ⇒ يكشف غياب الترتيب الثانوي بالاسم (نتيجة غير ثابتة).

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// أسماء الأصناف بترتيب الإدخال (١..٦) — غير أبجدي ولا سعري عمدًا.
const List<List<Object>> _seed = <List<Object>>[
  // [الاسم, السعر, عدد القطع المباعة, نشط]
  <Object>['ثوب أبيض', 5.0, 10, 1], // id=1
  <Object>['قميص', 8.0, 3, 1], // id=2
  <Object>['غترة', 4.0, 7, 1], // id=3
  <Object>['بنطلون', 12.0, 0, 1], // id=4 — لم يُبع قط
  <Object>['شماغ', 4.0, 1, 1], // id=5 — سعر مساوٍ لغترة
  <Object>['جوارب قديمة', 3.0, 99, 0], // id=6 — معطَّل: لا يظهر أبدًا
];

Future<Database> _open() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE "clothing" (
      "clothing_id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "clothing_name" TEXT NOT NULL,
      "normal_washing_and_ironing_price" REAL DEFAULT 0,
      "is_active" INTEGER DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE "invoice_items" (
      "item_id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "invoice_id" INTEGER NOT NULL,
      "clothing_id" INTEGER,
      "item_name" TEXT NOT NULL,
      "qty" INTEGER DEFAULT 0
    )
  ''');
  for (var i = 0; i < _seed.length; i++) {
    final row = _seed[i];
    await db.insert('clothing', <String, Object?>{
      'clothing_name': row[0],
      'normal_washing_and_ironing_price': row[1],
      'is_active': row[3],
    });
    final qty = row[2] as int;
    if (qty > 0) {
      await db.insert('invoice_items', <String, Object?>{
        'invoice_id': 1,
        'clothing_id': i + 1,
        'item_name': row[0],
        'qty': qty,
      });
    }
  }
  return db;
}

/// ينفّذ استعلام النمط ويعيد الأسماء بترتيب الصفوف الناتج.
Future<List<String>> _order(Database db, ClothingSort sort) async {
  final rows = await db.rawQuery(sort.query);
  return rows.map((r) => r['clothing_name'] as String).toList();
}

void main() {
  late Database db;

  setUp(() async => db = await _open());
  tearDown(() async => db.close());

  group('ترتيب الأصناف — استعلام حقيقي على SQLite', () {
    test('الاسم أ ← ي', () async {
      // ب(0628) < ث(062B) < ش(0634) < غ(063A) < ق(0642)
      expect(await _order(db, ClothingSort.nameAsc), <String>[
        'بنطلون',
        'ثوب أبيض',
        'شماغ',
        'غترة',
        'قميص',
      ]);
    });

    test('الاسم ي ← أ', () async {
      expect(
        await _order(db, ClothingSort.nameDesc),
        (await _order(db, ClothingSort.nameAsc)).reversed.toList(),
      );
    });

    test('بدون فرز = ترتيب الإدخال', () async {
      expect(await _order(db, ClothingSort.unsorted), <String>[
        'ثوب أبيض',
        'قميص',
        'غترة',
        'بنطلون',
        'شماغ',
      ]);
    });

    test('السعر: الأقل أولًا مع ترتيب ثانوي بالاسم', () async {
      // 4 لشماغ وغترة: عند التساوي يفصل الاسم لا الصفّ العشوائي.
      expect(await _order(db, ClothingSort.priceAsc), <String>[
        'شماغ',
        'غترة',
        'ثوب أبيض',
        'قميص',
        'بنطلون',
      ]);
    });

    test('السعر: الأعلى أولًا', () async {
      expect(await _order(db, ClothingSort.priceDesc), <String>[
        'بنطلون',
        'قميص',
        'ثوب أبيض',
        'شماغ',
        'غترة',
      ]);
    });

    test('الأكثر مبيعًا — والصنف غير المبيع يظهر أخيرًا لا يختفي', () async {
      expect(await _order(db, ClothingSort.bestSelling), <String>[
        'ثوب أبيض', // 10
        'غترة', // 7
        'قميص', // 3
        'شماغ', // 1
        'بنطلون', // 0 — LEFT JOIN لا JOIN
      ]);
    });

    test('الأحدث إضافة / الأقدم', () async {
      expect(await _order(db, ClothingSort.newest), <String>[
        'شماغ',
        'بنطلون',
        'غترة',
        'قميص',
        'ثوب أبيض',
      ]);
      expect(
        await _order(db, ClothingSort.oldest),
        (await _order(db, ClothingSort.newest)).reversed.toList(),
      );
    });

    test('الصنف المعطَّل لا يظهر في أي نمط — ولا في الأكثر مبيعًا', () async {
      for (final s in ClothingSort.all) {
        final names = await _order(db, s);
        expect(names, isNot(contains('جوارب قديمة')), reason: s.key);
        expect(names.length, 5, reason: s.key);
      }
    });

    test('كل نمط يعيد المجموعة نفسها (لا نمط يُسقط أصنافًا)', () async {
      final sets = <String>[];
      for (final s in ClothingSort.all) {
        final names = (await _order(db, s)).toSet().toList()..sort();
        sets.add(names.join(','));
      }
      final first = sets.first;
      for (var i = 1; i < sets.length; i++) {
        expect(sets[i], first, reason: ClothingSort.all[i].key);
      }
    });

    test('الترتيب ينعكس عند عكس النمط (لا نمط «نازل» يعطي ترتيبًا صاعدًا)', () async {
      for (final pair in <List<ClothingSort>>[
        <ClothingSort>[ClothingSort.nameAsc, ClothingSort.nameDesc],
        <ClothingSort>[ClothingSort.oldest, ClothingSort.newest],
      ]) {
        expect(
          await _order(db, pair[1]),
          (await _order(db, pair[0])).reversed.toList(),
          reason: '${pair[0].key} ↔ ${pair[1].key}',
        );
      }
    });

    test('صنف جديد يُدرَج يظهر أولًا في «الأحدث» وآخرًا في «الأقدم»', () async {
      await db.insert('clothing', <String, Object?>{
        'clothing_name': 'طاقية',
        'normal_washing_and_ironing_price': 1.0,
        'is_active': 1,
      });
      expect((await _order(db, ClothingSort.newest)).first, 'طاقية');
      expect((await _order(db, ClothingSort.oldest)).last, 'طاقية');
    });
  });
}
