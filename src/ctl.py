"""
ctl.py  --  P17 Phase 5: a small explicit-state CTL model checker

A self-contained Computation-Tree-Logic model checker over a finite Kripke
structure, used to formally verify the DDD pacemaker model (pacemaker_model.py).
Semantics are the standard fixpoint characterisations:

    EX f       = states with some successor in f
    E[f U g]   = least fixpoint  (g OR (f AND EX .))      -- "f until g"
    EG f       = greatest fixpoint (f AND EX .)           -- "f forever"
    EF f       = E[true U f]                              -- "f possibly"
    AX/AF/AG/AU = duals via negation

A formula HOLDS on the model iff every initial state satisfies it. For a failed
property the checker returns a concrete counterexample: a finite path for a
safety violation (AG f), or a lasso (path + cycle) for a liveness violation
(AG AF g). This is explicit-state (not BDD-symbolic like nuXmv) but gives the
same sound results on a finite model.
"""

from __future__ import annotations

from collections import deque


# --- formula constructors (formulas are nested tuples) ----------------------
def AP(name):  return ("ap", name)        # atomic proposition
def NOT(f):    return ("not", f)
def AND(f, g): return ("and", f, g)
def OR(f, g):  return ("or", f, g)
def IMP(f, g): return ("or", ("not", f), g)
def EX(f):     return ("EX", f)
def EF(f):     return ("EF", f)
def EG(f):     return ("EG", f)
def EU(f, g):  return ("EU", f, g)
def AX(f):     return ("AX", f)
def AF(f):     return ("AF", f)
def AG(f):     return ("AG", f)
def AU(f, g):  return ("AU", f, g)
TRUE = ("true",)
FALSE = ("false",)


class Kripke:
    """A finite Kripke structure: states, a TOTAL transition relation, labels."""

    def __init__(self, trans: dict, labels: dict, initial: set):
        self.states = set(trans.keys())
        self.trans = {s: set(succ) for s, succ in trans.items()}
        self.labels = {s: set(labels.get(s, ())) for s in self.states}
        self.initial = set(initial)
        # every state must have at least one successor (paths are infinite)
        for s, succ in self.trans.items():
            if not succ:
                raise ValueError(f"state {s} has no successor (not total)")
        # precompute predecessors for fast pre-image
        self.pred = {s: set() for s in self.states}
        for s, succ in self.trans.items():
            for t in succ:
                self.pred.setdefault(t, set()).add(s)

    def preimage(self, target: set) -> set:
        """{ s : some successor of s is in target }."""
        out = set()
        for t in target:
            out |= self.pred.get(t, set())
        return out

    # --- satisfaction set of a CTL formula ---
    def sat(self, f) -> set:
        kind = f[0]
        if kind == "true":
            return set(self.states)
        if kind == "false":
            return set()
        if kind == "ap":
            name = f[1]
            return {s for s in self.states if name in self.labels[s]}
        if kind == "not":
            return self.states - self.sat(f[1])
        if kind == "and":
            return self.sat(f[1]) & self.sat(f[2])
        if kind == "or":
            return self.sat(f[1]) | self.sat(f[2])
        if kind == "EX":
            return self.preimage(self.sat(f[1]))
        if kind == "EF":
            return self.sat(("EU", TRUE, f[1]))
        if kind == "EU":
            a, b = self.sat(f[1]), self.sat(f[2])
            z = set(b)
            while True:
                nxt = z | (a & self.preimage(z))
                if nxt == z:
                    return z
                z = nxt
        if kind == "EG":
            a = self.sat(f[1])
            z = set(a)
            while True:
                nxt = a & self.preimage(z)
                if nxt == z:
                    return z
                z = nxt
        if kind == "AX":
            return self.sat(("not", ("EX", ("not", f[1]))))
        if kind == "AF":
            return self.sat(("not", ("EG", ("not", f[1]))))
        if kind == "AG":
            return self.sat(("not", ("EF", ("not", f[1]))))
        if kind == "AU":
            # A[f U g] = !(E[!g U (!f & !g)] | EG !g)
            nf, ng = ("not", f[1]), ("not", f[2])
            return self.sat(("not", ("or", ("EU", ng, ("and", nf, ng)),
                                     ("EG", ng))))
        raise ValueError(f"unknown formula {f!r}")

    def holds(self, f) -> bool:
        """True iff every initial state satisfies f."""
        return self.initial <= self.sat(f)

    def violating_initials(self, f) -> set:
        return self.initial - self.sat(f)

    # --- counterexamples ---
    def _bfs_path(self, starts: set, target: set):
        """Shortest path (list of states) from any start to any target state."""
        seen = {s: None for s in starts}
        q = deque(s for s in starts if s in target)
        # if a start is already a target, trivial path
        for s in starts:
            if s in target:
                return [s]
        q = deque(starts)
        while q:
            s = q.popleft()
            for t in self.trans[s]:
                if t not in seen:
                    seen[t] = s
                    if t in target:
                        path = [t]
                        while seen[path[-1]] is not None:
                            path.append(seen[path[-1]])
                        return list(reversed(path))
                    q.append(t)
        return None

    def safety_counterexample(self, f):
        """For AG(f): a finite path to a state violating f, or None if it holds."""
        bad = self.states - self.sat(f)
        if not (self.initial & self.sat(("EF", ("not", f)))):
            return None
        return self._bfs_path(self.initial, bad)

    def liveness_counterexample(self, g):
        """For AG AF(g): a (prefix, cycle) lasso with g false forever, or None."""
        keep = self.sat(("EG", ("not", g)))   # states that can avoid g forever
        if not (self.initial & self.sat(("EF", ("EG", ("not", g))))):
            return None
        prefix = self._bfs_path(self.initial, keep)
        # walk inside `keep` until a state repeats -> the cycle
        seq = [prefix[-1]]
        index = {prefix[-1]: 0}
        while True:
            cur = seq[-1]
            nxts = [t for t in sorted(self.trans[cur], key=repr) if t in keep]
            nxt = nxts[0]
            if nxt in index:
                cyc_start = index[nxt]
                cycle = seq[cyc_start:]
                stem = prefix[:-1] + seq[:cyc_start]
                return stem, cycle
            index[nxt] = len(seq)
            seq.append(nxt)
