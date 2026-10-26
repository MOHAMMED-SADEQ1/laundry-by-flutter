#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات طبقة قاعدة جداول الصلاحيات (`roles` · `role_permissions` ·
`permission_overrides`) على SQLite حقيقي.

`tool/verify_permission_catalog.dart` يُثبت **الكتالوج الخالص** فقط (بلا
قاعدة). هذا الملف يُثبت ما لا يراه: أن **نص SQL في `sqldb.dart` يُنشئ فعلًا
المخطط الصحيح**، وأن الزرع **غير مُتلِف** (لا يدهس تعديلًا)، وأن المفاتيح
المزروعة **كلها معروفة في الكتالوج** (لا مفتاح شبح لا نقطة إنفاذ له).

يُثبت ستة أمور:
  1. مخطط الجداول الثلاثة موجود في المواضع الثلاثة ومتطابق.
  2. قاعدة قديمة بلا الجداول: الترحيل يُنشئها بالبنية الصحيحة.
  3. الزرع غير مُتلِف: إعادة تشغيله لا تُنشئ دورًا ثانيًا ولا تدهس صلاحيات
     دور عدّلها المدير.
  4. `admin` يملك كل مفاتيح الكتالوج بعد الزرع (سلطة عليا دائمة).
  5. المفتاح المركّب يمنع التكرار بُنيويًا (`role_permissions` ·
     `permission_overrides`).
  6. تضارب التجاوز يقرّره آخر صف (`permission_overrides`) لا تراكمه.
