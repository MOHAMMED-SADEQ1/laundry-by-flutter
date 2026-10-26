// حالات المصنعية — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// القاعدة نفسها المطبَّقة على طرق الدفع: **الرمز يُخزَّن، والتسمية تُعرض**.
// كان يُخزَّن `'تم الاستلام'` نصًّا عربيًّا في `invoices.status`، فيظهر عربيًّا
// في الواجهة الإنجليزية، وأي إعادة صياغة تسمية تكسر كل الفلاتر القديمة.
//
// عقد الرجوع: [tryParse] يقبل الرمز والعربي معًا، فقاعدة لم تُرحَّل بعد تُقرأ
// صحيحة، والترحيل في `sqldb.dart` يكتب الرموز مرة واحدة.

import 'package:laundry/services/i18n/l10n.dart';

enum ProcessingStatus {
  received('received', 'تم الاستلام'),
  inProgress('in_progress', 'قيد التنفيذ'),
  ready('ready', 'جاهز للاستلام'),
  delivered('delivered', 'تم التسليم');

  const ProcessingStatus(this.key, this.arabicLabel);

  /// ما يُخزَّن في `invoices.status`. لا يتغيّر أبدًا.
  final String key;

  /// التسمية العربية — مفتاح في قاموس `kEnglish`.
  final String arabicLabel;

  /// التسمية بلغة الواجهة الحالية.
  String get label => tr(arabicLabel);
}

class ProcessingStatuses {
  ProcessingStatuses._();

  static const ProcessingStatus received = ProcessingStatus.received;
  static const ProcessingStatus inProgress = ProcessingStatus.inProgress;
  static const ProcessingStatus ready = ProcessingStatus.ready;
  static const ProcessingStatus delivered = ProcessingStatus.delivered;

  static const List<ProcessingStatus> all = <ProcessingStatus>[
    ProcessingStatus.received,
    ProcessingStatus.inProgress,
    ProcessingStatus.ready,
    ProcessingStatus.delivered,
  ];

  static const Map<String, ProcessingStatus> _aliases =
      <String, ProcessingStatus>{
        'received': ProcessingStatus.received,
        'in_progress': ProcessingStatus.inProgress,
        'ready': ProcessingStatus.ready,
        'delivered': ProcessingStatus.delivered,
        'تم الاستلام': ProcessingStatus.received,
        'قيد التنفيذ': ProcessingStatus.inProgress,
        'جاهز للاستلام': ProcessingStatus.ready,
        'تم التسليم': ProcessingStatus.delivered,
      };

  static ProcessingStatus? tryParse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    return _aliases[text] ?? _aliases[text.toLowerCase()];
  }

  /// الرمز المخزَّن لأي قيمة مقروءة — مع سقوط آمن إلى «تم الاستلام».
  static String keyOf(String? raw) =>
      tryParse(raw)?.key ?? ProcessingStatus.received.key;

  /// التسمية بلغة الواجهة. تقبل الرمز أو العربي أو الـ enum نفسه.
  static String label(Object? raw) {
    final status =
        raw is ProcessingStatus ? raw : tryParse(raw?.toString());
    if (status != null) return status.label;
    final text = (raw ?? '').toString().trim();
    return text.isEmpty ? ProcessingStatus.received.label : text;
  }

  /// كل الرموز بالترتيب.
  static List<String> get keys =>
      all.map((s) => s.key).toList(growable: false);

  /// القيم العربية القديمة التي يجب أن تختفي من التخزين بعد الترحيل.
  static const List<String> legacyValues = <String>[
    'تم الاستلام',
    'قيد التنفيذ',
    'جاهز للاستلام',
    'تم التسليم',
  ];
}
