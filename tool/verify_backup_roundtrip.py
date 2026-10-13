# -*- coding: utf-8 -*-
"""
فحوص النسخ الاحتياطي على **ملفات SQLite حقيقية**.

    python tool/verify_backup_roundtrip.py

يثبت عمليًا - لا وصفًا - أربع حقائق يقوم عليها التنفيذ:

  1. ترويسة قاعدة البيانات الحقيقية تجتاز الفحص، وأي ملف آخر (ZIP/JSON/نص/
     مقتطع) يُرفض. (نفس القاعدة المطبقة في BackupNaming.validateBackupHeader)
  2. **النسخ المباشر لملف قاعدة مفتوحة في وضع WAL يفقد بيانات مُثبَّتة**،
     بينما `VACUUM INTO` يحفظها كاملة — وهذا سبب استخدامنا اللقطة لا النسخ.
  3. بقاء ملفات الجانب (-wal/-shm) مع ملف مستبدَل يُفسد الناتج أو يُخفي
     البيانات المستعادة — وهذا سبب حذفها قبل كل استعادة.
  4. الاستعادة الآمنة تعمل فعلًا: نفسها (استبدال + فحص + رجوع) تُنتج بيانات
     النسخة، والملف التالف يُرفض قبل لمس أي شيء.
"""

import json
import os
import shutil
import sqlite3
import struct
import sys
import tempfile
import zipfile

PASS = 0
FAIL = 0


def check(label, ok, detail=""):
    global PASS, FAIL
    if ok:
        PASS += 1
        print("  \u2705 " + label)
    else:
        FAIL += 1
        print("  \u274c " + label + ("  \u2192  " + str(detail) if detail else ""))


SQLITE_MAGIC = b"SQLite format 3\x00"
VALID_PAGE_SIZES = {1, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536}


def validate_backup_header(head):
    """مرآة القاعدة في BackupNaming.validateBackupHeader."""
    if len(head) < 100:
        return False
    if head[:16] != SQLITE_MAGIC:
        return False
    page_size = struct.unpack(">H", head[16:18])[0]
    return page_size in VALID_PAGE_SIZES


REQUIRED_TABLES = ["users", "settings", "invoices", "shifts"]


def make_system_db(path, invoices=3, tag="A"):
    """قاعدة مصغّرة بنفس الجداول الجوهرية في النظام."""
    con = sqlite3.connect(path)
    con.executescript(
        """
        CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT);
        CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE shifts (shift_id INTEGER PRIMARY KEY, start_time TEXT);
        CREATE TABLE invoices (
            invoice_id INTEGER PRIMARY KEY,
            invoice_date TEXT,
            total REAL,
            note TEXT
        );
        """
    )
    con.execute("INSERT INTO users VALUES (1, 'admin')")
    con.execute("INSERT INTO settings VALUES ('business_name', 'مغسلة')")
    con.execute("INSERT INTO shifts VALUES (1, '2026-09-21 09:00:00')")
    for i in range(1, invoices + 1):
        con.execute(
            "INSERT INTO invoices VALUES (?, ?, ?, ?)",
            (i, "2026-09-21 1%d:00:00" % i, 100.0 * i, tag),
        )
    con.commit()
    con.close()


