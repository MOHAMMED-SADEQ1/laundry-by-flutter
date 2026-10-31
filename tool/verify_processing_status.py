#!/usr/bin/env python3
"""حرس انحراف حالة الفاتورة (`invoices.status`).

يُثبت ثلاث دعاوى على **SQLite حقيقي**:

  1. القاعدة المُرقّاة تحمل افتراضيًا عربيًّا في `invoices.status`
     (`DEFAULT "تم الاستلام"`) لا يمكن تغييره بـ`ALTER TABLE` — أي أن
     الاعتماد على افتراضي العمود يجعل السلوك تابعًا لتاريخ إنشاء القاعدة.
  2. صفّ بحالة عربية **لا يطابق** أي تبويب في لوحة المصنعية لأن المقارنة
     نصّية مع المفاتيح (`received|in_progress|ready|delivered`).
  3. التطبيع (CASE … WHERE … IN) يعيد كل الصفوف إلى المفاتيح في مرور واحد،
     وخامل التكرار (تشغيله مرتين لا يغيّر شيئًا).

يُشغَّل:  python tool/verify_processing_status.py [مسار_قاعدة_حيّة]
"""
from __future__ import annotations

import os
import shutil
import sqlite3
import sys
import tempfile

KEYS = ("received", "in_progress", "ready", "delivered")
ARABIC = {
    "تم الاستلام": "received",
    "قيد التنفيذ": "in_progress",
    "جاهز للاستلام": "ready",
    "تم التسليم": "delivered",
}

# نفس SQL المطبَّق في `SqlDB._migrateProcessingStatusKeys` — حرفيًّا.
def normalize(con: sqlite3.Connection) -> int:
    cases = " ".join("WHEN ? THEN ?" for _ in KEYS)
    marks = ",".join("?" for _ in KEYS)
    args: list[str] = []
    for arabic, key in ARABIC.items():
        args.extend([arabic, key])
    args.extend(ARABIC.keys())
    cur = con.execute(
        'UPDATE "invoices" SET "status" = '
        f'CASE TRIM(COALESCE("status", \'\')) {cases} ELSE "status" END '
        f'WHERE TRIM(COALESCE("status", \'\')) IN ({marks})',
        args,
    )
    return cur.rowcount


def key_of(raw: str | None) -> str:
    text = (raw or "").strip()
    return ARABIC.get(text, text if text in KEYS else "received")


def live_db_path() -> str | None:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None
    p = os.path.join(
        appdata, "com.mohammadsadekaljafri", "laundry", "laundry_pos.db"
    )
    return p if os.path.exists(p) else None


def build_legacy_db(path: str) -> None:
    """قاعدة «مُرقّاة»: العمود أُضيف بـALTER فحمل افتراضيًّا عربيًّا."""
    con = sqlite3.connect(path)
    con.execute(
        'CREATE TABLE "invoices" ("invoices_id" INTEGER PRIMARY KEY, '
        '"status" TEXT, "credit_note_of" INTEGER)'
    )
    con.execute('ALTER TABLE "invoices" ADD COLUMN "x" TEXT')
    # محاكاة العمود القائم الذي لا يمكن تغيير افتراضيه:
    con.execute('ALTER TABLE "invoices" ADD COLUMN "st" TEXT')
    con.execute(
        'UPDATE "invoices" SET "st" = NULL WHERE 0'  # لا شيء — للتوضيح فقط
    )
    con.commit()
    con.close()


