#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات لقطة بنود الفاتورة (`invoice_items`) على SQLite حقيقي.

يُشغّل **نفس استعلامات** `InvoiceItemsService.costFor` على قاعدة مصغّرة،
ويُثبت أن العيبين الصامتين في الربط بالاسم قد زالا:

  1. إعادة تسمية صنف كانت تُصفّر تكلفة كل فواتيره التاريخية ⇒ الربح ينتفخ.
  2. تعديل `cost_price` كان يُعيد كتابة أرباح الماضي.

ويُثبت أيضًا أن الرجوع الاحتياطي **لا يُحتسب مرتين**.
"""
import json
import sqlite3
import sys

PASS = 0
FAIL = 0


def check(label, got, want):
    global PASS, FAIL
    ok = got == want
    if ok:
        PASS += 1
        print(f"  PASS  {label}: {got}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}: got {got!r} expected {want!r}")


def near(label, got, want):
    global PASS, FAIL
    ok = abs(got - want) < 0.011
    if ok:
        PASS += 1
        print(f"  PASS  {label}: {got:.2f}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}: got {got:.2f} expected {want:.2f}")


# ═══════════ الاستعلامات المنقولة حرفيًا من InvoiceItemsService ═══════════

Q_SNAPSHOT = """
SELECT COALESCE(SUM(ii.total_cost), 0) AS cost
FROM invoice_items ii
JOIN invoices i ON i.invoices_id = ii.invoice_id
WHERE {where}
"""

Q_LEGACY = """
SELECT COALESCE(SUM(CAST(json_extract(j.value, '$.count') AS INTEGER)
  * COALESCE(c.cost_price, 0)), 0) AS cost
FROM invoices i, json_each(i.list_data) j, clothing c
WHERE {where}
  AND json_extract(j.value, '$.vestments') = c.clothing_name
  AND NOT EXISTS (
    SELECT 1 FROM invoice_items ii WHERE ii.invoice_id = i.invoices_id
  )
