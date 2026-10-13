"""Validate the subscription cancel-refund settlement against the customer ledger.

Why this exists
---------------
`cancelWithSettlement` originally computed the credit base as:

    stored > 0 ? stored : (stored < 0 ? 0 : 0)

Both ternary branches are 0, so `base` was ALWAYS 0 for an indebted customer.
Cancelling a 50 subscription wiped the customer's entire debt: someone owing
200 ended up with +50 credit and zero debt — a 200 hole in receivables, and a
silent exploit (cancel a small subscription to erase a large debt).

The first fix attempt (simple netting) was ALSO wrong, because
`CustomerLedgerService.syncBalance` re-derives a negative balance from
`debtCents`, discarding the refund. The correct settlement is:

  1. Apply the refund to the customer's open invoices FIFO (reducing
     `remaining_amount`), exactly like a payment — so `debtCents` reflects it.
  2. Any leftover beyond the debt becomes credit on `customers.balance`.
  3. Re-derive via `syncBalance`.

This script models the ledger arithmetic and asserts the corrected behaviour,
including a regression check that the old formula was indeed broken.

It is a pure-logic harness (no Flutter, no sqflite) so it runs anywhere.
"""
import sys

FAILURES = []


def to_c(x):
    return round(x * 100)


def fr_c(c):
    return c / 100


class Ledger:
    """Faithful model of the customer ledger arithmetic."""

    def __init__(self, balance, invoice_debts):
        self.balance = to_c(balance)          # >0 credit, <0 debt
        self.inv = [to_c(d) for d in invoice_debts]

    def debt_cents(self):
        """Mirrors CustomerLedgerService.debtCents (SUM of remaining > 0)."""
        return max(0, sum(self.inv))

    def stored_balance_cents(self):
        return self.balance

    def sync_balance(self):
        """Mirrors CustomerLedgerService.syncBalance (keepCredit: true)."""
        stored = self.balance
        debt = self.debt_cents()
        self.balance = stored if stored > 0 else -debt

    def allocate_fifo(self, amount_cents):
        """Mirrors CustomerLedgerService.allocatePaymentFifo."""
        remaining = amount_cents
        touched = 0
        for i in range(len(self.inv)):
            if remaining <= 0:
                break
            due = self.inv[i]
            take = min(remaining, due)
            if take <= 0:
                continue
            self.inv[i] = due - take
            remaining -= take
            touched += 1
        if remaining > 0:
            base = self.balance if self.balance > 0 else 0
            self.balance = base + remaining
        else:
            self.sync_balance()
        return touched


def settle_fixed(ledger, refund_cents):
    """The corrected cancelWithSettlement refund-as-credit path."""
    debt = ledger.debt_cents()
    applied = refund_cents if refund_cents < debt else debt
    if applied > 0:
        ledger.allocate_fifo(applied)
    leftover = refund_cents - applied
    if leftover > 0:
        after = ledger.balance
        base = after if after > 0 else 0
        ledger.balance = base + leftover
    ledger.sync_balance()


def settle_buggy(ledger, refund_cents):
    """The original (defective) implementation, kept as a regression guard."""
    stored = ledger.balance
    base = stored if stored > 0 else (0 if stored < 0 else 0)
    ledger.balance = base + refund_cents
    ledger.sync_balance()


CASES = [
    # label, start balance, invoice debts, refund, expected balance, expected debt
    ("owes 200, refund 50",           -200.00, [200.00], 50.00, -150.00, 150.00),
    ("owes 30, refund 50 (excess)",    -30.00, [30.00],  50.00,   20.00,   0.00),
    ("no debt, refund 50",               0.00, [],       50.00,   50.00,   0.00),
    ("credit 100, refund 50",          100.00, [],       50.00,  150.00,   0.00),
    ("owes 50 exactly, refund 50",     -50.00, [50.00],  50.00,    0.00,   0.00),
    ("owes 300 across 3 invoices, refund 100", -300.00,
     [100.00, 100.00, 100.00], 100.00, -200.00, 200.00),
    ("owes 80 on 2 invoices, refund 100",      -80.00,
     [50.00, 30.00], 100.00, 20.00, 0.00),
]

print("subscription cancel-refund settlement\n")
print(f"{'case':<46} {'balance':>9} {'debt':>8}  result")
print("-" * 82)

for label, bal, debts, refund, exp_bal, exp_debt in CASES:
    led = Ledger(bal, debts)
    settle_fixed(led, to_c(refund))
    ok = (
        abs(led.balance - to_c(exp_bal)) <= 1
        and abs(led.debt_cents() - to_c(exp_debt)) <= 1
    )
    if not ok:
        FAILURES.append(
            (label, f"balance={fr_c(led.balance)} debt={fr_c(led.debt_cents())} "
                    f"expected balance={exp_bal} debt={exp_debt}")
        )
    print(
        f"{label:<46} {fr_c(led.balance):>9.2f} {fr_c(led.debt_cents()):>8.2f}  "
        f"{'OK' if ok else 'FAIL'}"
    )

# ── Invariant: the refund must never increase the customer's net position by
#    more than the refund itself, and debt must never grow.
print("\ninvariants:")
for label, bal, debts, refund, _, _ in CASES:
    before = Ledger(bal, debts)
    after = Ledger(bal, debts)
    settle_fixed(after, to_c(refund))
    debt_grew = after.debt_cents() > before.debt_cents() + 1
    # net position = credit - debt
    net_before = before.balance if before.balance > 0 else -before.debt_cents()
    net_after = after.balance if after.balance > 0 else -after.debt_cents()
    gained = net_after - net_before
    over_gain = gained > to_c(refund) + 1
    if debt_grew or over_gain:
        FAILURES.append(
            (label, f"debt_grew={debt_grew} over_gain={over_gain} "
                    f"(gained {fr_c(gained)} vs refund {refund})")
        )
    print(
        f"  {'OK  ' if not (debt_grew or over_gain) else 'FAIL'} {label:<44} "
        f"net {fr_c(net_before):>8.2f} -> {fr_c(net_after):>8.2f}  "
        f"(gained {fr_c(gained):>7.2f}, refund {refund:>7.2f})"
    )

# ── Regression guard: prove the OLD formula was genuinely broken, so nobody
#    "simplifies" the fix back to it.
print("\nregression guard (old formula must remain broken):")
old_broken = False
for label, bal, debts, refund, exp_bal, _ in CASES:
    led = Ledger(bal, debts)
    settle_buggy(led, to_c(refund))
    if abs(led.balance - to_c(exp_bal)) > 1:
        old_broken = True
        break
if old_broken:
    print("  OK   old formula deviates from expected on at least one case")
else:
    FAILURES.append(("regression", "old formula now matches expected — "
                                   "test no longer guards anything"))
    print("  FAIL old formula matches expected; guard is inert")

print("\n" + "=" * 62)
if FAILURES:
    print(f"RESULT: {len(FAILURES)} FAILURE(S)")
    for label, err in FAILURES:
        print(f"  - {label}: {err}")
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