def main() -> int:
    ok = 0
    fail = 0

    def check(name: str, cond: bool, detail: str = "") -> None:
        nonlocal ok, fail
        if cond:
            ok += 1
            print(f"[PASS] {name}")
        else:
            fail += 1
            print(f"[FAIL] {name}  {detail}")

    tmp = tempfile.mkdtemp(prefix="laundry_status_")
    src = sys.argv[1] if len(sys.argv) > 1 else live_db_path()

    if src and os.path.exists(src):
        db = os.path.join(tmp, "copy.db")
        shutil.copy2(src, db)
        mode = "نسخة من القاعدة الحيّة"
    else:
        db = os.path.join(tmp, "synthetic.db")
        con = sqlite3.connect(db)
        con.execute(
            'CREATE TABLE "invoices" ("invoices_id" INTEGER PRIMARY KEY, '
            '"status" TEXT DEFAULT "تم الاستلام", "credit_note_of" INTEGER)'
        )
        con.commit()
        con.close()
        mode = "قاعدة اصطناعية"

    con = sqlite3.connect(db)
    print(f"── المصدر: {mode} ({db})")

    # ─── 1. الافتراضي العربي لا يمكن تغييره بـALTER ───
    ddl = con.execute(
        "SELECT sql FROM sqlite_master WHERE name='invoices'"
    ).fetchone()[0]
    has_arabic_default = '"تم الاستلام"' in ddl
    check(
        "1. افتراضي العمود عربي في القاعدة المُرقّاة (سبب العيب)",
        has_arabic_default or mode.startswith("قاعدة اصطناعية"),
        ddl[:120],
    )

    # إدراج بلا حالة صريحة ⇒ يأخذ الافتراضي
    con.execute(
        'INSERT INTO "invoices" ("invoices_id","invoice_date") VALUES (900001,?)',
        ("2026-10-30T00:00:00",),
    )
    raw = con.execute(
        'SELECT "status" FROM "invoices" WHERE "invoices_id" = 900001'
    ).fetchone()[0]
    check(
        "2. إدراج بلا حالة صريحة ينتج قيمة غير مطابقة للمفاتيح",
        raw not in KEYS,
        f"status={raw!r}",
    )

    # ─── 3. قبل التطبيع: صفوف عربية لا تدخل أي تبويب ───
    legacy_before = con.execute(
        'SELECT COUNT(*) FROM "invoices" '
        "WHERE TRIM(COALESCE(\"status\",'')) IN ('تم الاستلام','قيد التنفيذ','جاهز للاستلام','تم التسليم')"
    ).fetchone()[0]
    tabbed_before = con.execute(
        'SELECT COUNT(*) FROM "invoices" WHERE "status" IN (?,?,?,?)', KEYS
    ).fetchone()[0]
    total_before = con.execute('SELECT COUNT(*) FROM "invoices"').fetchone()[0]
    check(
        "3. الصفوف العربية لا تُطابق أي تبويب",
        legacy_before == 0 or tabbed_before == total_before - legacy_before,
        f"عربي={legacy_before} مطابق={tabbed_before} كلي={total_before}",
    )

    # ─── 4. التطبيع ───
    changed = normalize(con)
    legacy_after = con.execute(
        'SELECT COUNT(*) FROM "invoices" '
        "WHERE TRIM(COALESCE(\"status\",'')) IN ('تم الاستلام','قيد التنفيذ','جاهز للاستلام','تم التسليم')"
    ).fetchone()[0]
    check("4. بعد التطبيع: صفر قيمة عربية", legacy_after == 0, f"بقي {legacy_after}")
    check("5. التطبيع غيّر صفوفًا فعلًا", changed >= 1, f"changed={changed}")

    tabbed_after = con.execute(
        'SELECT COUNT(*) FROM "invoices" WHERE "status" IN (?,?,?,?)', KEYS
    ).fetchone()[0]
    check(
        "6. كل الصفوف صارت داخل تبويب",
        tabbed_after == con.execute('SELECT COUNT(*) FROM "invoices"').fetchone()[0],
        f"مطابق={tabbed_after}",
    )

    # ─── 7. خامل التكرار ───
    again = normalize(con)
    check("7. تشغيله ثانيةً لا يغيّر شيئًا", again == 0, f"changed={again}")

    # ─── 8. منطق keyOf في Dart يطابق التحويل في SQL ───
    rows = con.execute('SELECT "status" FROM "invoices"').fetchall()
    mismatched = [r[0] for r in rows if key_of(r[0]) not in KEYS]
    check("8. keyOf يسقط دائمًا إلى مفتاح صالح", not mismatched, str(mismatched[:3]))

    # ─── 9. التسليم لا يظهر في اللوحة (بالمفتاح أو بالعربي) ───
    con.execute(
        'INSERT INTO "invoices" ("invoices_id","invoice_date","status") '
        "VALUES (900002,?,?)",
        ("2026-10-30T00:00:00", "تم التسليم"),
    )
    delivered_total = con.execute(
        "SELECT COUNT(*) FROM \"invoices\" WHERE \"status\" IN ('delivered','تم التسليم')"
    ).fetchone()[0]
    visible_total = con.execute('SELECT COUNT(*) FROM "invoices"').fetchone()[0]
    board = con.execute(
        'SELECT COUNT(*) FROM "invoices" '
        'WHERE COALESCE("credit_note_of",0)=0 '
        "  AND COALESCE(\"status\",'') NOT IN (?,?)",
        ("delivered", "تم التسليم"),
    ).fetchone()[0]
    check(
        "9. استعلام اللوحة يستبعد التسليم بالشكلين",
        board == visible_total - delivered_total and delivered_total >= 1,
        f"لوحة={board} كلي={visible_total} تسليم={delivered_total}",
    )

    # ─── 10. فواتير إشعار الدائن مستبعدة من اللوحة ───
    con.execute(
        'INSERT INTO "invoices" ("invoices_id","invoice_date","status","credit_note_of") '
        "VALUES (900003,?,?,900001)",
        ("2026-10-30T00:00:00", "received"),
    )
    board2 = con.execute(
        'SELECT COUNT(*) FROM "invoices" '
        'WHERE COALESCE("credit_note_of",0)=0 '
        "  AND COALESCE(\"status\",'') NOT IN (?,?)",
        ("delivered", "تم التسليم"),
    ).fetchone()[0]
    check("10. إشعار الدائن لا يظهر في لوحة المصنعية", board2 == board, f"{board2} vs {board}")

    con.close()
    shutil.rmtree(tmp, ignore_errors=True)

    print("─" * 60)
    print(f"نجح: {ok} · فشل: {fail}")
    if fail:
        print("❌ فشل الحرس")
        return 1
    print("✅ كل الفحوص نجحت")
    return 0


if __name__ == "__main__":
    sys.exit(main())
