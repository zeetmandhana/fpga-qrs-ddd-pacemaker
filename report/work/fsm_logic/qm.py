"""
qm.py -- small exact two-level minimiser (Quine-McCluskey + covering by
branch-and-bound) used for the encoding search and the covering-table study.
Cubes are strings over {'0','1','-'}; minterms are ints (MSB = variable 0).
"""
from __future__ import annotations

from functools import lru_cache
from itertools import product


def cube_minterms(cube: str) -> frozenset:
    opts = [("0", "1") if c == "-" else (c,) for c in cube]
    return frozenset(int("".join(p), 2) for p in product(*opts))


def lits(cube: str) -> int:
    return sum(c != "-" for c in cube)


def primes(on: frozenset, dc: frozenset, nv: int):
    terms = {format(m, "0%db" % nv) for m in (on | dc)}
    pis = set()
    while terms:
        nxt, used = set(), set()
        tl = sorted(terms)
        for i in range(len(tl)):
            for j in range(i + 1, len(tl)):
                a, b = tl[i], tl[j]
                diff = [k for k in range(nv) if a[k] != b[k]]
                if len(diff) == 1 and a[diff[0]] != "-" and b[diff[0]] != "-":
                    nxt.add(a[:diff[0]] + "-" + a[diff[0] + 1:])
                    used.update((a, b))
        pis |= terms - used
        terms = nxt
    # keep only primes that cover at least one ON minterm
    return sorted(p for p in pis if cube_minterms(p) & on)


def reduce_table(rows: dict, cols: dict, log=None):
    """rows: minterm -> set(col); cols: col -> set(minterm). Applies essential
    columns, row dominance and column dominance until nothing changes.
    Returns (chosen essentials, reduced rows, reduced cols)."""
    rows = {r: set(c) for r, c in rows.items()}
    cols = {c: set(r) for c, r in cols.items()}
    chosen = []
    changed = True
    it = 0
    while changed and rows:
        changed = False
        it += 1
        # essential columns
        ess = {next(iter(c)) for r, c in rows.items() if len(c) == 1}
        if ess:
            for c in ess:
                chosen.append(c)
                for r in list(cols.get(c, ())):
                    if r in rows:
                        for cc in rows[r]:
                            cols[cc].discard(r)
                        del rows[r]
                cols.pop(c, None)
            changed = True
            if log is not None:
                log.append("essential: %s" % sorted(ess))
            continue
        # row dominance: row r1 dominates r2 if cols(r1) >= cols(r2) -> drop r1
        rl = list(rows)
        drop = set()
        for a in rl:
            for b in rl:
                if a != b and a not in drop and b not in drop and rows[a] >= rows[b] and (rows[a] != rows[b] or a > b):
                    drop.add(a)
        if drop:
            for r in drop:
                for cc in rows[r]:
                    cols[cc].discard(r)
                del rows[r]
            changed = True
            if log is not None:
                log.append("row dominance removed %d rows" % len(drop))
        # column dominance (equal cost assumed per literal count): col c1 dominated by c2
        cl = [c for c in cols if cols[c]]
        for c in list(cols):
            if not cols[c]:
                del cols[c]
        dropc = set()
        for a in cl:
            for b in cl:
                if a != b and a not in dropc and b not in dropc and cols[b] >= cols[a] and lits(b) <= lits(a) \
                        and (cols[b] != cols[a] or (lits(b), b) < (lits(a), a)):
                    dropc.add(a)
        if dropc:
            for c in dropc:
                for r in cols[c]:
                    rows[r].discard(c)
                del cols[c]
            changed = True
            if log is not None:
                log.append("column dominance removed %d columns" % len(dropc))
    return chosen, rows, cols


def exact_cover(rows: dict, cols: dict):
    """Minimum-literal cover of the remaining table by branch and bound
    (cost = (#cubes, #literals))."""
    best = [None, (10 ** 9, 10 ** 9)]

    def rec(rows, chosen, cost):
        if not rows:
            if cost < best[1]:
                best[0], best[1] = list(chosen), cost
            return
        # lower bound: one more cube at least
        if (cost[0] + 1, cost[1]) >= best[1]:
            return
        r = min(rows, key=lambda k: len(rows[k]))          # most constrained row
        for c in sorted(rows[r], key=lambda c: (lits(c), c)):
            covered = {rr for rr, cs in rows.items() if c in cs}
            nrows = {rr: cs for rr, cs in rows.items() if rr not in covered}
            rec(nrows, chosen + [c], (cost[0] + 1, cost[1] + lits(c)))
    rec(rows, [], (0, 0))
    return best[0] or [], best[1]


@lru_cache(maxsize=None)
def minimise(on: frozenset, dc: frozenset, nv: int):
    """Exact minimum SOP (cubes, literals) for one function."""
    if not on:
        return (), 0
    if len(on | dc) == 2 ** nv:
        return ("-" * nv,), 0
    pis = primes(on, dc, nv)
    cols = {p: set(cube_minterms(p) & on) for p in pis}
    rows = {m: {p for p in pis if m in cols[p]} for m in on}
    chosen, rrows, rcols = reduce_table(rows, cols)
    rest, _ = exact_cover(rrows, rcols)
    cover = tuple(sorted(chosen + rest))
    return cover, sum(lits(c) for c in cover)
