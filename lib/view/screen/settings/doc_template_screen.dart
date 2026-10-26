/// **محرّر قوالب الطباعة** — تحكّم كامل في الورقة: كل عنصر يُفعَّل/يُعطَّل،
/// ونصّه يُحرَّر، و**حجم خطّه ووزنه وعرضه** يُضبطان، بلا مبرمج ولا إعادة بناء.
///
/// ## المشكلة التي يحلّها
/// كان تصميم الفاتورة وكشف الحساب مكتوبًا في الكود: `'رقم الإيصال: '` ·
/// `'السجل التجاري: '` · `'نسعد بتواصلكم عبر الأرقام:'` … وقرار الإظهار
/// موزّعًا على خيارات بعضها **ميّت لا يُقرأ**، والأحجام ثوابت (`20` · `12` ·
/// `27`) لا تُغيّر إلا بإعادة بناء التطبيق.
///
/// ## الحلّ
/// سجلّ واحد (`DocCatalog`) فيه كل حقل: معرّف · اسم · شرح · قسم · نصّ افتراضي
/// · **نمط افتراضي**. وهذه الشاشة تعرضه مجموعةً بأقسامه، ومع كل حقل **مفتاح
/// تفعيل** و**حقل نصّ** و**لوحة نمط** (حجم · وزن · عرض). والمولّدات الأربعة
/// تقرأ من القالب لا من الكود: الفاتورة · كشف الحساب · ملخّص الوردية · ورقة
/// المغسلة (تُفتح على تبويبها بـ`Get.arguments: DocKind.laundrySlip`).
///
/// ## قواعد التحرير
///   • **الفراغ = الافتراضي**: الحقل النصّي الفارغ يطبع نصّه الافتراضي (يظهر
///     كـ`hint`)، ولإخفاء السطر كاملًا يُعطَّل مفتاحه — فلا مستند بلا عناوين
///     لأن حقلًا تُرك فارغًا سهوًا.
///   • **حفظ تلقائي مؤجَّل**: كل تعديل يُحفظ بعد نصف ثانية (وما يبقى يُحفظ عند
///     الخروج)، فلا يضيع عمل المستخدم إن أغلق الشاشة بلا زرّ حفظ.
///   • **معاينة حيّة**: كل تعديل يظهر فورًا في البطاقة العلوية بنمطه.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/pdf/doc_template_service.dart';
import 'package:laundry/view/screen/settings/settings_pages.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

class DocTemplateScreen extends StatefulWidget {
  const DocTemplateScreen({super.key});

  @override
  State<DocTemplateScreen> createState() => _DocTemplateScreenState();
}

class _DocTemplateScreenState extends State<DocTemplateScreen> {
  final DocTemplateService _svc = DocTemplateService.instance;

  DocKind _kind = DocKind.invoice;
  bool _loading = true;

  /// تصفية الحقول بالاسم — ضرورية بعد أن صار في الفاتورة وحدها 33 حقلًا.
  String _filter = '';

  /// المسوّدات في الذاكرة — تُكتب إلى القاعدة بعد [Duration] من آخر تعديل.
  final Map<DocKind, DocTemplate> _draft = <DocKind, DocTemplate>{};

  /// متحكّمات حقول النصّ — مفتاحها `<kind>.<fieldKey>`.
  final Map<String, TextEditingController> _textCtl =
      <String, TextEditingController>{};

  Timer? _saveTimer;
  bool _saving = false;
  String? _savedAt;

  DocTemplate get _t => _draft[_kind] ?? DocTemplate.defaults(_kind);

  @override
  void initState() {
    super.initState();
    // يمكن فتح الشاشة مباشرة على تبويب محدَّد (مثل ورقة المغسلة من
    // «الطباعة وإخراج الفاتورة») بلا بحث عن التبويب.
    final arg = Get.arguments;
    if (arg is DocKind) _kind = arg;
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // أي تعديل معلّق يُحفظ قبل الخروج — وإلا ضاع بلا إشعار.
    // ⚠️ `ui: false`: الشجرة تُفكّ الآن، فأي `setState` هنا يرمي
    // «setState() called after dispose()» أو «element is defunct».
    if (_dirtyKinds.isNotEmpty) _flush(ui: false);
    for (final c in _textCtl.values) {
      c.dispose();
    }
    super.dispose();
  }

