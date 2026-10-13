"""تحقّق من منطق ربط الحركات بالوردية (الترحيل التصحيحي).

يثبت — باختبار فعلي على SQLite — أن:
  1. حركة داخل وردية مغلقة  → تُربط بها
  2. حركة **بعد** إقفالها     → لا تُربط (وهو الخلل الذي أصلحناه)
  3. حركة داخل وردية مفتوحة  → تُربط بها
  4. حركة خارج أي وردية       → تبقى NULL (غير منسوبة)
"""

import sqlite3
import sys

results = []


def check(name, got, expected):
    ok = got == expected
    results.append((ok, name, got, expected))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}\n        got={got!r} expected={expected!r}")


SCHEMA = """
CREATE TABLE shifts (
  shift_id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time TEXT NOT NULL,
  end_time TEXT,
  total_cash REAL DEFAULT 0
);
CREATE TABLE expenses (
  expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL, date TEXT, shift_id INTEGER
);
CREATE TABLE customer_payments (
  payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL, payment_date TEXT, shift_id INTEGER
);
CREATE TABLE subscription_payments (
  payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL, paid_date TEXT, shift_id INTEGER
);
"""

# نفس استعلام المطابقة في sqldb.dart (نافذة محدودة الطرفين)
MATCH_SQL = """
SELECT shift_id FROM shifts
WHERE datetime(start_time) <= datetime(?)
  AND (end_time IS NULL OR datetime(end_time) >= datetime(?))
ORDER BY shift_id ASC LIMIT 1
"""


def backfill(conn, table, col):
    rows = conn.execute(
        f'SELECT DISTINCT "{col}" AS ts FROM "{table}" '
        f'WHERE shift_id IS NULL AND "{col}" IS NOT NULL'
    ).fetchall()
    linked = 0
    for (ts,) in rows:
        if not ts:
            continue
        match = conn.execute(MATCH_SQL, (ts, ts)).fetchall()
        if not match:
            continue
        conn.execute(
            f'UPDATE "{table}" SET shift_id = ? WHERE "{col}" = ? AND shift_id IS NULL',
            (match[0][0], ts),
        )
        linked += 1
    conn.commit()
    return linked


conn = sqlite3.connect(":memory:")
conn.executescript(SCHEMA)

# وردية 1: 09:00 → 17:00 (مغلقة)
conn.execute("INSERT INTO shifts VALUES (1,'2026-09-01 09:00:00','2026-09-01 17:00:00',0)")
# وردية 2: 21:00 → 01:00 من الغد (تعبر منتصف الليل، مغلقة)
conn.execute("INSERT INTO shifts VALUES (2,'2026-09-01 21:00:00','2026-09-02 01:00:00',0)")
# وردية 3: مفتوحة الآن
conn.execute("INSERT INTO shifts VALUES (3,'2026-09-03 08:00:00',NULL,0)")

conn.executemany(
    "INSERT INTO expenses (amount, date) VALUES (?,?)",
    [
        (10, "2026-09-01 12:00:00"),  # داخل وردية 1
        (20, "2026-09-01 18:30:00"),  # بين ورديتين → لا وردية
        (30, "2026-09-01 23:30:00"),  # داخل وردية 2 (تعبر منتصف الليل)
        (40, "2026-09-02 00:30:00"),  # بعد منتصف الليل — ما زالت وردية 2
        (50, "2026-09-02 02:00:00"),  # **بعد إقفال وردية 2** → لا تُربط
        (60, "2026-09-03 10:00:00"),  # داخل الوردية المفتوحة
    ],
)
conn.commit()

linked = backfill(conn, "expenses", "date")
rows = conn.execute("SELECT expense_id, shift_id FROM expenses ORDER BY expense_id").fetchall()
got = [r[1] for r in rows]

check("E1. الربط: داخل وردية 1", got[0], 1)
check("E2. بين ورديتين → غير منسوب", got[1], None)
check("E3. داخل وردية تعبر منتصف الليل", got[2], 2)
check("E4. بعد منتصف الليل — ما زالت نفس الوردية", got[3], 2)
check("E5. **بعد إقفال الوردية → لا تُربط** (الخلل المُصلَح)", got[4], None)
check("E6. داخل الوردية المفتوحة", got[5], 3)

# idempotency: تشغيل ثانٍ لا يغيّر شيئًا
linked2 = backfill(conn, "expenses", "date")
got2 = [r[1] for r in conn.execute("SELECT expense_id, shift_id FROM expenses ORDER BY expense_id").fetchall()]
check("E7. إعادة التشغيل لا تغيّر الروابط (idempotent)", got2, got)
check("E8. إعادة التشغيل تربط صفرًا", linked2, 0)

print()
print("=" * 62)
failed = [r for r in results if not r[0]]
if failed:
    print(f"{len(failed)} من {len(results)} فشل")
    sys.exit(1)
print(f"كل الفحوصات نجحت ({len(results)}/{len(results)})")