"""


def cost_for(db, where, args):
    a = db.execute(Q_SNAPSHOT.format(where=where), args).fetchone()[0]
    b = db.execute(Q_LEGACY.format(where=where), args).fetchone()[0]
    return a + b


def snapshot_rows(raw, clothing_by_name):
    """نفس منطق `_itemRowsFromJson` في sqldb.dart."""
    out = []
    try:
        decoded = json.loads(raw) if raw else []
    except Exception:
        return out
    if not isinstance(decoded, list):
        return out
    for item in decoded:
        if not isinstance(item, dict):
            continue
        name = str(item.get('vestments') or '').strip()
        if not name:
            continue
        qty = int(float(item.get('count') or 0))
        price = float(item.get('price') or 0)
        line_total = float(item.get('total_price') or 0)
        total = line_total if line_total > 0 else price * qty
        c = clothing_by_name.get(name)
        cost = float(c['cost_price']) if c else 0.0
        out.append({
            'clothing_id': c['clothing_id'] if c else None,
            'item_name': name,
            'content': str(item.get('content') or ''),
            'qty': qty,
            'unit_price': price,
            'unit_cost': cost,
            'total_price': total,
            'total_cost': round(cost * qty, 2),
            'note': 'لقطة مُستنتجة عند الترحيل',
            'created_at': '2026-10-01T00:00:00.000',
        })
    return out


def build():
    db = sqlite3.connect(":memory:")
    db.executescript(
        """
        CREATE TABLE clothing (
          clothing_id INTEGER PRIMARY KEY, clothing_name TEXT,
          cost_price REAL DEFAULT 0);
        CREATE TABLE invoices (
          invoices_id INTEGER PRIMARY KEY, invoice_date TEXT,
          subscription_id INTEGER, list_data TEXT);
        CREATE TABLE invoice_items (
          item_id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER,
          clothing_id INTEGER, item_name TEXT, content TEXT, qty INTEGER,
          unit_price REAL, unit_cost REAL, total_price REAL,
          total_cost REAL, note TEXT, created_at TEXT);
        """
    )
    db.execute("INSERT INTO clothing VALUES (1,'ثوب', 4.0)")
    db.execute("INSERT INTO clothing VALUES (2,'بنطال', 3.0)")

    # فاتورة 1: 3 أثواب (تكلفة 4) + 2 بناطيل (تكلفة 3) ⇒ تكلفة 18
    db.execute(
        "INSERT INTO invoices VALUES (1,'2026-09-01T10:00:00.000', NULL, ?)",
        (json.dumps([
            {"vestments": "ثوب", "content": "غسيل", "count": 3,
             "price": 50, "total_price": 150},
            {"vestments": "بنطال", "content": "غسيل", "count": 2,
             "price": 75, "total_price": 150},
        ]),),
    )
    # فاتورة 2 (اشتراكية): 5 قمصان غير مسجّلة في المخزون ⇒ تكلفة 0
    db.execute(
        "INSERT INTO invoices VALUES (2,'2026-09-10T10:00:00.000', 7, ?)",
        (json.dumps([
            {"vestments": "قميص", "content": "غسيل", "count": 5,
             "price": 16, "total_price": 80},
        ]),),
    )
    db.commit()
    return db


def main():
    db = build()

    # ═══ 1) الترحيل: تعبئة اللقطة من list_data ═══
    print("\n[1] ترحيل اللقطة من الفواتير القديمة")

    clothing = {
        r[0]: {'clothing_id': r[1], 'cost_price': r[2]}
        for r in db.execute(
            "SELECT clothing_name, clothing_id, cost_price FROM clothing"
        )
    }
    inserted = 0
    for iid, raw in db.execute("SELECT invoices_id, list_data FROM invoices"):
        rows = snapshot_rows(raw, clothing)
        for r in rows:
            r['invoice_id'] = iid
            db.execute(
                "INSERT INTO invoice_items (invoice_id, clothing_id, "
                "item_name, content, qty, unit_price, unit_cost, total_price, "
                "total_cost, note, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (r['invoice_id'], r['clothing_id'], r['item_name'],
                 r['content'], r['qty'], r['unit_price'], r['unit_cost'],
                 r['total_price'], r['total_cost'], r['note'],
                 r['created_at']),
            )
            inserted += 1
    db.commit()
    check("عدد البنود المُلتقطة (2 + 1)", inserted, 3)
    check(
        "بنود فاتورة 1",
        db.execute(
            "SELECT COUNT(*) FROM invoice_items WHERE invoice_id = 1"
        ).fetchone()[0],
        2,
    )
    near(
        "تكلفة فاتورة 1 من اللقطة (3×4 + 2×3 = 18)",
        cost_for(db, "i.invoices_id = ?", [1]),
        18.0,
    )
    near(
        "صنف غير مسجَّل في المخزون ⇒ تكلفته صفر (لا يُختلق رقم)",
        cost_for(db, "i.invoices_id = ?", [2]),
        0.0,
    )

    # ═══ 2) إعادة الترحيل لا تُضاعف ═══
    print("\n[2] حارس الترحيل: لا تكرار ولا مضاعفة")

    again = 0
    for iid, raw in db.execute("SELECT invoices_id, list_data FROM invoices"):
        already = db.execute(
            "SELECT COUNT(*) FROM invoice_items WHERE invoice_id = ?", (iid,)
        ).fetchone()[0]
        if already > 0:
            continue
        again += len(snapshot_rows(raw, clothing))
    check("الفواتير ذات اللقطة تُتخطّى", again, 0)
    check(
        "عدد البنود لم يتغيّر",
        db.execute("SELECT COUNT(*) FROM invoice_items").fetchone()[0],
        3,
    )
    near(
        "التكلفة لم تتضاعف",
        cost_for(db, "i.invoices_id = ?", [1]),
        18.0,
    )

    # ═══ 3) 🔴 العيب الأول: إعادة تسمية صنف ═══
    print("\n[3] 🔴 إعادة تسمية صنف — العيب الذي كان يُصفّر التكلفة")

    # ما كانت النتيجة قبل الإصلاح: الربط بالاسم وحده
    legacy_only = db.execute(
        "SELECT COALESCE(SUM(CAST(json_extract(j.value,'$.count') AS INTEGER)"
        " * COALESCE(c.cost_price,0)),0) FROM invoices i, "
        "json_each(i.list_data) j, clothing c "
        "WHERE i.invoices_id = 1 "
        "AND json_extract(j.value,'$.vestments') = c.clothing_name"
    ).fetchone()[0]
    near("قبل التسمية: الربط بالاسم يعطي التكلفة", legacy_only, 18.0)

    db.execute("UPDATE clothing SET clothing_name = 'ثوب رجالي' WHERE clothing_id = 1")
    db.commit()

    # ملاحظة: الفاتورة 1 تحمل بندين — «ثوب» (3×4=12) و«بنطال» (2×3=6).
    # التسمية تُبطل ربط «ثوب» وحده، فيبقى «بنطال» ملتصقًا (6). لذا يُقاس الفقد
    # مرّتين: إجماليًا (12 يُفقد) وعلى البند المُعاد تسميته حصرًا (صفر).
    legacy_after = db.execute(
        "SELECT COALESCE(SUM(CAST(json_extract(j.value,'$.count') AS INTEGER)"
        " * COALESCE(c.cost_price,0)),0) FROM invoices i, "
        "json_each(i.list_data) j, clothing c "
        "WHERE i.invoices_id = 1 "
        "AND json_extract(j.value,'$.vestments') = c.clothing_name"
    ).fetchone()[0]
    near(
        "🔴 بعد التسمية: الربط بالاسم يفقد البند المُعاد تسميته (12)",
        legacy_after,
        6.0,
    )
    legacy_renamed_only = db.execute(
        "SELECT COALESCE(SUM(CAST(json_extract(j.value,'$.count') AS INTEGER)"
        " * COALESCE(c.cost_price,0)),0) FROM invoices i, "
        "json_each(i.list_data) j, clothing c "
        "WHERE i.invoices_id = 1 "
        "AND json_extract(j.value,'$.vestments') = 'ثوب' "
        "AND json_extract(j.value,'$.vestments') = c.clothing_name"
    ).fetchone()[0]
    near(
        "🔴 البند المُعاد تسميته تحديدًا: الربط بالاسم يعطي صفرًا",
        legacy_renamed_only,
        0.0,
    )
    near(
        "✅ اللقطة تحفظ التكلفة التاريخية (12 للثوب + 6 للبنطال)",
        cost_for(db, "i.invoices_id = ?", [1]),
        12.0 + 6.0,
    )
    check(
        "اسم البند في اللقطة لم يتغيّر",
        db.execute(
            "SELECT item_name FROM invoice_items WHERE item_id = 1"
        ).fetchone()[0],
        "ثوب",
    )

    # ═══ 4) 🔴 العيب الثاني: تعديل سعر التكلفة ═══
    print("\n[4] 🔴 تعديل سعر التكلفة — لا يُعيد كتابة أرباح الماضي")

    db.execute("UPDATE clothing SET cost_price = 99.0")
    db.commit()

    near(
        "✅ تكلفة فاتورة قديمة ثابتة على 18 (لا 297)",
        cost_for(db, "i.invoices_id = ?", [1]),
        18.0,
    )
    # فاتورة جديدة بالتكلفة الجديدة
    db.execute(
        "INSERT INTO invoices VALUES (3,'2026-10-01T10:00:00.000', NULL, ?)",
        (json.dumps([
            {"vestments": "ثوب رجالي", "content": "غسيل", "count": 1,
             "price": 50, "total_price": 50},
        ]),),
    )
    db.commit()
    clothing2 = {
        r[0]: {'clothing_id': r[1], 'cost_price': r[2]}
        for r in db.execute(
            "SELECT clothing_name, clothing_id, cost_price FROM clothing"
        )
    }
    for r in snapshot_rows(
        json.dumps([{"vestments": "ثوب رجالي", "content": "غسيل", "count": 1,
                     "price": 50, "total_price": 50}]),
        clothing2,
    ):
        r['invoice_id'] = 3
        db.execute(
            "INSERT INTO invoice_items (invoice_id, clothing_id, item_name, "
            "content, qty, unit_price, unit_cost, total_price, total_cost, "
            "note, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (3, r['clothing_id'], r['item_name'], r['content'], r['qty'],
             r['unit_price'], r['unit_cost'], r['total_price'],
             r['total_cost'], r['note'], r['created_at']),
        )
    db.commit()
    near(
        "فاتورة اليوم تُلتقط بالتكلفة الجديدة (99)",
        cost_for(db, "i.invoices_id = ?", [3]),
        99.0,
    )
    near(
        "إجمالي كل الفواتير = 18 + 0 + 99",
        cost_for(db, "1 = 1", []),
        117.0,
    )

    # ═══ 5) الرجوع الاحتياطي بلا احتساب مزدوج ═══
    print("\n[5] الرجوع الاحتياطي (فواتير بلا لقطة) بلا احتساب مزدوج")

    db.execute(
        "INSERT INTO invoices VALUES (4,'2026-10-02T10:00:00.000', NULL, ?)",
        (json.dumps([
            {"vestments": "ثوب رجالي", "content": "غسيل", "count": 2,
             "price": 50, "total_price": 100},
        ]),),
    )
    db.commit()
    # فاتورة 4 بلا لقطة ⇒ تُحتسب بالربط بالاسم (2 × 99)
    near(
        "فاتورة بلا لقطة تُحتسب بالربط بالاسم",
        cost_for(db, "i.invoices_id = ?", [4]),
        198.0,
    )
    near(
        "الإجمالي بعد إضافة الفاتورة 4 = 18 + 0 + 99 + 198",
        cost_for(db, "1 = 1", []),
        315.0,
    )

    # الآن نضيف لقطة للفاتورة 4 ⇒ يجب ألّا تُحتسب مرتين
    for r in snapshot_rows(
        json.dumps([{"vestments": "ثوب رجالي", "content": "غسيل", "count": 2,
                     "price": 50, "total_price": 100}]),
        clothing2,
    ):
        r['invoice_id'] = 4
        db.execute(
            "INSERT INTO invoice_items (invoice_id, clothing_id, item_name, "
            "content, qty, unit_price, unit_cost, total_price, total_cost, "
            "note, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (4, r['clothing_id'], r['item_name'], r['content'], r['qty'],
             r['unit_price'], r['unit_cost'], r['total_price'],
             r['total_cost'], r['note'], r['created_at']),
        )
    db.commit()
    near(
        "بعد إضافة اللقطة: نفس التكلفة (لا مضاعفة)",
        cost_for(db, "i.invoices_id = ?", [4]),
        198.0,
    )
    near(
        "الإجمالي لم يتغيّر",
        cost_for(db, "1 = 1", []),
        315.0,
    )

    # ═══ 6) فلترة الاشتراكات ═══
    print("\n[6] فلترة الفواتير الاشتراكية (نفس نمط التقارير)")

    near(
        "الاشتراكية وحدها",
        cost_for(db, "i.subscription_id IS NOT NULL", []),
        0.0,
    )
    near(
        "غير الاشتراكية وحدها",
        cost_for(db, "i.subscription_id IS NULL", []),
        315.0,
    )

    print(f"\n{'=' * 52}")
    print(f"  النتيجة: {PASS} ناجح · {FAIL} فاشل")
    print('=' * 52)
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