  final Set<DocKind> _dirtyKinds = <DocKind>{};

  Future<void> _load() async {
    for (final kind in DocKind.values) {
      _draft[kind] = await _svc.load(kind);
      for (final f in DocCatalog.fieldsOf(kind)) {
        if (!f.hasText) continue;
        _textCtl[_ctlKey(kind, f.key)] = TextEditingController(
          text: _draft[kind]!.texts[f.key] ?? '',
        );
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _ctlKey(DocKind kind, String field) => '${kind.name}.$field';

  /// يعدّل مسوّدة ويجدول حفظًا مؤجَّلًا.
  void _edit(DocTemplate next) {
    setState(() {
      _draft[next.kind] = next;
      _dirtyKinds.add(next.kind);
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _flush);
  }

  /// يحفظ كل المسوّدات المعدَّلة الآن.
  ///
  /// [ui] = false يعني «حفظ صامت» — يُستدعى من [dispose] حيث لا يجوز لمس
  /// الواجهة: `mounted` قد تبقى `true` لحظةً بينما العنصر صار `defunct`،
  /// فيرمي `setState` استثناءً يُسقط الشاشة عند الخروج.
  Future<void> _flush({bool ui = true}) async {
    if (_dirtyKinds.isEmpty || _saving) return;
    final kinds = _dirtyKinds.toList();
    _dirtyKinds.clear();
    if (ui && mounted) setState(() => _saving = true);
    try {
      for (final kind in kinds) {
        final t = _draft[kind];
        if (t == null) continue;
        await _svc.save(kind, t);
      }
      if (ui && mounted) {
        setState(() {
          _saving = false;
          _savedAt = TimeOfDay.now().format(context);
        });
      }
    } catch (e) {
      if (ui && mounted) {
        setState(() => _saving = false);
        Get.snackbar(
          tr('تعذّر الحفظ'),
          '$e',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> _resetCurrent() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(tr('استعادة الافتراضي')),
        content: Text(
          trf(
            tr('سيُعاد قالب «{0}» إلى نصوصه وتفعيلاته وأحجامه الأصلية، وتُفقد كل تعديلاتك عليه.'),
            [tr(DocCatalog.labelOf(_kind))],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(tr('استعادة')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _saveTimer?.cancel();
    final fresh = await _svc.reset(_kind);
    if (!mounted) return;
    setState(() {
      _draft[_kind] = fresh;
      _dirtyKinds.remove(_kind);
      for (final f in DocCatalog.fieldsOf(_kind)) {
        if (!f.hasText) continue;
        _textCtl[_ctlKey(_kind, f.key)]?.text = fresh.texts[f.key] ?? '';
      }
    });
    Get.snackbar(tr('تمّ'), tr('أُعيد القالب إلى الافتراضي'));
  }

  void _setAll(bool value) {
    _edit(_t.withAllEnabled(value));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      title: tr('قوالب الطباعة'),
      subtitle: tr(
        'تصميم الفاتورة وكشف الحساب وملخص الوردية وورقة المغسلة — نصًّا ونمطًا',
      ),
      children: [
        FadeInUp(delayMs: 0, child: _kindTabs()),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          FadeInUp(delayMs: 60, child: _previewCard()),
          const SizedBox(height: 14),
          FadeInUp(delayMs: 90, child: _toolbar()),
          const SizedBox(height: 14),
          for (var i = 0; i < DocSections.ordered.length; i++) ...[
            if (_fieldsIn(DocSections.ordered[i]).isNotEmpty)
              FadeInUp(
                delayMs: 120 + i * 40,
                child: _sectionCard(DocSections.ordered[i]),
              ),
            if (_fieldsIn(DocSections.ordered[i]).isNotEmpty)
              const SizedBox(height: 14),
          ],
          _statusLine(),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// حقول قسم — بعد تطبيق التصفية.
  List<DocField> _fieldsIn(String section) {
    final all = DocCatalog.fieldsIn(_kind, section);
    final q = _filter.trim();
    if (q.isEmpty) return all;
    return all
        .where(
          (f) => f.label.contains(q) || f.hint.contains(q) || f.key.contains(q),
        )
        .toList();
  }

  // ─── التبويبات: فاتورة / كشف حساب / ملخص وردية / ورقة مغسلة ───
  Widget _kindTabs() {
    return SoftCard(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final kind in DocKind.values) _kindTab(kind)],
      ),
    );
  }

  Widget _kindTab(DocKind kind) {
    final selected = _kind == kind;
    return InkWell(
      // مفتاح ثابت للتبويب: اسم المستند يظهر أيضًا في المعاينة، فالبحث
      // بالنصّ يجد أكثر من ودجة ويفشل النقر في الاختبارات.
      key: ValueKey<String>('doc-kind-${kind.name}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _kind = kind),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconOf(kind),
              size: 16,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              tr(DocCatalog.labelOf(kind)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconOf(DocKind kind) => switch (kind) {
    DocKind.invoice => Icons.receipt_long_outlined,
    DocKind.statement => Icons.description_outlined,
    DocKind.shift => Icons.point_of_sale_outlined,
    DocKind.laundrySlip => Icons.local_laundry_service_outlined,
  };

  // ─── المعاينة الحيّة ───
  Widget _previewCard() {
    final t = _t;
    final fields = DocCatalog.fieldsOf(_kind);
    final on = fields.where((f) => t.isOn(f.key)).toList();

    String sampleFor(DocField f) {
      switch (f.key) {
        case DocCatalog.kBusinessName:
          return t.textOf(f.key, tr('اسم النشاط')).trim().isEmpty
              ? tr('اسم النشاط')
              : t.textOf(f.key);
        case DocCatalog.kBusinessAddress:
          return t.textOf(f.key, tr('الرياض – حي النخيل'));
        case DocCatalog.kTitle:
          return t.textOf(f.key);
        case DocCatalog.kReceiptNo:
          return '${t.textOf(f.key)}: 1024';
        case DocCatalog.kDatetime:
          return '${t.textOf(f.key)}: 2026-10-24 09:30';
        case DocCatalog.kTaxNumber:
          return '${t.textOf(f.key)}: 300000000000003';
        case DocCatalog.kCrNumber:
          return '${t.textOf(f.key)}: 1010000000';
        case DocCatalog.kShortAddress:
          return '${t.textOf(f.key)}: RRAA1234';
        case DocCatalog.kCashier:
          return '${t.textOf(f.key)}: admin';
        case DocCatalog.kCustomerName:
          return trf('{0}: محمد صادق', [t.textOf(f.key)]);
        case DocCatalog.kCustomerPhone:
          return '${t.textOf(f.key)}: 05xxxxxxxx';
        case DocCatalog.kPickupCode:
          return '${t.textOf(f.key)}: 1234';
        case DocCatalog.kPhoneLine:
          return '${t.textOf(f.key)}  0500000000';
        case DocCatalog.kItemNote:
          return trf('{0}: بقعة زيت على الكم', [t.textOf(f.key)]);
        case DocCatalog.kItemName:
          return tr('قميص (قطن)');
        case DocCatalog.kService:
          return tr('غسيل + كوي');
        case DocCatalog.kQty:
          return '3';
        case DocCatalog.kEmptyItems:
          return t.textOf(f.key);
        case DocCatalog.kTotalPieces:
          return '${t.textOf(f.key)}: 6';
        case DocCatalog.kItemsCount:
          return '${t.textOf(f.key)}: 3';
        case DocCatalog.kWorkerSignature:
        case DocCatalog.kNotesSignature:
          return '${t.textOf(f.key)}: ________________';
        case DocCatalog.kBusinessPhone:
          return '0500000000';
        case DocCatalog.kSlipSubtitle:
          return t.textOf(f.key);
        case DocCatalog.kSlipNotice:
          return t.textOf(f.key);
        case DocCatalog.kItemLine:
          return tr('قميص (قطن)');
        case DocCatalog.kItemPrice:
          return '15.00';
        case DocCatalog.kGross:
          return '${t.textOf(f.key)}   100.00';
        case DocCatalog.kDiscount:
          return '${t.textOf(f.key)}   - 10.00';
        case DocCatalog.kTaxBase:
          return '${t.textOf(f.key)}   90.00';
        case DocCatalog.kTaxLine:
          return '${t.textOf(f.key)} 15%   13.50';
        case DocCatalog.kPaid:
          return trf('{0}: نقد', [t.textOf(f.key)]);
        case DocCatalog.kRemaining:
          return '${t.textOf(f.key)}: 0.00';
        case DocCatalog.kDue:
          return '${t.textOf(f.key)}   103.50';
        case DocCatalog.kSum:
          return '${t.textOf(f.key)}   100.00';
        case DocCatalog.kTotalAmount:
          return '103.50 ${t.textOf(DocCatalog.kCurrency)}';
        case DocCatalog.kSubsBadge:
          return t.textOf(f.key);
        case DocCatalog.kSubsNote:
          return t.textOf(f.key);
        case DocCatalog.kPeriod:
          return trf('{0}: من 2026-10-01 إلى 2026-10-24', [
            t.textOf(f.key),
          ]);
        case DocCatalog.kPrintedAt:
          return '${t.textOf(f.key)}: 2026-10-24 09:30';
        case DocCatalog.kSectionTitle:
          return tr('عنوان قسم');
        case DocCatalog.kSummaryTitle:
        case DocCatalog.kSummaryTitlePeriod:
          return t.textOf(f.key);
        case DocCatalog.kTotalsPurchases:
        case DocCatalog.kTotalsPaid:
        case DocCatalog.kTotalsDebt:
        case DocCatalog.kTotalsCredit:
        case DocCatalog.kTotalsNet:
          return '${t.textOf(f.key)}: 0.00 ${t.textOf(DocCatalog.kCurrency)}';
        case DocCatalog.kTotalsPieces:
          return '${t.textOf(f.key)}: 12';
        case DocCatalog.kTotalsSubPieces:
          return '${t.textOf(f.key)}: 3';
        case DocCatalog.kShiftId:
          return '${t.textOf(f.key)}: 14';
        case DocCatalog.kStartTime:
          return '${t.textOf(f.key)}: 2026-10-24 08:00';
        case DocCatalog.kEndTime:
          return '${t.textOf(f.key)}: 2026-10-24 20:00';
        case DocCatalog.kInvoiceCount:
          return '${t.textOf(f.key)}: 32';
        case DocCatalog.kTotalCash:
          return '${t.textOf(f.key)}: 1450.00 ${t.textOf(DocCatalog.kCurrency)}';
        case DocCatalog.kTotalNetwork:
          return '${t.textOf(f.key)}: 980.00 ${t.textOf(DocCatalog.kCurrency)}';
        case DocCatalog.kFooter:
          return t.textOf(f.key, tr('شكرًا لتعاملكم معنا'));
        case DocCatalog.kDivider:
          return '──────────────';
        case DocCatalog.kLogo:
          return tr('«شعار النشاط»');
        case DocCatalog.kQr:
          return tr('«رمز QR»');
        case DocCatalog.kPhotos:
          return tr('«صور القطع»');
        case DocCatalog.kItemsTable:
          return '«${t.textOf(f.key)}»';
        case DocCatalog.kInvoicesTable:
          return '«${t.textOf(f.key)}»';
        case DocCatalog.kPaymentsTable:
          return '«${t.textOf(f.key)}»';
        case DocCatalog.kUsagesTable:
          return '«${t.textOf(f.key)}»';
        case DocCatalog.kTotals:
          return tr('«ملخّص الإجماليات»');
        case DocCatalog.kCurrency:
          return t.textOf(f.key);
        default:
          return t.textOf(f.key, f.label);
      }
    }

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: tr('معاينة مباشرة'),
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (on.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      tr('كل العناصر معطَّلة — الورقة ستخرج فارغة.'),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                for (final f in on) _previewLine(f, sampleFor(f)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'المعاينة تُظهر النصّ وحجمه ووزنه وعرضه تقريبيًا (مصغَّرةً لتناسب الشاشة). المقاس النهائي يتبع مقاس الورق في صفحة الطباعة.',
            ),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// سطر معاينة واحد بنمط حقلِه.
  ///
  /// **لماذا `Transform.scale` للعرض؟** لأن `letterSpacing` في Flutter —
  /// كحزمة `pdf` — **يكسر اتصال الحروف العربية**، ولأن `fontVariations`
  /// لا تعمل إلا مع خطوط متغيّرة. فالتمديد الأفقي هو ما يحدث في الورق
  /// فعلًا، فنعرضه كما هو.
  Widget _previewLine(DocField f, String text) {
    final s = _t.styleOf(f.key);
    final scale = 0.5;
    final size = (s.size * scale).clamp(9.0, 20.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Transform.scale(
        scaleX: s.widthScale.clamp(0.9, 1.15),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: size,
            fontWeight:
                s.weight >= 600 ? FontWeight.w700 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── شريط الأدوات ───
  Widget _toolbar() {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _toolButton(
                icon: Icons.check_circle_outline,
                label: tr('تفعيل الكل'),
                onTap: () => _setAll(true),
              ),
              _toolButton(
                icon: Icons.remove_circle_outline,
                label: tr('إيقاف الكل'),
                onTap: () => _setAll(false),
              ),
              _toolButton(
                icon: Icons.restore,
                label: tr('استعادة الافتراضي'),
                onTap: _resetCurrent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('doc-template-filter'),
            textDirection: appTextDirection,
            style: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: tr('ابحث عن عنصر… (مثال: الشعار · الخصم · وقت البدء)'),
              hintStyle: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ─── بطاقة قسم ───
  Widget _sectionCard(String section) {
    final fields = _fieldsIn(section);
    final onCount = fields.where((f) => _t.isOn(f.key)).length;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(section),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // «حجم موحّد للقسم» — طلب المستخدم: التحكّم لكل قسم قسم.
              if (fields.any((f) => f.hasStyle))
                TextButton.icon(
                  onPressed: () => _applySectionStyle(section),
                  icon: const Icon(Icons.tune, size: 14),
                  label: Text(
                    tr('نمط القسم'),
                    style: const TextStyle(
                      fontFamily: 'cairo', fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$onCount / ${fields.length}',
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final f in fields) _fieldRow(f),
        ],
      ),
    );
  }

  /// يفتح ضبط النمط لكل حقول القسم دفعةً واحدة.
  Future<void> _applySectionStyle(String section) async {
    final fields = DocCatalog.fieldsIn(
      _kind,
      section,
    ).where((f) => f.hasStyle).toList();
    if (fields.isEmpty) return;
    var draft = _t.styleOf(fields.first.key);
    final result = await Get.dialog<DocStyle>(
      AlertDialog(
        title: Text(trf('نمط موحّد — {0}', [section])),
        content: SizedBox(
          width: 340,
          child: StatefulBuilder(
            builder:
                (context, setLocal) => _StyleControls(
                  value: draft,
                  onChanged: (v) => setLocal(() => draft = v),
                ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () => Get.back(result: draft),
            child: Text(tr('طبّق على القسم')),
          ),
        ],
      ),
    );
    if (result == null) return;
    _edit(_t.withSectionStyle(section, result));
    Get.snackbar(
      tr('تمّ'),
      trf('طُبِّق النمط على {0} عنصرًا', ['${fields.length}']),
    );
  }

  // ─── صفّ حقل واحد ───
  Widget _fieldRow(DocField f) {
    final t = _t;
    final on = t.isOn(f.key);
    final ctl = _textCtl[_ctlKey(_kind, f.key)];
    final fallback =
        f.defaultText.trim().isEmpty
            ? tr('من معلومات النشاط')
            : tr(f.defaultText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(f.label),
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color:
                            on ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    if (f.hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr(f.hint),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: on,
                onChanged: (v) => _edit(t.withField(f.key, enabled: v)),
              ),
            ],
          ),
          if (on && f.hasText) ...[
            const SizedBox(height: 6),
            TextField(
              // مفتاح ثابت للاختبار: يُميّز حقل النصّ عن حقل «البحث» في الشريط.
              key: ValueKey<String>('doc-text-${f.key}'),
              controller: ctl,
              textDirection: appTextDirection,
              style: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: fallback,
                hintStyle: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11.5,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
                helperText: trf('فارغ ⇒ «{0}»', [fallback]),
                helperStyle: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 9.5,
                  color: AppColors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (v) => _edit(t.withField(f.key, text: v)),
            ),
          ],
          if (on && f.hasStyle) ...[
            const SizedBox(height: 6),
            _StyleControls(
              key: ValueKey<String>('doc-style-${f.key}'),
              value: t.styleOf(f.key),
              onChanged: (v) => _edit(t.withField(f.key, style: v)),
              onReset: () => _edit(t.withField(f.key, style: f.style)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusLine() {
    final dirty = _dirtyKinds.isNotEmpty;
    final text =
        _saving
            ? tr('جارٍ الحفظ…')
            : dirty
            ? tr('تعديلات غير محفوظة بعد…')
            : _savedAt == null
            ? tr('كل شيء محفوظ')
            : trf('محفوظ · آخر حفظ {0}', ['$_savedAt']);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _saving || dirty ? Icons.cloud_upload_outlined : Icons.cloud_done,
          size: 14,
          color: _saving || dirty ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// **لوحة نمط الحقل** — الحجم · الوزن · العرض.
///
/// تُستخدم في مكانين: تحت كل حقل، وداخل حوار «نمط القسم» — فمنطق التعديل
/// واحد لا نسختان تختلفان بعد أول تعديل.
class _StyleControls extends StatelessWidget {
  const _StyleControls({
    super.key,
    required this.value,
    required this.onChanged,
    this.onReset,
  });

  final DocStyle value;
  final ValueChanged<DocStyle> onChanged;

  /// «استعادة الافتراضي لهذا الحقل» — غائب في حوار القسم.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _stepper(
            label: tr('الحجم'),
            display: _fmt(value.size),
            onMinus:
                value.size <= DocStyle.minSize
                    ? null
                    : () => onChanged(value.copyWith(size: value.size - 1)),
            onPlus:
                value.size >= DocStyle.maxSize
                    ? null
                    : () => onChanged(value.copyWith(size: value.size + 1)),
          ),
          _weightPicker(),
          _stepper(
            label: tr('العرض'),
            display: '${value.width}%',
            onMinus:
                value.width <= DocStyle.minWidth
                    ? null
                    : () => onChanged(value.copyWith(width: value.width - 5)),
            onPlus:
                value.width >= DocStyle.maxWidth
                    ? null
                    : () => onChanged(value.copyWith(width: value.width + 5)),
          ),
          if (onReset != null)
            Tooltip(
              message: tr('استعادة نمط هذا العنصر'),
              child: IconButton(
                onPressed: onReset,
                icon: const Icon(Icons.settings_backup_restore, size: 16),
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _stepper({
    required String label,
    required String display,
    VoidCallback? onMinus,
    VoidCallback? onPlus,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 10.5,
            color: AppColors.textSecondary,
          ),
        ),
        _miniIcon(Icons.remove, onMinus),
        SizedBox(
          width: 38,
          child: Text(
            display,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _miniIcon(Icons.add, onPlus),
      ],
    );
  }

  Widget _miniIcon(IconData icon, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Icon(
        icon,
        size: 15,
        color: onTap == null ? AppColors.textMuted : AppColors.primary,
      ),
    ),
  );

  Widget _weightPicker() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('الوزن'),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 10.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value.weight,
            isDense: true,
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            items: [
              for (final w in DocStyle.weights)
                DropdownMenuItem<int>(
                  value: w,
                  child: Text(
                    tr(DocStyle(weight: w).weightLabel),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight:
                          w >= 600 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
            ],
            onChanged: (w) {
              if (w != null) onChanged(value.copyWith(weight: w));
            },
          ),
        ),
      ],
    );
  }
}