def inspect_like_service(path):
    """مرآة inspectBackupFile: ترويسة ثم سلامة بنية ثم وجود الجداول."""
    if not os.path.exists(path):
        return (False, "غير موجود", 0, 0)
    size = os.path.getsize(path)
    if size < 512:
        return (False, "أصغر من أن يكون قاعدة بيانات", size, 0)
    with open(path, "rb") as fh:
        head = fh.read(100)
    if not validate_backup_header(head):
        return (False, "ليست ترويسة SQLite", size, 0)
    try:
        con = sqlite3.connect("file:%s?mode=ro" % path, uri=True)
        verdict = con.execute("PRAGMA integrity_check").fetchone()[0]
        if str(verdict).lower() != "ok":
            return (False, "فحص السلامة فشل: %s" % verdict, size, 0)
        names = {
            r[0]
            for r in con.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        missing = [t for t in REQUIRED_TABLES if t not in names]
        if missing:
            return (False, "جداول مفقودة: %s" % "،".join(missing), size, 0)
        count = con.execute("SELECT COUNT(*) FROM invoices").fetchone()[0]
        con.close()
        return (True, "", size, count)
    except Exception as exc:  # noqa: BLE001
        return (False, "تعذّر فتحه كقاعدة: %s" % exc, size, 0)


def invoices_of(path):
    con = sqlite3.connect(path)
    try:
        return con.execute("SELECT COUNT(*) FROM invoices").fetchone()[0]
    finally:
        con.close()


def safe_invoices_of(path):
    """يقرأ الفواتير ويعيد 0 إن كان الملف غير مقروء كقاعدة النظام.

    النسخ المباشر لملف في وضع WAL قد لا يحوي حتى الجداول (فالصفحات كلها
    لا تزال في -wal)، وهذا بحد ذاته دليل على قصور النسخ المباشر.
    """
    try:
        return invoices_of(path)
    except Exception:  # noqa: BLE001
        return 0


def tags_of(path):
    con = sqlite3.connect(path)
    try:
        return sorted(r[0] for r in con.execute("SELECT DISTINCT note FROM invoices"))
    finally:
        con.close()


def read_snapshot_via_vacuum(live_path, dest):
    """مرآة BackupService._snapshotTo."""
    if os.path.exists(dest):
        os.remove(dest)
    con = sqlite3.connect(live_path)
    try:
        con.execute("VACUUM INTO ?", (dest,))
    finally:
        con.close()


def main():
    work = tempfile.mkdtemp(prefix="laundry_backup_verify_")
    try:
        print("\u2550\u2550 1) فحص الملفات: ما يُقبل وما يُرفض \u2550\u2550")

        good = os.path.join(work, "good.db")
        make_system_db(good, invoices=4)
        ok, reason, size, count = inspect_like_service(good)
        check("قاعدة النظام الحقيقية تُقبل", ok, reason)
        check("عدد الفواتير يُقرأ صحيحًا", count == 4, count)
        check("حجمها فوق الحد الأدنى", size >= 512)

        with open(good, "rb") as fh:
            check("ترويسة القاعدة الحقيقية صحيحة", validate_backup_header(fh.read(100)))

        # ملف ZIP
        zip_path = os.path.join(work, "archive.db")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("a.txt", "x" * 2000)
        ok, reason, _, _ = inspect_like_service(zip_path)
        check("ملف ZIP يُرفض", not ok, reason)
        check("سبب الرفض يذكر الترويسة", "ترويسة" in reason, reason)

        # ملف JSON
        json_path = os.path.join(work, "data.db")
        with open(json_path, "w", encoding="utf-8") as fh:
            json.dump({"invoices": 12}, fh)
            fh.write(" " * 2000)
        ok, reason, _, _ = inspect_like_service(json_path)
        check("ملف JSON يُرفض", not ok, reason)

        # نص عادي
        text_path = os.path.join(work, "notes.db")
        with open(text_path, "w", encoding="utf-8") as fh:
            fh.write("هذه ملاحظات وليست قاعدة بيانات\n" * 60)
        ok, reason, _, _ = inspect_like_service(text_path)
        check("ملف نصي يُرفض", not ok, reason)

        # مقتطع
        trunc = os.path.join(work, "truncated.db")
        with open(good, "rb") as src, open(trunc, "wb") as dst:
            dst.write(src.read(40))
        ok, reason, _, _ = inspect_like_service(trunc)
        check("ملف مقتطع (40 بايت) يُرفض", not ok, reason)

        # قاعدة بجداول غريبة (نظام آخر)
        alien = os.path.join(work, "alien.db")
        con = sqlite3.connect(alien)
        con.execute("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT)")
        con.execute("INSERT INTO products VALUES (1, 'x')")
        con.commit()
        con.close()
        ok, reason, _, _ = inspect_like_service(alien)
        check("قاعدة من نظام آخر تُرفض", not ok, reason)
        check("سبب الرفض يذكر الجداول المفقودة", "مفقودة" in reason, reason)

        # قاعدة مبنية على مستوى الصفحة نفسه
        page_probe = os.path.join(work, "pagesize.db")
        con = sqlite3.connect(page_probe)
        con.execute("PRAGMA page_size = 8192")
        con.execute("CREATE TABLE t (x INTEGER)")
        con.commit()
        con.close()
        with open(page_probe, "rb") as fh:
            head = fh.read(100)
        check(
            "حجم الصفحة 8192 مُرمّز يُقبل",
            struct.unpack(">H", head[16:18])[0] == 8192,
            struct.unpack(">H", head[16:18])[0],
        )

        print("\n\u2550\u2550 2) لقطة VACUUM INTO مقابل النسخ المباشر (WAL) \u2550\u2550")

        wal_live = os.path.join(work, "wal_live.db")
        con = sqlite3.connect(wal_live, isolation_level=None)
        con.execute("PRAGMA journal_mode=WAL")
        con.executescript(
            """
            CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT);
            CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT);
            CREATE TABLE shifts (shift_id INTEGER PRIMARY KEY, start_time TEXT);
            CREATE TABLE invoices (
                invoice_id INTEGER PRIMARY KEY, invoice_date TEXT,
                total REAL, note TEXT
            );
            INSERT INTO users VALUES (1, 'admin');
            INSERT INTO settings VALUES ('business_name', 'مغسلة');
            INSERT INTO shifts VALUES (1, '2026-09-21 09:00:00');
            """
        )
        for i in range(1, 6):
            con.execute(
                "INSERT INTO invoices VALUES (?, ?, ?, ?)",
                (i, "2026-09-21 10:0%d:00" % i, 50.0 * i, "WAL"),
            )
        # مُثبَّتة (commit) لكن بقاياها قد تبقى في -wal لا في الملف الرئيسي.

        raw_copy = os.path.join(work, "raw_copy.db")
        shutil.copyfile(wal_live, raw_copy)

        vacuum_copy = os.path.join(work, "vacuum_copy.db")
        read_snapshot_via_vacuum(wal_live, vacuum_copy)

        raw_count = safe_invoices_of(raw_copy) if os.path.exists(raw_copy) else 0
        vac_count = invoices_of(vacuum_copy)
        con.close()

        check(
            "VACUUM INTO يحفظ كل الفواتير المثبَّتة",
            vac_count == 5,
            vac_count,
        )
        check(
            "النسخ المباشر لملف WAL يُنتج نسخة ناقصة",
            raw_count < 5,
            "النسخ المباشر أعطى %d من 5 (وهذا سبب استخدام اللقطة)" % raw_count,
        )
        check(
            "اللقطة تجتاز الفحص كذلك",
            inspect_like_service(vacuum_copy)[0],
            inspect_like_service(vacuum_copy)[1],
        )

        print("\n\u2550\u2550 3) خطر بقايا ملفات الجانب مع ملف مستبدَل \u2550\u2550")

        # قاعدة A في وضع WAL مع بيانات مُثبَّتة، وقاعدة B مختلفة.
        #
        # **لا نغلق اتصال A قبل النسخ:** SQLite يعمل checkpoint تلقائيًا عند
        # إغلاق آخر اتصال فيختفي -wal، ولا يبقى ما نُحاكيه. الاتصال يبقى مفتوحًا
        # كما هي حال قاعدة بيانات التطبيق أثناء العمل.
        db_a = os.path.join(work, "live_a.db")
        make_system_db(db_a, invoices=2, tag="A")
        con_a = sqlite3.connect(db_a, isolation_level=None)
        con_a.execute("PRAGMA journal_mode=WAL")
        con_a.execute(
            "INSERT INTO invoices VALUES (99, '2026-09-21 23:00:00', 999, 'A')"
        )
        sidecars = [p for p in (db_a + "-wal", db_a + "-shm") if os.path.exists(p)]
        check(
            "للقاعدة الحيّة ملفات جانب فعلًا",
            len(sidecars) > 0,
            "لا ملفات جانب — يتخطى الفحص هذا الجزء",
        )

        db_b = os.path.join(work, "source_b.db")
        make_system_db(db_b, invoices=5, tag="B")

        # استبدال **بلا** حذف ملفات الجانب (السلوك القديم):
        # ملفات الجانب تحمل اسم قاعدة **الهدف** كما في الواقع، فتبقى من A
        # بينما الملف الرئيسي يُستبدل ببيانات B.
        bad_target = os.path.join(work, "restore_keep_sidecar.db")
        shutil.copyfile(db_a, bad_target)
        for p in sidecars:
            suffix = "-wal" if p.endswith("-wal") else "-shm"
            shutil.copyfile(p, bad_target + suffix)
        shutil.copyfile(db_b, bad_target)  # الملف الرئيسي صار B والجانب من A
        con_a.close()

        corrupted = False
        detail = ""
        try:
            tags = tags_of(bad_target)
            corrupted = tags != ["B"]
            detail = "البيانات بعد الاستعادة: %s (المتوقع ['B'])" % tags
        except Exception as exc:  # noqa: BLE001
            corrupted = True
            detail = "قاعدة غير قابلة للقراءة بعد الاستعادة: %s" % exc
        check(
            "بقايا -wal/-shm مع ملف مستبدَل تُفسد الناتج",
            corrupted,
            detail,
        )

        # استبدال **مع** حذف ملفات الجانب (سلوكنا الآن)
        good_target = os.path.join(work, "restore_clean.db")
        shutil.copyfile(db_a, good_target)
        for suffix in ("-wal", "-shm", "-journal"):
            p = good_target + suffix
            if os.path.exists(p):
                os.remove(p)
        shutil.copyfile(db_b, good_target)
        check(
            "حذف ملفات الجانب قبل النسخ يعطي بيانات النسخة كاملة",
            tags_of(good_target) == ["B"],
            tags_of(good_target),
        )

        print("\n\u2550\u2550 4) دورة الاستعادة الكاملة: فحص → أمان → استبدال → فحص \u2550\u2550")

        live = os.path.join(work, "live.db")
        make_system_db(live, invoices=9, tag="LIVE")
        source = os.path.join(work, "source.db")
        make_system_db(source, invoices=3, tag="RESTORED")

        ok, reason, _, src_count = inspect_like_service(source)
        check("المصدر يجتاز الفحص قبل الاستعادة", ok, reason)

        # نسخة أمان بأسلوبنا (VACUUM INTO + فحص)
        safety = os.path.join(work, "pre_restore_2026-09-21_143000.db")
        read_snapshot_via_vacuum(live, safety)
        ok, reason, _, safety_count = inspect_like_service(safety)
        check("نسخة الأمان صالحة", ok, reason)
        check("نسخة الأمان تحمل بيانات الحالة الراهنة", safety_count == 9, safety_count)

        # استبدال
        for suffix in ("-wal", "-shm", "-journal"):
            p = live + suffix
            if os.path.exists(p):
                os.remove(p)
        shutil.copyfile(source, live)
        ok, reason, _, after = inspect_like_service(live)
        check("الناتج يجتاز الفحص بعد الاستعادة", ok, reason)
        check("الناتج يحمل بيانات النسخة", after == 3 and tags_of(live) == ["RESTORED"], after)

        # محاكاة فشل: ملف تالف يُنسخ ثم يُرفض ⇒ رجوع من نسخة الأمان
        shutil.copyfile(trunc, live)
        ok, reason, _, _ = inspect_like_service(live)
        check("الملف التالف يُرفض بعد النسخ (فيُشغّل الرجوع)", not ok, reason)
        shutil.copyfile(safety, live)
        ok, reason, _, rolled = inspect_like_service(live)
        check("الرجوع من نسخة الأمان يعيد بيانات المستخدم", ok and rolled == 9, rolled)

        print("\n\u2550\u2550 5) اسم ملف آمن بلا نقطتين \u2550\u2550")
        name = "laundry_pos_2026-09-21_1430.db"
        check("الاسم بلا نقطتين (Windows)", ":" not in name, name)
        check("الاسم بامتداد .db", name.endswith(".db"), name)
        check("الاسم صالح كمسار نظام", make_safe_probe(work, name))
        check(
            "مانع التكرار ينتج اسمًا جديدًا",
            dedupe("a.db", {"a.db"}) == "a_2.db",
            dedupe("a.db", {"a.db"}),
        )
        check(
            "مانع التكرار لا يفرّق بحالة الأحرف",
            dedupe("Backup.db", {"backup.DB"}) == "Backup_2.db",
            dedupe("Backup.db", {"backup.DB"}),
        )
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print("\n" + "\u2550" * 36)
    print("النتيجة: %d نجحت · %d فشلت" % (PASS, FAIL))
    if FAIL:
        sys.exit(1)


def dedupe(name, existing):
    """مرآة BackupNaming.dedupeName."""
    taken = {e.lower() for e in existing}
    if name.lower() not in taken:
        return name
    stem, dot, ext = name.rpartition(".")
    if not dot:
        stem, ext = name, ""
    counter = 2
    while ("%s_%d.%s" % (stem, counter, ext)).lower() in taken:
        counter += 1
    return "%s_%d.%s" % (stem, counter, ext)


def make_safe_probe(work, name):
    """هل يمكن فعلًا إنشاء ملف بهذا الاسم؟"""
    try:
        path = os.path.join(work, name)
        with open(path, "wb") as fh:
            fh.write(b"x")
        return os.path.exists(path)
    except OSError:
        return False


if __name__ == "__main__":
    main()
