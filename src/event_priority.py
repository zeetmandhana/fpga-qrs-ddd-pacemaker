"""
event_priority.py  --  P17 Phase 6: the event-priority / timer-expiry logic block

This is the COMBINATIONAL decision core extracted from src/pacemaker.py (it does
NOT re-implement the whole pacemaker). Each tick the controller reduces its
timers to a handful of Boolean predicates and arbitrates the four device events
by a fixed priority (VS > VP > AS > AP). That arbitration is a pure Boolean
function -- a dedicated block suitable for two-level (ESPRESSO) minimisation and
for a BDD representation.

Inputs (8 Boolean signals):
    p = phase is AVI   (0 = AEI, awaiting atrial event; 1 = AVI, awaiting ventricle)
    a = a_in           (intrinsic atrial depolarisation this tick)
    v = v_in           (intrinsic ventricular depolarisation this tick)
    r = (t_v >= VRP)   ventricular refractory elapsed  -> V-sensing allowed
    m = (t_av >= AVI)  AV interval elapsed
    u = (t_v >= URI)   upper-rate interval satisfied
    e = (t_v >= AEI)   atrial escape interval elapsed
    b = (t_v <  PVARP) inside PVARP -> atrial sensing blanked

Outputs (4 device events):
    VS = v & r
    VP = ~VS & p & m & u
    AS = ~VS & ~VP & ~p & a & ~b
    AP = ~VS & ~VP & ~p & ~(a & ~b) & e

NOTE on the tooling (as the assignment distinguishes):
  * ESPRESSO minimises two-level (PLA / sum-of-products) logic -> we emit the
    PLA and compute a minimised SOP.
  * a BDD is a canonical decision-diagram *representation* of the function ->
    we build a reduced ordered BDD and report its node count.
  These are different things; both are produced here from the same block.
"""

from __future__ import annotations

from itertools import product

VARS = ["p", "a", "v", "r", "m", "u", "e", "b"]
VAR_DESC = {
    "p": "phase==AVI", "a": "a_in", "v": "v_in",
    "r": "t_v>=VRP", "m": "t_av>=AVI", "u": "t_v>=URI",
    "e": "t_v>=AEI", "b": "t_v<PVARP (blanked)",
}
OUTPUTS = ["VS", "VP", "AS", "AP"]
N = len(VARS)


def decide(p, a, v, r, m, u, e, b):
    """The event-priority / timer-expiry arbiter (the dedicated block)."""
    vs = v & r
    vp = (not vs) and p and m and u
    as_ = (not vs) and (not vp) and (not p) and a and (not b)
    ap = (not vs) and (not vp) and (not p) and (not (a and (not b))) and e
    return (int(vs), int(vp), int(as_), int(ap))


def assignment(idx: int):
    """Integer 0..255 -> tuple of 8 input bits (p is the MSB)."""
    return tuple((idx >> (N - 1 - i)) & 1 for i in range(N))


def truth_table():
    rows = []
    for idx in range(1 << N):
        bits = assignment(idx)
        rows.append((bits, decide(*bits)))
    return rows


def minterms(out_idx: int):
    return {idx for idx in range(1 << N)
            if decide(*assignment(idx))[out_idx] == 1}


# ---------------------------------------------------------------------------
# Quine-McCluskey two-level minimisation (ESPRESSO-equivalent, exact PIs)
# ---------------------------------------------------------------------------

def _cube_covers(cube: str):
    """All minterm integers covered by a cube string of {'0','1','-'}."""
    choices = [("0", "1") if c == "-" else (c,) for c in cube]
    out = []
    for combo in product(*choices):
        out.append(int("".join(combo), 2))
    return set(out)


def _combine(a: str, b: str):
    diff, pos = 0, -1
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            diff += 1
            pos = i
            if diff > 1:
                return None
    if diff == 1 and a[pos] != "-" and b[pos] != "-":
        return a[:pos] + "-" + a[pos + 1:]
    return None


def prime_implicants(minterm_set):
    terms = {format(m, f"0{N}b") for m in minterm_set}
    primes = set()
    while terms:
        used = set()
        nxt = set()
        tl = list(terms)
        for i in range(len(tl)):
            for j in range(i + 1, len(tl)):
                c = _combine(tl[i], tl[j])
                if c is not None:
                    nxt.add(c)
                    used.add(tl[i])
                    used.add(tl[j])
        primes |= (terms - used)
        terms = nxt
    return primes


def minimise(minterm_set):
    """Return a minimal-ish SOP cover (list of cube strings)."""
    if not minterm_set:
        return []                                  # constant 0
    if len(minterm_set) == (1 << N):
        return ["-" * N]                           # constant 1
    primes = list(prime_implicants(minterm_set))
    cov = {p: _cube_covers(p) & minterm_set for p in primes}
    remaining = set(minterm_set)
    chosen = []
    while remaining:
        essentials = set()
        for mt in remaining:
            owners = [p for p in primes if mt in cov[p]]
            if len(owners) == 1:
                essentials.add(owners[0])
        if essentials:
            for p in essentials:
                if p not in chosen:
                    chosen.append(p)
                    remaining -= cov[p]
        else:
            best = max(primes, key=lambda p: len(cov[p] & remaining))
            if not (cov[best] & remaining):
                break
            chosen.append(best)
            remaining -= cov[best]
    return chosen


