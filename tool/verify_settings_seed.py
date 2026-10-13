"""تحقّق حقيقي (SQLite فعلي) لسلوك **زرع خيارات النظام**.

يُشغَّل بـ:
    python tool/verify_settings_seed.py

يغطي نفس منطق `lib/sqldb.dart`:
  * `_insertDefaultSettings` ⇒ INSERT OR IGNORE (لا يدهس قيمة قائمة)
  * `_ensureDefaultSettings` ⇒ يكتب الافتراضي **فقط عند غياب المفتاح**

القيم الافتراضية مطابقة لسجل `lib/services/settings/setting_option.dart`
(وهو نفسه مُتحقَّق منه مقابل ثوابت الكود في `tool/verify_setting_options.dart`).
"""

import sqlite3
import sys

PASS, FAIL = "PASS", "FAIL"
results = []


def check(name, got, expected):
    ok = got == expected
    results.append((ok, name, got, expected))
    print(f"[{PASS if ok else 'FAIL'}] {name}\n        got={got!r}  expected={expected!r}\n")


SCHEMA = """
CREATE TABLE settings (
  key   TEXT NOT NULL PRIMARY KEY,
  value TEXT,
  description TEXT
);
"""

# نفس مفاتيح/افتراضيات السجل (setting_option.dart)
DEFAULTS = [
    ("invoice_start", "1001"),
    ("page_size", "12"),
    ("currency", "ر.س"),
    ("invoice_auto_delete_enabled", "0"),
    ("invoice_retention_days", "400"),
    ("loyalty_enabled", "1"),
    ("loyalty_rate", "10"),
    ("tax_enabled", "0"),
    ("tax_rate", "0.15"),
    ("license_warn_days", "7"),
    ("license_check_hours", "1"),
]


def build_db():
    conn = sqlite3.connect(":memory:")
    conn.executescript(SCHEMA)
    return conn


def insert_default_settings(conn):
    """`_insertDefaultSettings`: INSERT OR IGNORE."""
    for key, value in DEFAULTS:
        conn.execute(
            "INSERT OR IGNORE INTO settings (key, value, description)"
            " VALUES (?, ?, '')",
            (key, value),
        )
    conn.commit()


def ensure_default_settings(conn):
    """`_ensureDefaultSettings`: الافتراضي فقط عند غياب المفتاح."""
    for key, value in DEFAULTS:
        row = conn.execute(
            "SELECT value FROM settings WHERE key = ?", (key,)
        ).fetchone()
        if row is None:
            conn.execute(
                "INSERT INTO settings (key, value) VALUES (?, ?)", (key, value)
            )
    conn.commit()


print("=" * 70)
print("A. قاعدة جديدة: كل المفاتيح تُزرع بقيمها الافتراضية")
print("=" * 70)
conn = build_db()
insert_default_settings(conn)

count = conn.execute("SELECT COUNT(*) FROM settings").fetchone()[0]
check("A1. عدد المفاتيح المزروعة = 11", count, len(DEFAULTS))

check(
    "A2. الحذف التلقائي معطَّل في قاعدة جديدة",
    conn.execute(
        "SELECT value FROM settings WHERE key = 'invoice_auto_delete_enabled'"
    ).fetchone()[0],
    "0",
)
check(
    "A3. مدة الاحتفاظ الافتراضية 400 يومًا",
    conn.execute(
        "SELECT value FROM settings WHERE key = 'invoice_retention_days'"
    ).fetchone()[0],
    "400",
)
check(
    "A4. الولاء مفعَّل افتراضيًا",
    conn.execute(
        "SELECT value FROM settings WHERE key = 'loyalty_enabled'"
    ).fetchone()[0],
    "1",
)
check(
    "A5. كل المفاتيح موجودة بلا تكرار",
    conn.execute(
        "SELECT COUNT(DISTINCT key) FROM settings"
    ).fetchone()[0],
    len(DEFAULTS),
)

# إعادة الزرع آمنة (idempotent) ولا تُنشئ استثناءً ولا صفوفًا مكرّرة
insert_default_settings(conn)
check(
    "A6. تكرار الزرع لا يضاعف المفاتيح",
    conn.execute("SELECT COUNT(*) FROM settings").fetchone()[0],
    len(DEFAULTS),
)

print("=" * 70)
print("B. قاعدة قائمة: قيم المستخدم لا تُدهس")
print("=" * 70)
conn2 = build_db()
conn2.execute(
    "INSERT INTO settings (key, value) VALUES ('invoice_auto_delete_enabled', '1')"
)
conn2.execute(
    "INSERT INTO settings (key, value) VALUES ('invoice_retention_days', '900')"
)
conn2.execute("INSERT INTO settings (key, value) VALUES ('loyalty_rate', '25')")
conn2.commit()

insert_default_settings(conn2)
ensure_default_settings(conn2)

check(
    "B1. تفعيل الحذف الذي اختاره المستخدم باقٍ",
    conn2.execute(
        "SELECT value FROM settings WHERE key = 'invoice_auto_delete_enabled'"
    ).fetchone()[0],
    "1",
)
check(
    "B2. مدة الاحتفاظ المعدَّلة (900) باقية",
    conn2.execute(
        "SELECT value FROM settings WHERE key = 'invoice_retention_days'"
    ).fetchone()[0],
    "900",
)
check(
    "B3. معدّل الولاء المعدَّل (25) باقٍ",
    conn2.execute(
        "SELECT value FROM settings WHERE key = 'loyalty_rate'"
    ).fetchone()[0],
    "25",
)
check(
    "B4. المفاتيح الناقصة أُكملت بالافتراضي",
    conn2.execute(
        "SELECT value FROM settings WHERE key = 'page_size'"
    ).fetchone()[0],
    "12",
)
check(
    "B5. لا مفاتيح مكرّرة",
    conn2.execute("SELECT COUNT(DISTINCT key) FROM settings").fetchone()[0],
    conn2.execute("SELECT COUNT(*) FROM settings").fetchone()[0],
)

print("=" * 70)
failed = [r for r in results if not r[0]]
if failed:
    print(f"{len(failed)} من {len(results)} فحصًا فشل")
    for _, name, got, exp in failed:
        print(f"  - {name}: got={got!r} expected={exp!r}")
    sys.exit(1)
print(f"كل الفحوصات نجحت ({len(results)}/{len(results)})")
sys.exit(0)
