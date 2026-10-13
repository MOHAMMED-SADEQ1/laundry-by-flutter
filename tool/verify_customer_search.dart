// فحوص منطق البحث عن الزبائن — **خالص** بلا Flutter وبلا قاعدة بيانات.
//
// التشغيل:  dart run tool/verify_customer_search.dart
//
// **لماذا:** البحث برقم الجوال لم يكن يعمل في قائمة الزبائن رغم أن تلميح
// الشاشة ينصّ على «بالاسم أو الرقم» (الفلترة كانت بالاسم وحده). فهذه الفحوص
// تُثبت: المطابقة بالاسم وأي من الرقمين، تجاهل الفواصل والشرطات، الأرقام
// العربية، وأن شرط SQL كله بمعاملات `?` بلا قيمة واحدة مدموجة في النص.
// ignore_for_file: avoid_print

import 'package:laundry/services/customer/customer_search.dart';

int _pass = 0;
int _fail = 0;

void check(String label, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  ✅ $label');
  } else {
    _fail++;
    print('  ❌ $label${detail == null ? '' : '  →  $detail'}');
  }
}

Map<String, dynamic> customer({
  int id = 1,
  String name = 'أحمد',
  String? phone1 = '0555123456',
  String? phone2,
}) => {
  'customer_id': id,
  'customer_name': name,
  'phone_1': phone1,
  'phone_2': phone2,
};

int _placeholders(String where) => '?'.allMatches(where).length;