def cube_to_str(cube: str) -> str:
    lits = []
    for c, name in zip(cube, VARS):
        if c == "1":
            lits.append(name)
        elif c == "0":
            lits.append("~" + name)
    return "&".join(lits) if lits else "1"


def sop_to_str(cubes) -> str:
    if not cubes:
        return "0"
    return " | ".join(cube_to_str(c) for c in cubes)


def literal_count(cubes) -> int:
    return sum(1 for c in cubes for ch in c if ch in "01")


# ---------------------------------------------------------------------------
# PLA (ESPRESSO input format) emission
# ---------------------------------------------------------------------------

def to_pla() -> str:
    lines = [f".i {N}", f".o {len(OUTPUTS)}",
             ".ilb " + " ".join(VARS), ".ob " + " ".join(OUTPUTS)]
    for idx in range(1 << N):
        bits = assignment(idx)
        outs = decide(*bits)
        if any(outs):                              # omit all-zero rows
            lines.append("".join(str(x) for x in bits) + " " +
                         "".join(str(o) for o in outs))
    lines.append(".e")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Reduced Ordered BDD (a representation, distinct from ESPRESSO)
# ---------------------------------------------------------------------------

class ROBDD:
    def __init__(self):
        # node 0/1 are the terminals; internal nodes are (var_idx, low, high)
        self.nodes = {0: ("T", 0), 1: ("T", 1)}
        self.unique = {}
        self._next = 2

    def mk(self, var, low, high):
        if low == high:
            return low
        key = (var, low, high)
        if key in self.unique:
            return self.unique[key]
        nid = self._next
        self._next += 1
        self.nodes[nid] = (var, low, high)
        self.unique[key] = nid
        return nid

    def build(self, truth_vec, var_idx=0, memo=None):
        if memo is None:
            memo = {}
        if var_idx == N:
            return int(truth_vec[0])
        if all(x == truth_vec[0] for x in truth_vec):
            return int(truth_vec[0])
        key = (var_idx, truth_vec)
        if key in memo:
            return memo[key]
        half = len(truth_vec) // 2
        low = self.build(truth_vec[:half], var_idx + 1, memo)   # var = 0
        high = self.build(truth_vec[half:], var_idx + 1, memo)  # var = 1
        node = self.mk(var_idx, low, high)
        memo[key] = node
        return node

    def reachable(self, roots):
        seen, stack = set(), list(roots)
        while stack:
            nid = stack.pop()
            if nid in seen:
                continue
            seen.add(nid)
            kind = self.nodes[nid][0]
            if kind != "T":
                _, lo, hi = self.nodes[nid]
                stack += [lo, hi]
        return seen

    def eval(self, root, bits):
        nid = root
        while self.nodes[nid][0] != "T":
            var, lo, hi = self.nodes[nid]
            nid = hi if bits[var] else lo
        return self.nodes[nid][1]

    def to_dot(self, roots_named):
        out = ["digraph BDD {", "  rankdir=TB;", '  node [shape=circle];',
               '  t0 [shape=box,label="0"]; t1 [shape=box,label="1"];']
        internal = self.reachable(roots_named.values()) - {0, 1}
        for nid in sorted(internal):
            var, lo, hi = self.nodes[nid]
            out.append(f'  n{nid} [label="{VARS[var]}"];')
            lot = "t0" if lo == 0 else ("t1" if lo == 1 else f"n{lo}")
            hit = "t0" if hi == 0 else ("t1" if hi == 1 else f"n{hi}")
            out.append(f'  n{nid} -> {lot} [style=dashed];')
            out.append(f'  n{nid} -> {hit} [style=solid];')
        for name, root in roots_named.items():
            rt = "t0" if root == 0 else ("t1" if root == 1 else f"n{root}")
            out.append(f'  {name} [shape=plaintext]; {name} -> {rt};')
        out.append("}")
        return "\n".join(out) + "\n"


def build_bdd():
    """Build one shared ROBDD for the 4 outputs; return (bdd, roots, stats)."""
    bdd = ROBDD()
    roots = {}
    for oi, name in enumerate(OUTPUTS):
        tv = tuple(decide(*assignment(idx))[oi] for idx in range(1 << N))
        roots[name] = bdd.build(tv)
    shared = len(bdd.reachable(roots.values()) - {0, 1})
    per = {}
    for name, root in roots.items():
        per[name] = len(bdd.reachable([root]) - {0, 1})
    return bdd, roots, {"shared_internal_nodes": shared, "per_output": per}