"""
import os
import re
import sqlite3
import sys

PASS = 0
FAIL = 0

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
SQLDB = os.path.join(ROOT, 'lib', 'sqldb.dart')
CATALOG = os.path.join(ROOT, 'lib', 'services', 'permission',
                       'permission_catalog.dart')


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
        print(f"  PASS  {label}{(': ' + detail) if detail else ''}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}{(': ' + detail) if detail else ''}")


# ═══════════ استخراج الكتالوج من permission_catalog.dart ═══════════

def catalog_keys():
    """كل مفاتيح الصلاحيات (`key: 'group.action'`) من الكتالوج الخالص."""
    with open(CATALOG, encoding='utf-8') as fh:
        src = fh.read()
    return re.findall(r"key:\s*'([a-z][a-z0-9_]*\.[a-z][a-z0-9_]*)'", src)


def catalog_bundle(name):
    """حزمة دور من الكتالوج — قائمة مفاتيح `'...'` داخل القوسين."""
    with open(CATALOG, encoding='utf-8') as fh:
        src = fh.read()
    # adminBundle مُشتق: كل المفاتيح — نُعيدها مباشرةً.
    if name == 'admin':
        return catalog_keys()
    pattern = re.compile(
        rf"static\s+const\s+List<String>\s+{name}\s*=\s*<String>\[(.*?)\]",
        re.DOTALL,
    )
    m = pattern.search(src)
    if not m:
        return None
    return re.findall(r"'([a-z][a-z0-9_]*\.[a-z][a-z0-9_]*)'", m.group(1))


def catalog_roles():
    """(name, label, isSystem) من `seedRoles`."""
    with open(CATALOG, encoding='utf-8') as fh:
        src = fh.read()
    m = re.search(
        r"seedRoles\s*=\s*<(.*?)>\s*\[(.*?)\];", src, re.DOTALL)
    if not m:
        return None
    body = m.group(2)
    out = []
    for rec in re.finditer(
            r"name:\s*'(\w+)',\s*label:\s*'([^']+)',\s*isSystem:\s*(true|false)",
            body):
        out.append((rec.group(1), rec.group(2), rec.group(3) == 'true'))
    return out


def catalog_role_labels():
    """خريطة name ⇒ label من `roleLabelOf` (للتحقق من تطابق الزرع)."""
    with open(CATALOG, encoding='utf-8') as fh:
        src = fh.read()
    # seedRoles هو المصدر — لا نستخرج من switch (فيه تكرار).
    roles = catalog_roles() or []
    return {n: l for n, l, _ in roles}


# ═══════════ استخراج DDL من sqldb.dart ═══════════

def extract_ddl(table):
    r"""كتل `CREATE TABLE ... "table" (...)` — توقف عند أول `)` مُغلق.

    نمط الأقواس المزدوجة يُطابَق حتى السطر الذي يحمل القوس المُغلق وحده،
    فلا يبتلع كتلًا لاحقة.
    """
    with open(SQLDB, encoding='utf-8') as fh:
        src = fh.read()
    pattern = re.compile(
        rf'CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+"{table}"\s*\((.*?)\n\s*\)\s*\)?',
        re.DOTALL,
    )
    return [re.sub(r'\s+', ' ', m).strip() for m in pattern.findall(src)]


def columns_of(ddl):
    return re.findall(r'"(\w+)"', ddl)


print("=" * 64)
print("  إثبات طبقة قاعدة الصلاحيات — SQLite حقيقي")
print("=" * 64)

# ═══════════ 1) المخطط: تعريف واحد + ثلاثة مواضع نداء ═══════════

print("\n[1] المخطط: تعريف واحد لا ينحرف + نداء من 3 مواضع")

ROLES_COLS = ['role_id', 'name', 'label', 'is_system', 'created_at']
RP_COLS = ['role_id', 'permission_key']
PO_COLS = ['user_id', 'permission_key', 'allow']

with open(SQLDB, encoding='utf-8') as _fh:
    sqldb_src = _fh.read()

# التعريف **مُستخرج في دالة واحدة** (`_createPermissionTables`) تُنادى من
# المواضع الثلاثة — هذا أفضل من ثلاث نسخ: يستحيل أن تنحرف نسخة عن نسخة.
call_sites = sqldb_src.count('await _createPermissionTables(')
check("[1] _createPermissionTables مُناداة من 3 مواضع", call_sites, 3)

ok("[1] التعريف مُستخرج في دالة واحدة (لا نسخ تنحرف)",
   sqldb_src.count('Future<void> _createPermissionTables(') == 1)

# الزرع كذلك
check("[1] _seedDefaultPermissions مُناداة من 3 مواضع",
      sqldb_src.count('await _seedDefaultPermissions('), 3)
ok("[1] الزرع مُستخرج في دالة واحدة",
   sqldb_src.count('Future<void> _seedDefaultPermissions(') == 1)

for table, expected in (
        ('roles', ROLES_COLS),
        ('role_permissions', RP_COLS),
        ('permission_overrides', PO_COLS),
):
    ddls = extract_ddl(table)
    ok(f"[1] {table}: معرَّف مرة واحدة", len(ddls) == 1, f'وجدنا {len(ddls)}')
    if ddls:
        check(f"[1] {table}: أسماء الأعمدة بالترتيب",
              columns_of(ddls[0])[:len(expected)], expected)

# المفتاح المركّب مذكور صراحةً
rp_ddl = extract_ddl('role_permissions')
ok("[1] role_permissions بمفتاح مركّب",
   any('PRIMARY KEY ("role_id", "permission_key")' in d for d in rp_ddl))
po_ddl = extract_ddl('permission_overrides')
ok("[1] permission_overrides بمفتاح مركّب",
   any('PRIMARY KEY ("user_id", "permission_key")' in d for d in po_ddl))

# الفهارس
ok("[1] فهرس role_permissions موجود",
   'idx_role_permissions_role' in sqldb_src)
ok("[1] فهرس permission_overrides موجود",
   'idx_permission_overrides_user' in sqldb_src)

# ═══════════ 2) قاعدة قديمة بلا الجداول ═══════════

print("\n[2] قاعدة قديمة بلا جداول الصلاحيات — الترحيل يُنشئها")

db = sqlite3.connect(':memory:')
db.row_factory = sqlite3.Row
db.execute('CREATE TABLE "users" ("user_id" INTEGER PRIMARY KEY, '
           '"username" TEXT UNIQUE, "role" TEXT)')
db.commit()

before = db.execute(
    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
    "AND name IN ('roles','role_permissions','permission_overrides')"
).fetchone()[0]
check("[2] قبل الترحيل: الجداول مفقودة", before, 0)

# نفس نص الترحيل من sqldb.dart
for table in ('roles', 'role_permissions', 'permission_overrides'):
    ddls = extract_ddl(table)
    if ddls:
        db.execute(f'CREATE TABLE IF NOT EXISTS "{table}" ({ddls[0]})')
db.commit()

after = db.execute(
    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
    "AND name IN ('roles','role_permissions','permission_overrides')"
).fetchone()[0]
check("[2] بعد الترحيل: الجداول الثلاثة موجودة", after, 3)

check("[2] أعمدة roles الفعلية",
      [r[1] for r in db.execute('PRAGMA table_info("roles")')], ROLES_COLS)
check("[2] أعمدة role_permissions الفعلية",
      [r[1] for r in db.execute('PRAGMA table_info("role_permissions")')],
      RP_COLS)
check("[2] أعمدة permission_overrides الفعلية",
      [r[1] for r in db.execute('PRAGMA table_info("permission_overrides")')],
      PO_COLS)

# إعادة تشغيل الترحيل لا تُنشئ نسخة ثانية
for table in ('roles', 'role_permissions', 'permission_overrides'):
    ddls = extract_ddl(table)
    if ddls:
        db.execute(f'CREATE TABLE IF NOT EXISTS "{table}" ({ddls[0]})')
db.commit()
check("[2] إعادة الترحيل idempotent",
      db.execute(
          "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
          "AND name IN ('roles','role_permissions','permission_overrides')"
      ).fetchone()[0], 3)

# ═══════════ 3) الزرع — مرآة `_seedDefaultPermissions` ═══════════

print("\n[3] الزرع: غير مُتلِف ولا يدهس تعديلًا")

keys = catalog_keys()
roles = catalog_roles()
role_labels = catalog_role_labels()
ok("[3] الكتالوج يقرأ مفاتيح", len(keys) > 0, f'{len(keys)} مفتاح')
ok("[3] الكتالوج يقرأ 5 أدوار", roles is not None and len(roles) == 5)
ok("[3] الأدوار كلها نظامية", all(sys_ for _, _, sys_ in roles))
check("[3] أسماء الأدوار", [n for n, _, _ in roles],
      ['admin', 'manager', 'accountant', 'cashier', 'worker'])

bundles = {
    'admin': catalog_bundle('admin'),
    'manager': catalog_bundle('managerBundle'),
    'accountant': catalog_bundle('accountantBundle'),
    'cashier': catalog_bundle('cashierBundle'),
    'worker': catalog_bundle('workerBundle'),
}
ghost = [(r, k) for r, b in bundles.items() if b for k in b if k not in keys]
ok("[3] لا مفتاح شبح في أي حزمة", not ghost, str(ghost))

NOW = '2026-10-15T00:00:00.000'
ALLOWED = set(keys)


def seed_permissions():
    """مرآة حرفية لمنطق `_seedDefaultPermissions`."""
    for name, label, is_system in roles:
        cur = db.execute(
            'INSERT OR IGNORE INTO "roles" (name, label, is_system, created_at) '
            'VALUES (?,?,?,?)', (name, label, 1 if is_system else 0, NOW))
        inserted = cur.rowcount > 0
        row = db.execute('SELECT role_id FROM "roles" WHERE name = ?',
                         (name,)).fetchone()
        if row is None:
            continue
        role_id = row['role_id']
        has_any = db.execute(
            'SELECT 1 FROM "role_permissions" WHERE role_id = ? LIMIT 1',
            (role_id,)).fetchone() is not None
        if inserted and not has_any:
            for k in (bundles.get(name) or []):
                if k in ALLOWED:
                    db.execute(
                        'INSERT OR IGNORE INTO "role_permissions" '
                        '(role_id, permission_key) VALUES (?,?)', (role_id, k))
    db.commit()


seed_permissions()

check("[3] عدد الأدوار بعد الزرع", db.execute(
    'SELECT COUNT(*) FROM "roles"').fetchone()[0], 5)
check("[3] عدد إسنادات admin", db.execute(
    'SELECT COUNT(*) FROM "role_permissions" rp JOIN "roles" r '
    'ON r.role_id = rp.role_id WHERE r.name = "admin"').fetchone()[0],
    len(keys))

# idempotent: إعادة الزرع لا تُنشئ نسخة ثانية
seed_permissions()
check("[3] إعادة الزرع: لا دور ثانٍ", db.execute(
    'SELECT COUNT(*) FROM "roles"').fetchone()[0], 5)
check("[3] إعادة الزرع: لا إسناد مكرَّر", db.execute(
    'SELECT COUNT(*) FROM (SELECT role_id, permission_key '
    'FROM "role_permissions" GROUP BY role_id, permission_key '
    'HAVING COUNT(*) > 1)').fetchone()[0], 0)

# تعديل صلاحيات دور ثم إعادة الزرع — لا تُدهس
manager_id = db.execute(
    'SELECT role_id FROM "roles" WHERE name = "manager"').fetchone()['role_id']
db.execute('DELETE FROM "role_permissions" WHERE role_id = ? '
           'AND permission_key = "invoice.delete"', (manager_id,))
db.commit()
before_cnt = db.execute('SELECT COUNT(*) FROM "role_permissions" '
                        'WHERE role_id = ?', (manager_id,)).fetchone()[0]
seed_permissions()
after_cnt = db.execute('SELECT COUNT(*) FROM "role_permissions" '
                       'WHERE role_id = ?', (manager_id,)).fetchone()[0]
check("[3] الزرع لا يدهس إسنادًا عُدِّل", after_cnt, before_cnt)
ok("[3] الصلاحية المحذوفة لم تعد",
   db.execute('SELECT 1 FROM "role_permissions" WHERE role_id = ? '
              'AND permission_key = "invoice.delete"',
              (manager_id,)).fetchone() is None)

# ═══════════ 4) admin يملك كل المفاتيح ═══════════

print("\n[4] admin = سلطة عليا دائمة (كل مفاتيح الكتالوج)")

admin_id = db.execute(
    'SELECT role_id FROM "roles" WHERE name = "admin"').fetchone()['role_id']
admin_keys = {r['permission_key'] for r in db.execute(
    'SELECT permission_key FROM "role_permissions" WHERE role_id = ?',
    (admin_id,))}
missing = set(keys) - admin_keys
ok("[4] admin يملك كل المفاتيح", not missing, str(sorted(missing)))
ok("[4] admin لا يملك مفتاحًا شبحًا", admin_keys <= set(keys))

# ═══════════ 5) المفتاح المركّب يمنع التكرار بُنيويًا ═══════════

print("\n[5] المفتاح المركّب: منع التكرار بُنيويًا")

dup_rejected = False
try:
    db.execute('INSERT INTO "role_permissions" (role_id, permission_key) '
               'VALUES (?, "invoice.create")', (admin_id,))
    db.commit()
except sqlite3.IntegrityError:
    db.rollback()
    dup_rejected = True
ok("[5] إسناد مكرَّر مرفوض بُنيويًا", dup_rejected)

db.execute('INSERT OR IGNORE INTO "permission_overrides" '
           '(user_id, permission_key, allow) VALUES (1, "invoice.delete", 1)')
db.commit()
dup_override = False
try:
    db.execute('INSERT INTO "permission_overrides" '
               '(user_id, permission_key, allow) VALUES (1, "invoice.delete", 0)')
    db.commit()
except sqlite3.IntegrityError:
    db.rollback()
    dup_override = True
ok("[5] تجاوز مكرَّر مرفوض بُنيويًا", dup_override)

# ═══════════ 6) قرار التجاوز: آخر كتابة تفوز (upsert) ═══════════

print("\n[6] التجاوز الفردي: upsert لا تراكم")

db.execute(
    'INSERT INTO "permission_overrides" (user_id, permission_key, allow) '
    'VALUES (2, "invoice.discount_apply", 1) '
    'ON CONFLICT(user_id, permission_key) DO UPDATE SET allow = excluded.allow')
db.execute(
    'INSERT INTO "permission_overrides" (user_id, permission_key, allow) '
    'VALUES (2, "invoice.discount_apply", 0) '
    'ON CONFLICT(user_id, permission_key) DO UPDATE SET allow = excluded.allow')
db.commit()
check("[6] صف واحد فقط للمستخدم/المفتاح", db.execute(
    'SELECT COUNT(*) FROM "permission_overrides" WHERE user_id = 2 '
    'AND permission_key = "invoice.discount_apply"').fetchone()[0], 1)
check("[6] آخر كتابة فازت (allow=0)", db.execute(
    'SELECT allow FROM "permission_overrides" WHERE user_id = 2 '
    'AND permission_key = "invoice.discount_apply"').fetchone()[0], 0)

# قرار فعلي: تجاوز يمنح فوق دور لا يملك
print("\n[7] القرار الفعلي: الهرم + التجاوز")

cashier_id = db.execute(
    'SELECT role_id FROM "roles" WHERE name = "cashier"').fetchone()['role_id']
cashier_keys = {r['permission_key'] for r in db.execute(
    'SELECT permission_key FROM "role_permissions" WHERE role_id = ?',
    (cashier_id,))}
ok("[7] الكاشير لا يملك حذف فاتورة أصلًا",
   'invoice.delete' not in cashier_keys)

# تجاوز يمنح الكاشير (user 3) هذه الصلاحية
db.execute(
    'INSERT INTO "permission_overrides" (user_id, permission_key, allow) '
    'VALUES (3, "invoice.delete", 1)')
db.commit()


def can(user_id, role_name, key):
    """مرآة القرار: التجاوز الفردي يعلو، ثم دور المستخدم، ثم لا."""
    ov = db.execute(
        'SELECT allow FROM "permission_overrides" WHERE user_id = ? '
        'AND permission_key = ?', (user_id, key)).fetchone()
    if ov is not None:
        return bool(ov['allow'])
    rid = db.execute('SELECT role_id FROM "roles" WHERE name = ?',
                     (role_name,)).fetchone()
    if rid is None:
        return False
    return db.execute(
        'SELECT 1 FROM "role_permissions" WHERE role_id = ? '
        'AND permission_key = ?', (rid['role_id'], key)).fetchone() is not None


ok("[7] كاشير (3) مع تجاوز ⇒ يملك الحذف", can(3, 'cashier', 'invoice.delete'))
ok("[7] كاشير (4) بلا تجاوز ⇒ لا يملك", not can(4, 'cashier', 'invoice.delete'))

# تجاوز يمنع مديرًا من صلاحية يملكها دوره
db.execute(
    'INSERT INTO "permission_overrides" (user_id, permission_key, allow) '
    'VALUES (5, "reports.profit", 0)')
db.commit()
ok("[7] مدير (5) مع منع ⇒ لا يرى الأرباح",
   not can(5, 'manager', 'reports.profit'))
ok("[7] مدير (6) بلا تجاوز ⇒ يرى الأرباح",
   can(6, 'manager', 'reports.profit'))

# ═══════════ التقرير ═══════════

db.close()

print("\n" + "=" * 64)
print(f"  النتيجة: {PASS} ناجح · {FAIL} فاشل")
print("=" * 64)
sys.exit(1 if FAIL else 0)
