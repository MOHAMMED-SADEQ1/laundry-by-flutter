"""تحقّق من منطق تطبيع أرقام الواتساب (InvoiceShareService.normalizePhone).

منقول بدقة من Dart حتى نختبر الحالات الواقعية دون تشغيل التطبيق.
"""

import re
import sys


def normalize_phone(raw: str) -> str:
    """مرآة لـ InvoiceShareService.normalizePhone"""
    digits = re.sub(r"[^0-9+]", "", raw)
    if digits.startswith("+"):
        digits = digits[1:]
    if digits.startswith("00"):
        digits = digits[2:]
    if not digits:
        return ""
    if digits.startswith("0"):
        digits = "966" + digits[1:]
    elif len(digits) == 9 and digits.startswith("5"):
        digits = "966" + digits
    return digits


CASES = [
    ("0537498756", "966537498756", "صيغة محلية 05 — الحالة الأشيع"),
    ("+966537498756", "966537498756", "دولي بعلامة +"),
    ("00966537498756", "966537498756", "دولي ببادئة 00"),
    ("537498756", "966537498756", "9 أرقام تبدأ بـ 5 بلا صفر"),
    ("966537498756", "966537498756", "دولي بلا +"),
    ("0537 498 756", "966537498756", "بمسافات داخلية"),
    ("053-749-8756", "966537498756", "بشرطات"),
    ("0537498756 ", "966537498756", "بمسافة زائدة في الطرف"),
    ("", "", "فارغ"),
    ("abc", "", "غير رقمي"),
    ("0123456789", "966123456789", "رقم أرضي بصفر بادئ"),
    ("+966 53 749 8756", "966537498756", "دولي مع مسافات"),
]

print(f"{'input':<20} {'got':<15} {'expected':<15} {'':<5} note")
print("-" * 80)
fails = []
for raw, expected, note in CASES:
    got = normalize_phone(raw)
    ok = got == expected
    if not ok:
        fails.append((raw, got, expected, note))
    print(f"{raw!r:<20} {got:<15} {expected:<15} {'OK' if ok else 'FAIL':<5} {note}")

print("-" * 80)
if fails:
    print(f"{len(fails)} من {len(CASES)} فشل:")
    for raw, got, exp, note in fails:
        print(f"  {note}: input={raw!r} got={got!r} expected={exp!r}")
    sys.exit(1)
print(f"كل الحالات نجحت ({len(CASES)}/{len(CASES)})")
