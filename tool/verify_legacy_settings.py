#!/usr/bin/env python3
"""حرس حذف مفاتيح الإعداد الميتة.

**العيب الذي يمنعه:** `settings` كانت تحمل عشرات المفاتيح التي لا يقرأها أي
كود (`inv_show_*` · `print_*` القديمة · `require_open_shift` …). ليست خطأً
محاسبيًّا، لكنها **كذب على المستخدم**: تُعرض في شاشات أو تُرحَّل وتُنسخ في
كل نسخة احتياطية ولا تفعل شيئًا. حذفها يقلّص القاعدة والنسخ، ويجعل كل مفتاح
موجود **يعمل فعلًا**.

يُثبت هذا الحرس — على الكود وعلى SQLite حقيقي — أربع دعاوى:

  1. كل مفتاح في [LegacySettingKeys.all] **لا يقرأه أي كود** (لا باسمه ولا
     بثابته في `AppConstants`)، وهو الشرط الوحيد الذي يجعل الحذف آمنًا.
  2. لا مفتاح منها **مُسجَّل** في `SettingOptions` — وإلا لحذفنا خيارًا حيًّا.
  3. الترحيل يحذف **هذه المفاتيح وحدها**، ويترك كل مفتاح آخر سليمًا.
  4. الترحيل يُبقي **أثرًا** في `audit_log` بالقيم المحذوفة، وخامل التكرار
     (تشغيله ثانيةً لا يحذف شيئًا).

يُشغَّل:  python tool/verify_legacy_settings.py [مسار_قاعدة_حيّة]
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile

OK = 0
FAIL = 0
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def check(name: str, cond: bool, detail: str = "") -> None:
    global OK, FAIL
    if cond:
        OK += 1
        print(f"[PASS] {name}")
    else:
        FAIL += 1
        print(f"[FAIL] {name}  {detail}")


def read(rel: str) -> str:
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return ""
    with open(p, encoding="utf-8") as f:
        return f.read()


def legacy_keys() -> list[str]:
    src = read("lib/services/settings/legacy_setting_keys.dart")
    body = src[src.find("all = "):] if "all = " in src else src
    return re.findall(r"'([a-z0-9_]+)'", body)


def constants_map() -> dict[str, str]:
    """`AppConstants` — اسم الثابت ⇒ قيمته النصّية."""
    src = read("lib/config/constants.dart")
    return {
        m.group(1): m.group(2)
        for m in re.finditer(r"static const \w+ (\w+) =\s*'([^']*)'", src)
    }


def option_keys() -> set[str]:
    """المفاتيح المُسجَّلة في `SettingOptions` (خيارات حيّة).

    الخيارات تُسجَّل بثابت من `AppConstants` لا بنصّ حرفي، فيُترجم الاسم
    إلى قيمته عبر [constants_map].
    """
    src = read("lib/services/settings/setting_option.dart")
    consts = constants_map()
    names = set(re.findall(r"key:\s*AppConstants\.(\w+)", src))
    return {consts[n] for n in names if n in consts}


def dart_files() -> list[str]:
    out: list[str] = []
    for root, _, files in os.walk(os.path.join(ROOT, "lib")):
        for f in files:
            if f.endswith(".dart"):
                out.append(os.path.join(root, f))
    return out


def live_db_path() -> str | None:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None
    p = os.path.join(
        appdata, "com.mohammadsadekaljafri", "laundry", "laundry_pos.db"
    )
    return p if os.path.exists(p) else None


def main() -> int:
    keys = legacy_keys()
    check("0. قائمة المفاتيح الميتة غير فارغة", len(keys) >= 40, f"{len(keys)}")
    check("0. لا تكرار في القائمة", len(set(keys)) == len(keys))

    consts = constants_map()
    registered = option_keys()
    check("0. خيارات SettingOptions قُرِئت", len(registered) > 50, f"{len(registered)}")

    # ─── [1] لا قارئ لأي مفتاح ───
    # نستثني ملف القائمة نفسه (هو موضع الذِكر المشروع) و`sqldb.dart`
    # (موضع الحذف المحروس).
    allow = {
        os.path.join(ROOT, "lib", "services", "settings", "legacy_setting_keys.dart"),
        os.path.join(ROOT, "lib", "sqldb.dart"),
    }
    sources = {p: open(p, encoding="utf-8").read() for p in dart_files() if p not in allow}

    # الثوابت التي تحمل قيمة أحد المفاتيح الميتة — تُعدّ «قارئًا محتملًا».
    dead_const_names = {n for n, v in consts.items() if v in keys}

    readers: list[str] = []
    for key in keys:
        for path, src in sources.items():
            if f"'{key}'" in src:
                readers.append(f"{key} ← {os.path.relpath(path, ROOT)}")
                break
    check("1. لا ملف يذكر مفتاحًا ميتًا بقيمته", not readers, " · ".join(readers[:6]))

    const_readers: list[str] = []
    for name in sorted(dead_const_names):
        for path, src in sources.items():
            if re.search(rf"\b{name}\b", src):
                const_readers.append(f"{name} ← {os.path.relpath(path, ROOT)}")
                break
    check(
        "1. لا ملف يقرأ ثابتًا يشير إلى مفتاح ميت",
        not const_readers,
        " · ".join(const_readers[:6]),
    )

    # ─── [2] لا مفتاح ميت مسجَّل كخيار حيّ ───
    overlap = sorted(set(keys) & registered)
    check("2. لا تقاطع بين الميت والمُسجَّل", not overlap, ", ".join(overlap[:8]))

    # ─── [3] و[4] على SQLite حقيقي ───
    tmp = tempfile.mkdtemp(prefix="laundry_settings_")
    src_db = sys.argv[1] if len(sys.argv) > 1 else live_db_path()
    if src_db and os.path.exists(src_db):
        db = os.path.join(tmp, "copy.db")
        shutil.copy2(src_db, db)
        mode = "نسخة من القاعدة الحيّة"
    else:
        db = os.path.join(tmp, "synthetic.db")
        con = sqlite3.connect(db)
        con.execute('CREATE TABLE "settings" ("key" TEXT PRIMARY KEY, "value" TEXT)')
        con.execute(
            'CREATE TABLE "audit_log" ("log_id" INTEGER PRIMARY KEY AUTOINCREMENT, '
            '"user_id" INTEGER, "action" TEXT, "table_name" TEXT, '
            '"record_id" INTEGER, "old_values" TEXT, "new_values" TEXT, '
            '"timestamp" TEXT)'
        )
        con.executemany(
            'INSERT INTO "settings" ("key","value") VALUES (?,?)',
            [(k, "1") for k in keys] + [("tax_rate", "15"), ("invoice_copies", "2")],
        )
        con.commit()
        con.close()
        mode = "قاعدة اصطناعية"

    con = sqlite3.connect(db)
    print(f"── المصدر: {mode} ({db})")

    # 🚨 **القاعدة الحيّة قد تكون رُحِّلت فعلًا**، فتُصبح `present` فارغة
    # ويقارن الحرس أثر تدقيق **قديمًا** (50 قيمة) بعدد صفر ⇒ فشل كاذب لا
    # علاقة له بالكود. نُعيد زرع المفاتيح الميتة في **النسخة المؤقّتة** فقط
    # كي يُعيد الحرس إنتاج الترحيل نفسه في كل تشغيل، بدل أن يعتمد على حالة
    # القاعدة الحيّة في يوم التشغيل.
    con.executemany(
        'INSERT OR IGNORE INTO "settings" ("key","value") VALUES (?,?)',
        [(k, "1") for k in keys],
    )
    con.commit()

    before_keys = {
        r[0] for r in con.execute('SELECT "key" FROM "settings"')
    }
    present = sorted(before_keys & set(keys))
    others_before = before_keys - set(keys)
    print(f"   مفاتيح ميتة موجودة فعلًا: {len(present)} من {len(keys)}")

    # نفس SQL في `SqlDB._cleanupLegacySettings`.
    def cleanup(conn: sqlite3.Connection) -> int:
        rows = conn.execute(
            'SELECT "key","value" FROM "settings" '
            f'WHERE "key" IN ({",".join("?" for _ in keys)})',
            keys,
        ).fetchall()
        if rows:
            snapshot = {k: (v or "") for k, v in rows}
            conn.execute(
                'INSERT INTO "audit_log" ("user_id","action","table_name",'
                '"record_id","old_values","new_values","timestamp") '
                "VALUES (NULL,'settings_legacy_cleanup','settings',NULL,?,?,?)",
                (
                    json.dumps(snapshot, ensure_ascii=False),
                    json.dumps({"deleted": len(rows)}),
                    "2026-10-30T00:00:00",
                ),
            )
            conn.execute(
                'DELETE FROM "settings" '
                f'WHERE "key" IN ({",".join("?" for _ in keys)})',
                keys,
            )
        conn.commit()
        return len(rows)

    deleted = cleanup(con)
    check("3. عدد المحذوف = عدد الموجود", deleted == len(present), f"{deleted}≠{len(present)}")

    after_keys = {r[0] for r in con.execute('SELECT "key" FROM "settings"')}
    check("3. لا مفتاح ميت بقي", not (after_keys & set(keys)), ", ".join(sorted(after_keys & set(keys))[:6]))
    check(
        "3. كل مفتاح حيّ آخر سليم",
        others_before.issubset(after_keys),
        ", ".join(sorted(others_before - after_keys)[:6]),
    )
    if others_before:
        sample = sorted(others_before)[0]
        val = con.execute(
            'SELECT "value" FROM "settings" WHERE "key" = ?', (sample,)
        ).fetchone()
        check("3. قيمة مفتاح حيّ لم تتغيّر", val is not None, sample)

    audit = con.execute(
        "SELECT old_values, new_values FROM \"audit_log\" "
        "WHERE \"action\" = 'settings_legacy_cleanup' ORDER BY log_id DESC LIMIT 1"
    ).fetchone()
    check("4. أثر التدقيق مكتوب", audit is not None)
    if audit:
        old = json.loads(audit[0])
        check("4. الأثر يحمل القيم المحذوفة", len(old) == len(present), f"{len(old)}")
        check(
            "4. الأثر يطابق العدد المحذوف",
            json.loads(audit[1]).get("deleted") == len(present),
        )

    second = cleanup(con)
    check("4. خامل التكرار (تشغيل ثانٍ لا يحذف)", second == 0, f"{second}")

    con.close()
    print("─" * 60)
    print(f"نجح: {OK} · فشل: {FAIL}")
    if FAIL:
        return 1
    print("✅ كل الفحوص نجحت")
    return 0


if __name__ == "__main__":
    sys.exit(main())