void main() {
  print('── التطبيع ─────────────────────');
  check('فراغات الطرفين', CustomerSearch.normalize('  أحمد  ') == 'أحمد');
  check(
    'توحيد الفراغات الداخلية',
    CustomerSearch.normalize('أحمد    علي') == 'أحمد علي',
  );
  check('نص فراغات فقط', CustomerSearch.normalize('    ') == '');

  print('── تحويل الأرقام ──────────────');
  check('عربية → لاتينية', CustomerSearch.toWesternDigits('٠٥٥٥') == '0555');
  check('هندية → لاتينية', CustomerSearch.toWesternDigits('۰۵۵۵') == '0555');
  check('نص مختلط', CustomerSearch.toWesternDigits('a٥b') == 'a5b');
  check(
    'أرقام الجوال وحدها',
    CustomerSearch.phoneDigits('0555 123-456') == '0555123456',
  );
  check(
    'حذف + والأقواس',
    CustomerSearch.phoneDigits('+966 (55) 5-12') == '96655512',
  );
  check(
    'أرقام عربية في الهاتف',
    CustomerSearch.phoneDigits('٠٥٥٥-١٢٣') == '0555123',
  );

  print('── المطابقة بالاسم ────────────');
  check('اسم كامل', CustomerSearch.matches(customer(), 'أحمد'));
  check('جزء من الاسم', CustomerSearch.matches(customer(), 'حم'));
  check(
    'إنجليزية بلا حساسية لحالة الأحرف',
    CustomerSearch.matches(customer(name: 'Ahmed Ali'), 'ahmed'),
  );
  check('بحث فارغ يُطابق الكل', CustomerSearch.matches(customer(), '   '));

  print('── حرس «يبدو رقمًا» ───────────');
  check('رقم بفواصل', CustomerSearch.looksLikePhone('0555 123'));
  check('رقم بأرقام عربية', CustomerSearch.looksLikePhone('٠٥٥٥١٢٣'));
  check('رقم بشرطات وأقواس', CustomerSearch.looksLikePhone('(05)-55'));
  check('نص فيه حروف ليس رقمًا', !CustomerSearch.looksLikePhone('محمد 5'));
  check('نص فارغ ليس رقمًا', !CustomerSearch.looksLikePhone(''));
  check(
    'اسم فيه رقم لا يُطابق أرقام زبائن آخرين',
    !CustomerSearch.matches(
      customer(name: 'زبون آخر', phone1: '0555123456'),
      'محمد 5',
    ),
  );
  check(
    'اسم فيه رقم يُطابق نفسه',
    CustomerSearch.matches(customer(name: 'محمد 5', phone1: null), 'محمد 5'),
  );

  print('── المطابقة بالجوال ───────────');
  check('رقم كامل', CustomerSearch.matches(customer(), '0555123456'));
  check('جزء من الرقم', CustomerSearch.matches(customer(), '5123'));
  check(
    'رقم مكتوب بمسافات يطابق المخزَّن متصلًا',
    CustomerSearch.matches(customer(), '0555 123 456'),
  );
  check(
    'رقم بالأرقام العربية',
    CustomerSearch.matches(customer(), '٠٥٥٥١٢٣٤٥٦'),
  );
  check(
    'الرقم الثاني (phone_2)',
    CustomerSearch.matches(customer(phone1: '', phone2: '0509999999'), '0999'),
  );
  check('لا مطابقة', !CustomerSearch.matches(customer(), 'زياد'));
  check(
    'حقلا رقم فارغان لا يُطابقان',
    !CustomerSearch.matches(customer(phone1: '', phone2: ''), '0555'),
  );

  print('── الفلترة (بلا قاعدة بيانات) ──');
  final rows = [
    customer(id: 1, name: 'أحمد', phone1: '0555123456'),
    customer(id: 2, name: 'سعيد', phone1: '0509999999'),
    customer(id: 3, name: 'خالد', phone1: null, phone2: '0533000000'),
  ];
  check('بالاسم يُرجع واحدًا', CustomerSearch.filter(rows, 'سعيد').length == 1);
  check(
    'بالرقم يُرجع صاحبه',
    CustomerSearch.filter(rows, '53300').single['customer_id'] == 3,
  );
  check('بحث فارغ يُرجع الكل', CustomerSearch.filter(rows, '  ').length == 3);
  check(
    'الترتيب محفوظ',
    CustomerSearch.filter(rows, '').map((r) => r['customer_id']).join(',') ==
        '1,2,3',
  );

  print('── شرط SQL ─────────────────────');
  final byName = CustomerSearch.buildQuery('أحمد');
  check('ثلاثة شروط للاسم', byName.where.split(' OR ').length == 3);
  check('ثلاث قيم', byName.args.length == 3);
  check(
    'عدد ? يساوي عدد القيم',
    _placeholders(byName.where) == byName.args.length,
  );
  check('لا قيمة مدموجة في النص', !byName.where.contains('أحمد'));
  check(
    'القيم محاطة بـ %',
    byName.args.every(
      (a) => a.toString().startsWith('%') && a.toString().endsWith('%'),
    ),
  );
  check(
    'تجريد الفواصل على عمودي الجوال (5 فواصل × عمودين)',
    RegExp(r'REPLACE\(').allMatches(byName.where).length == 10,
  );

  final byPhone = CustomerSearch.buildQuery('0555 123');
  check('خمسة شروط للرقم المفوصل', byPhone.where.split(' OR ').length == 5);
  check('خمس قيم', byPhone.args.length == 5);
  check(
    'عدد ? يساوي عدد القيم (رقم)',
    _placeholders(byPhone.where) == byPhone.args.length,
  );
  check('لا رقم مدموج في النص', !byPhone.where.contains('0555'));
  check(
    'تعبيرا الجوال يتكرران لصيغة الأرقام',
    RegExp(r'REPLACE\(').allMatches(byPhone.where).length == 20,
  );

  final mixed = CustomerSearch.buildQuery('محمد 5');
  check(
    'نصّ فيه حروف لا يُضيف صيغة الأرقام',
    mixed.where.split(' OR ').length == 3,
  );
  check(
    'شرط النص المخلوط بمعاملات',
    _placeholders(mixed.where) == mixed.args.length,
  );

  final digitsOnly = CustomerSearch.buildQuery('0555123456');
  check(
    'لا شروط مكرّرة للأرقام المجرّدة',
    digitsOnly.where.split(' OR ').length == 3,
  );

  final symbols = CustomerSearch.buildQuery('%');
  check(
    'رموز البدل لا تُفشل البناء',
    _placeholders(symbols.where) == symbols.args.length,
  );

  check('الاسم بلا ذمم أو جداول أخرى', !byName.where.contains('customers'));

  print('\n════════════════════════════════════');
  print('النتيجة: $_pass نجحت · $_fail فشلت');
  if (_fail > 0) throw StateError('هناك فحوص فاشلة');
}
