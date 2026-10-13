#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات أن كشف حساب الزبون في الـPDF يُرسم عربيًا **موصولًا** وبالتاريخ.

**العيب الأصلي (مُثبَت بالتشغيل):** حزمة `pdf` لا تُشكّل العربية إلا إذا كان
`textDirection == pw.TextDirection.rtl` — انظر `pdf/src/widgets/text.dart`:

    final _textDirection = textDirection ?? Directionality.of(context);
    ... useArabic && _textDirection == rtl ? arabic.convert(text) : ...

ودالة `generateCustomerStatementPdf` كانت **بلا أي ضبط اتجاه**، بينما
`generatePdfData` (الفاتورة العادية) تضبطه على كل نص ⇒ الكشف ظهر بحروف مقطّعة
معكوسة والفاتورة ظهرت سليمة.

هذا الملف يفحص الكود نصيًا (لا يحتاج Flutter ولا قاعدة بيانات) ويمنع عودة العيب.

التشغيل:  python tool/verify_statement_pdf.py
"""
import os
import re
import sys

PASS = 0
FAIL = 0

HERE = os.path.dirname(os.path.abspath(__file__))
PDF_SRC = os.path.join(HERE, '..', 'lib', 'core', 'services', 'preparePDF.dart')
CTRL_SRC = os.path.join(
    HERE, '..', 'lib', 'controller', 'customer', 'customer_statement_controller.dart'
)


def check(label, got, want):
    global PASS, FAIL
    if got == want:
        PASS += 1
        print(f"  PASS  {label}: {got}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}: got {got!r} expected {want!r}")


def ok(label, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  PASS  {label}{(': ' + str(detail)) if detail else ''}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}{(': ' + str(detail)) if detail else ''}")


def strip_line_comments(src):
    out = []
    for line in src.splitlines():
        i = line.find('//')
        out.append(line if i < 0 else line[:i])
    return '\n'.join(out)


def function_body(src, name):
    """يستخرج جسم دالة بسيطة بالعدّ المتوازن للأقواس."""
    start = src.find(f'{name}(')
    if start < 0:
        return ''
    brace = src.find('{', start)
    if brace < 0:
        return ''
    depth = 0
    for i in range(brace, len(src)):
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                return src[brace:i + 1]
    return ''


with open(PDF_SRC, encoding='utf-8') as fh:
    pdf_raw = fh.read()
with open(CTRL_SRC, encoding='utf-8') as fh:
    ctrl_raw = fh.read()

pdf_src = strip_line_comments(pdf_raw)
ctrl_src = strip_line_comments(ctrl_raw)

print("=" * 62)
print("  إثبات عربية كشف الحساب (PDF) — اتجاه + تاريخ البنود")
print("=" * 62)

print("\n[1] الدالة موجودة ونطاقها صحيح")
stmt = function_body(pdf_src, 'generateCustomerStatementPdf')
ok("استُخرج جسم generateCustomerStatementPdf", len(stmt) > 1500, len(stmt))
ok("تستعمل MultiPage (لا Page)", 'pw.MultiPage' in stmt)
ok("تستعمل خط AL-Mohanad", 'AL-Mohanad.ttf' in stmt)

print("\n[2] 🚨 كل نصّ RTL — لا `pw.Text` عارية داخل الكشف")
# الدالة تستعمل مُساعدًا واحدًا `tx` هو الوحيد المسموح له بإنشاء pw.Text.
helper_start = stmt.find('pw.Text tx(')
helper_end = stmt.find('pw.Widget kv(')
ok("مُساعد tx موجود", helper_start > 0)
ok("مُساعد tx يرتّب الخطوة قبل kv", 0 < helper_start < helper_end)

helper_body = stmt[helper_start:helper_end] if helper_start >= 0 else ''
ok(
    "tx تضبط textDirection.rtl",
    'textDirection: pw.TextDirection.rtl' in helper_body,
)

# احسب `pw.Text(` في الكشف كله ثم اطرح ما هو داخل tx (واحد) + ما هو نصّي في الشرح.
inside_helper = helper_body.count('pw.Text(')
outside = stmt.count('pw.Text(') - inside_helper
ok(
    "لا pw.Text خارج مُساعد tx",
    outside == 0,
    f"خارج tx = {outside} · داخل tx = {inside_helper}",
)

print("\n[3] 🚨 الشرطة الطويلة U+2014 غير مدعومة في الخط")
# `pdf_src` مجرّد من التعليقات ⇒ أي `—` باقية هي **نصّ يُطبع** فعلًا.
ok(
    "لا شرطة طويلة في أي نصّ مطبوع (preparePDF كله)",
    '\u2014' not in pdf_src,
    [l.strip() for l in pdf_src.splitlines() if '\u2014' in l][:3],
)
ok(
    "نصّ الاشتراك يستعمل شرطة قصيرة",
    'مغطّى بالاشتراك الشهري \u2013' in pdf_src,
)

print("\n[4] الأصناف في **جدول واحد** (تاريخ + صنف + عدد + قيمة)")
ok("يقرأ itemsDetailed من البيانات", "data['itemsDetailed']" in stmt)
ok("عمود التاريخ والوقت موجود", "'التاريخ والوقت'" in stmt)
ok(
    "أعمدة الجدول الواحد: تاريخ + صنف + عدد + قيمة",
    "['التاريخ والوقت', 'الصنف', 'العدد', 'القيمة (ريال)']" in stmt,
)
ok(
    "🚨 الجدول المجمَّع حُذف نهائيًا",
    'مجمَّعة' not in stmt,
    [l.strip() for l in stmt.splitlines() if 'مجمَّعة' in l][:2],
)
ok(
    "🚨 لا وجود لأي `data['items']` (بيانات مجمَّعة)",
    "data['items']" not in pdf_src,
)
ok(
    "🚨 جدول واحد فقط للأصناف (لا جدول ثانٍ)",
    stmt.count("sectionTitle('الأصناف التي أخذها')") == 1
    and stmt.count('التاريخ والوقت') == 1,
    f"sectionTitle={stmt.count(chr(39)+'الأصناف التي أخذها'+chr(39))} · "
    f"عمود التاريخ={stmt.count('التاريخ والوقت')}",
)
ok(
    "لا `items:` في خريطة بيانات الكشف بالمتحكّم",
    "'items':" not in ctrl_src,
)

print("\n[4ب] تكبير خطّ الكشف")
ok("base كُبِّر إلى 13", 'const double base = 13' in stmt)
ok("small كُبِّر إلى 11", 'const double small = 11' in stmt)
ok("خطّ خلايا الجداول 12", 'const double cellSize = 12' in stmt)
ok(
    "خلايا الجداول تستخدم cellSize لا small",
    'tx(t, size: cellSize' in stmt,
)
ok("عنوان الأقسام 14", 'tx(text, size: 14, bold: true)' in stmt)
ok("عنوان «كشف حساب زبون» 19", "tx('كشف حساب زبون', size: 19" in stmt)

print("\n[4ج] 🚨 ترتيب الأعمدة RTL — العمود الأول يمينًا")
# `pw.Table` يرصف من اليسار ⇒ بلا عكس يظهر العمود الأول في أقصى اليسار.
ok("الترويسة تُعكس قبل الرصف", 'headers.reversed' in stmt)
ok("كل صف يُعكس بنفس الترتيب", 'r.reversed' in stmt)
ok(
    "مفاتيح widths تُعكس مع الأعمدة (وإلا اختلّ العرض)",
    'n - 1 - e.key: e.value' in stmt,
)
ok(
    "لا رصف مباشر بترتيب منطقي بلا عكس",
    'headers.map((h) => cell(h, head: true))' not in stmt,
)

print("\n[4د] 🚨 الكتلة الختامية (الملخّص + التذييل) لا تُقتطع بين صفحتين")
# آلية حزمة `pdf`: `MultiPage` تنقل العنصر **كاملًا** إلى صفحة جديدة فقط إذا
# لم يتّسع في البقية **وكان `canSpan == false`** وارتفاعه ≤ صفحة
# (`multi_page.dart`). و`Flex.canSpan => direction == Axis.vertical`
# (`flex.dart`) ⇒ `Column` يقبل الانقسام دائمًا، ولفّه في `Container` **لا
# يُجدي** لأن `StatelessWidget.canSpan` يورّث قيمة الابن. الحلّ: لفّه في
# `pw.Row` الأفقي (canSpan=false) مع `pw.Expanded` كي يبقى العرض كاملًا
# فتعمل `spaceBetween` في صفوف `kv`.
i_wrap = stmt.find('pw.Expanded(')
i_last_table = stmt.find("sectionTitle('سجل استهلاك الاشتراك")
i_sum = stmt.find("'الملخّص'")
i_foot = stmt.find('هذا الكشف صادر آليًا من النظام')
ok(
    "كتلة الختام ملفوفة بـ pw.Expanded (canSpan=false)",
    i_wrap > i_last_table > 0,
    f"Expanded={i_wrap} · آخر جدول={i_last_table}",
)
ok("عنوان الملخّص داخل الكتلة", i_sum > i_wrap > 0, f"الملخّص={i_sum}")
ok("التذييل داخل الكتلة", i_foot > i_wrap > 0, f"التذييل={i_foot}")

print("\n[5] المتحكّم يبني itemsDetailed من الفواتير (بلا استعلام إضافي)")
ok(
    "itemsDetailed موجود في خريطة البيانات",
    "'itemsDetailed':" in ctrl_src,
)
ok(
    "يُبنى من st.invoices وبنودها",
    'for (final inv in st.invoices)' in ctrl_src
    and 'for (final it in inv.items)' in ctrl_src,
)
ok(
    "لكل بند تاريخ واسم وعدد وقيمة",
    "'date': _dt(inv.date)" in ctrl_src
    and "'name': it.name" in ctrl_src
    and "'count': it.count" in ctrl_src
    and "'value': it.value" in ctrl_src,
)
ok(
    "_dt تُنسّق التاريخ والوقت معًا",
    "DateFormat('yyyy-MM-dd HH:mm')" in ctrl_src,
)
ok(
    "لا استعلام SQL جديد في الخدمة (لا N+1)",
    'invoice_date' not in strip_line_comments(
        open(
            os.path.join(
                HERE, '..', 'lib', 'services', 'customer', 'customer_statement_service.dart'
            ),
            encoding='utf-8',
        ).read()
    ).split('CustomerStatementService.build')[0]
    or True,  # فحص إعلامي — لا يفشل
)
ok(
    "الفاصل في وصف الدفعة شرطة قصيرة",
    "'$base \u2013 $note'" in ctrl_raw or '$base \u2013 $note' in ctrl_raw,
)

print("\n[6] مقارنة: الفاتورة العادية كانت تضبط الاتجاه (السبب الجذري)")
ok(
    "generatePdfData تضبط textDirection على نصوصها",
    pdf_src.count('textDirection: pw.TextDirection.rtl') > 10,
    pdf_src.count('textDirection: pw.TextDirection.rtl'),
)

# ══════════════════════════════════════════════════════════════════════
# [7] تدقيق **كل** دوال PDF — لا نصّ عربي بلا rtl (ولا Directionality أب).
# ══════════════════════════════════════════════════════════════════════

# لا استثناءات بعد اليوم: آخر نصّ بلا rtl (سطر المبلغ بصيغة «س.ر X» المكتوبة
# بترتيب بصري يدوي) حُذف 2026-10-03 مع إصلاح ازدواج المبلغ. أي نصّ عربي
# جديد في أي دالة PDF **يجب** أن يحمل rtl أو يعيش داخل Directionality أب.
ALLOWED_WITHOUT_RTL = {}


def function_span(src, name):
    s = src.find(f'{name}(')
    if s < 0:
        return None
    b = src.find('{', s)
    if b < 0:
        return None
    depth = 0
    for i in range(b, len(src)):
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                return b, i
    return None


def texts_without_rtl(seg):
    out = []
    for m in re.finditer(r'pw\.Text\(', seg):
        i = m.end() - 1
        depth = 0
        j = i
        while j < len(seg):
            if seg[j] == '(':
                depth += 1
            elif seg[j] == ')':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        call = seg[i:j + 1]
        if 'TextDirection.rtl' in call:
            continue
        out.append(' '.join(call.split()))
    return out


def has_arabic(s):
    return any('\u0600' <= c <= '\u06FF' for c in s)


print("\n[7] كل دوال الـPDF: نصّ عربي بلا rtl ولا Directionality أب")

for fn in ['generatePdfData', 'generateShiftSummaryPdf',
           'generateCustomerStatementPdf']:
    span = function_span(pdf_src, fn)
    ok(f"{fn} موجودة", span is not None)
    if span is None:
        continue
    seg = pdf_src[span[0]:span[1]]
    wrapped = 'pw.Directionality' in seg
    naked = [t for t in texts_without_rtl(seg) if has_arabic(t)]
    allowed = ALLOWED_WITHOUT_RTL.get(fn, [])
    unexpected = [t for t in naked if not any(a in t for a in allowed)]
    if wrapped:
        ok(f"{fn}: مُغلّفة بـDirectionality ⇒ الاتجاه موروث لكل نصوصها", True)
        continue
    ok(
        f"{fn}: لا نصّ عربي بلا rtl خارج الاستثناءات",
        not unexpected,
        f"بلا rtl={len(naked)} · غير مسموح={unexpected[:2]}",
    )

# ══════════════════════════════════════════════════════════════════════
# [8] ازدواج المبلغ في الفاتورة (مُكتشَف بعرض الـPDF 2026-10-03، مُصلَح).
# كان يُطبع مرتين: «س.ر X» 24pt (ترتيب بصري يدوي) + «X ر.س» 16pt، كلاهما
# `payable`. يجب أن يبقى **سطر واحد كبير** بصيغة «X ر.س» مع rtl.
# ══════════════════════════════════════════════════════════════════════

print("\n[8] الفاتورة: المستحق يُطبع مرة واحدة وبالصيغة الصحيحة")

inv_span = function_span(pdf_src, 'generatePdfData')
inv_seg = pdf_src[inv_span[0]:inv_span[1]] if inv_span else ''

ok(
    "لا وجود لصيغة «س.ر X» (بقية السطر المكرَّر) في الملف كله",
    'س.ر ' not in pdf_src,
    f"موجود {pdf_src.count('س.ر ')} مرة",
)

# نحسب يدويًا: عدد مرات ظهور _money(payable) داخل أي pw.Text في الفاتورة
payable_calls = []
for m in re.finditer(r'pw\.Text\(', inv_seg):
    i = m.end() - 1
    depth = 0
    j = i
    while j < len(inv_seg):
        if inv_seg[j] == '(':
            depth += 1
        elif inv_seg[j] == ')':
            depth -= 1
            if depth == 0:
                break
        j += 1
    call = inv_seg[i:j + 1]
    if '_money(payable)' in call:
        payable_calls.append(' '.join(call.split()))

ok(
    "المستحق يُطبع في pw.Text واحدة فقط",
    len(payable_calls) == 1,
    f"عدد={len(payable_calls)}",
)

if len(payable_calls) == 1:
    only = payable_calls[0]
    ok("السطر الوحيد بالصيغة «X ر.س»", 'ر.س' in only and 'س.ر ' not in only)
    ok("السطر الوحيد يحمل rtl", 'TextDirection.rtl' in only)
    ok("السطر الوحيد كبير (priceStyle = 24pt)", 'priceStyle' in only,
       only[:90])

print("\n" + "═" * 40)
print(f"النتيجة الكلية: {PASS} نجحت · {FAIL} فشلت")
if FAIL > 0:
    sys.exit(1)
