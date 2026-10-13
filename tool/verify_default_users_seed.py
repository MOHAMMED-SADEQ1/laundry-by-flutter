"""تحقّق من زرع الحسابات الافتراضية في جدول `users`.

يثبت — باختبار فعلي على SQLite + إعادة تنفيذ نفس دالة التجزئة في Dart — أن:
  1. الحسابات الأربعة تُزرع عند أول إنشاء للقاعدة.
  2. كلمة مرور كل حساب **تُطابق** تجزئتها المخزَّنة (الدخول سينجح فعلًا).
  3. الزرع **خامل التكرار**: تشغيله مرتين لا يُنشئ صفوفًا مكرّرة.
  4. 🔒 الزرع **لا يُعيد** كلمة المرور الافتراضية على حساب غيّرها صاحبه.
  5. كل حساب له `salt` مستقل ⇒ تجزئتان مختلفتان ولو تساوت كلمات المرور.
  6. الأدوار الأربعة صحيحة، و`is_active = 1` لكل حساب.

التجزئة منسوخة حرفيًا من `lib/services/security/security_service.dart`:
    salt = base64(16 بايت عشوائي)
    hash = sha256(utf8(password + salt))
    المخزَّن = "<salt>:<hash>"
"""

import base64
import hashlib
import os
import sqlite3

results = []


def check(name, got, expected):
    ok = got == expected
    results.append(ok)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}\n        got={got!r} expected={expected!r}")


def generate_salt():
    return base64.b64encode(os.urandom(16)).decode()


def hash_password(password, salt=None):
    salt = salt or generate_salt()
    digest = hashlib.sha256((password + salt).encode("utf-8")).hexdigest()
    return f"{salt}:{digest}"


def verify_password(password, stored):
    parts = stored.split(":")
    if len(parts) != 2:
        return False
    return hash_password(password, salt=parts[0]) == stored


# ── نفس القيم في lib/config/constants.dart ──
DEFAULTS = [
    ("admin", "laundry123456", "admin", "مدير النظام"),
    ("manager", "manager123456", "manager", "مدير"),
    ("accountant", "accountant123456", "accountant", "محاسب"),
    ("user", "user123456", "cashier", "مستخدم"),
]

SCHEMA = """
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  full_name TEXT,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'cashier',
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);
"""


def seed(conn):
    """يحاكي `SqlDB._seedDefaultUsers` — INSERT OR IGNORE على username."""
    for username, password, role, full_name in DEFAULTS:
        conn.execute(
            "INSERT OR IGNORE INTO users "
            "(username, full_name, password_hash, role, is_active, created_at) "
            "VALUES (?,?,?,?,1,datetime('now'))",
            (username, full_name, hash_password(password), role),
        )
    conn.commit()


def main():
    c = sqlite3.connect(":memory:")
    c.executescript(SCHEMA)

    # ── 1: أول إنشاء ──
    seed(c)
    rows = c.execute("SELECT username, password_hash, role, is_active FROM users").fetchall()
    check("عدد الحسابات المزروعة", len(rows), 4)
    check("أسماء المستخدمين", sorted(r[0] for r in rows),
          ["accountant", "admin", "manager", "user"])

    # ── 6: الأدوار والتفعيل ──
    check("الأدوار", {r[0]: r[2] for r in rows},
          {"admin": "admin", "manager": "manager",
           "accountant": "accountant", "user": "cashier"})
    check("كل الحسابات مُفعَّلة", all(r[3] == 1 for r in rows), True)

    # ── 2: كلمات المرور تُطابق التجزئة (الدخول ينجح فعلًا) ──
    stored = {r[0]: r[1] for r in rows}
    for username, password, _, _ in DEFAULTS:
        check(f"كلمة مرور '{username}' تُطابق تجزئتها",
              verify_password(password, stored[username]), True)
    check("كلمة مرور خاطئة تُرفض", verify_password("wrong", stored["admin"]), False)

    # ── 5: salt مستقل لكل حساب ──
    salts = [stored[u].split(":")[0] for u, _, _, _ in DEFAULTS]
    check("كل حساب له salt مختلف", len(set(salts)), 4)

    # ── 3: خامل التكرار ──
    seed(c)
    seed(c)
    check("إعادة الزرع لا تُكرّر الصفوف",
          c.execute("SELECT COUNT(*) FROM users").fetchone()[0], 4)

    # ── 4: 🔒 لا يُعيد كلمة مرور حساب غيّرها صاحبه ──
    new_hash = hash_password("MyNewSecret!99")
    c.execute("UPDATE users SET password_hash = ? WHERE username = 'admin'", (new_hash,))
    c.commit()
    seed(c)
    after = c.execute(
        "SELECT password_hash FROM users WHERE username = 'admin'"
    ).fetchone()[0]
    check("زرع لاحق لا يمحو كلمة مرور مُغيَّرة (لا رجوع للافتراضية)",
          after, new_hash)
    check("كلمة المرور الجديدة ما زالت تعمل",
          verify_password("MyNewSecret!99", after), True)
    check("الكلمة الافتراضية لم تعد تعمل",
          verify_password("laundry123456", after), False)

    print(f"\n{sum(results)}/{len(results)} نجحت")
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
