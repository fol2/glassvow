"""D547-PC1 numerical/accounting reference, not an evidence authenticator.
Synthetic tests only. Does not fetch data, invoke Godot, bind a contract, or
certify a package. Python 3.10+, standard library only.
"""
from dataclasses import dataclass, field
from functools import lru_cache
import math
import unittest


EPOCH = "D547-PC1-20260914"
ALPHA_542 = 0.025
ALPHA_548_RESERVED = 0.025
INTERVAL_SLOTS = 256  # unused slots cannot be recycled or spent on another look
N = 2048
N_MEAS = 256
CAPS = {"preflight": 8192, "development": 8192,
        "confirmation": 40960, "counterfactual": 24576}
CPU_CAP = 64 * 3600
ELAPSED_CAP = 48 * 3600
RAW_CAP = 64 * 2**30


def integer(x, name):
    if type(x) is not int:
        raise ValueError(f"{name}: integer required (bool is not a count)")
    return x


def bernoulli_kl(q, p):
    if not 0 <= q <= 1 or not 0 <= p <= 1:
        raise ValueError("probability outside [0,1]")
    if q == 0:
        return -math.log1p(-p) if p < 1 else math.inf
    if q == 1:
        return -math.log(p) if p > 0 else math.inf
    if p == 0 or p == 1:
        return math.inf
    return q*math.log(q/p)+(1-q)*(math.log1p(-q)-math.log1p(-p))


@lru_cache(maxsize=8192, typed=True)
def interval(k, n):
    """Fixed-sample binary Chernoff/KL interval, not a Wald/CP approximation.

    Valid for IID Bernoulli or simple random sampling without replacement
    from a frozen finite binary population. 256 two-sided intervals share
    0.025 total noncoverage by the union bound. Unknown/biased sampling
    designs are not made valid by calling this numerical function.
    """
    integer(k, "k"); integer(n, "n")
    if n <= 0 or not 0 <= k <= n:
        raise ValueError("require 0 <= k <= n and n > 0")
    q=k/n
    radius=math.log(2*INTERVAL_SLOTS/ALPHA_542)/n
    lo=0.0
    if k > 0:
        left,right=0.0,q
        for _ in range(70):
            mid=(left+right)/2
            if bernoulli_kl(q,mid) > radius: left=mid
            else: right=mid
        lo=left
    hi=1.0
    if k < n:
        left,right=q,1.0
        for _ in range(70):
            mid=(left+right)/2
            if bernoulli_kl(q,mid) > radius: right=mid
            else: left=mid
        hi=right
    return max(0.0,lo-1e-12),min(1.0,hi+1e-12)


def effective_seed(value):
    integer(value, "seed")
    if not -(2**63) <= value < 2**63:
        raise ValueError("seed not representable as signed native int64")
    return value & 0xFFFFFFFF


def paired(gain, loss, n):
    integer(gain, "gain"); integer(loss, "loss"); integer(n, "n")
    if gain < 0 or loss < 0 or gain+loss > n:
        raise ValueError("discordant cells must be disjoint")
    g, ell = interval(gain, n), interval(loss, n)
    return max(-1., g[0]-ell[1]), min(1., g[1]-ell[0])


def balanced_gain(g_on, l_on, g_off, l_off, n=N_MEAS):
    a, b = paired(g_on, l_on, n), paired(g_off, l_off, n)
    return (a[0]+b[0])/2, (a[1]+b[1])/2


def decide(bounds, cutoff, op):
    lo, hi = bounds
    if not all(math.isfinite(x) for x in (lo, hi, cutoff)) or lo > hi:
        raise ValueError("invalid interval/cutoff")
    if op == ">=":
        return "PASS" if lo >= cutoff else "FAIL" if hi < cutoff else "INCONCLUSIVE"
    if op == "<=":
        return "PASS" if hi <= cutoff else "FAIL" if lo > cutoff else "INCONCLUSIVE"
    if op == "<":
        return "PASS" if hi < cutoff else "FAIL" if lo >= cutoff else "INCONCLUSIVE"
    raise ValueError("unsupported comparison")


def registry():
    """204 occupied primitive interval slots; remaining 52 are sealed unused."""
    out = {}
    for rep in ("A", "B"):
        for vow in (0, 5):
            p = f"{rep}/v{vow}"
            for metric in ("B.win", "R_B.gain", "R_B.loss"):
                out[f"{p}/{metric}"] = N
            for k in (1, 2, 3):
                q = f"{p}/K{k}"
                for metric in ("acquire", "enact", "win_enact", "K_R.gain", "K_R.loss"):
                    out[f"{q}/{metric}"] = N
                for metric in ("on.correct", "off.correct", "natural_negative.not_negative",
                               "blind_on.gain", "blind_on.loss", "blind_off.gain", "blind_off.loss"):
                    out[f"{q}/{metric}"] = N_MEAS
            for k, ell in ((1, 2), (1, 3), (2, 3)):
                for metric in ("correct_k", "correct_l", "exclusive_k", "exclusive_l"):
                    out[f"{p}/pair{k}{ell}/{metric}"] = N
    return out


def validate_counts(rows):
    """Structural check only: underlying raw provenance must also be verified."""
    expected, seen = registry(), set()
    for row in rows:
        key, k, n = row["key"], row["successes"], row["n"]
        if key in seen or key not in expected:
            raise ValueError("duplicate or undeclared metric")
        seen.add(key)
        integer(n, "n"); integer(k, "successes")
        if n != expected[key] or not 0 <= k <= n:
            raise ValueError("missing/extended sample or invalid count")
    if seen != set(expected):
        raise ValueError("incomplete final metric registry")


def validate_roots(arms, exposed, protected):
    """One independent root per factual episode, CRN pairing across five arms.
    `exposed` and `protected` must come from a verified source, not an empty
    caller default. A missing history index is an entry blocker.
    """
    if exposed is None or protected is None:
        raise ValueError("missing exposure/protection authority")
    if set(arms) != {"R", "B", "K1", "K2", "K3"}:
        raise ValueError("wrong arm set")
    canonical = None
    for roots in arms.values():
        roots=[effective_seed(x) for x in roots]
        if len(roots) != N or len(set(roots)) != N:
            raise ValueError("incomplete or duplicate roots")
        forbidden={effective_seed(x) for x in set(exposed) | set(protected)}
        if set(roots) & forbidden:
            raise ValueError("exposed/protected root")
        if canonical is None:
            canonical = tuple(roots)
        elif tuple(roots) != canonical:
            raise ValueError("CRN ordering mismatch")


@dataclass
class Ledger:
    """Illustrative event accounting. `bound` is a TRUSTED adapter input,
    NOT a self-asserted boolean supplied in an empirical result document.
    History is retained as unknown; it is never used as spending credit.
    """
    bound: bool = False
    historical_remaining: object = None
    epoch: str = EPOCH
    candidate: str | None = None
    spent: dict = field(default_factory=lambda: {k: 0 for k in CAPS})
    receipts: dict = field(default_factory=dict)
    cpu: float = 0.0
    elapsed: float = 0.0
    raw: int = 0

    def debit(self, event_id, candidate, stage, count, cpu=0., elapsed=0., raw=0):
        integer(count, "count"); integer(raw, "raw")
        if (not self.bound or self.epoch != EPOCH or not event_id or not candidate
                or stage not in CAPS or count <= 0 or raw < 0
                or not all(math.isfinite(x) and x >= 0 for x in (cpu, elapsed))):
            raise ValueError("invalid/unbound spending")
        event = (candidate, stage, count, cpu, elapsed, raw)
        if event_id in self.receipts:
            if self.receipts[event_id] != event:
                raise ValueError("conflicting replay receipt")
            return False  # identical receipt readback is not another invocation
        if self.candidate is not None and candidate != self.candidate:
            raise ValueError("second candidate/renamed retry is not allocated")
        if (self.spent[stage]+count > CAPS[stage] or self.cpu+cpu > CPU_CAP
                or elapsed < self.elapsed or elapsed > ELAPSED_CAP or self.raw+raw > RAW_CAP):
            raise ValueError("finite cap exceeded")
        self.candidate = candidate
        self.spent[stage] += count
        self.cpu += cpu
        self.elapsed = max(self.elapsed, elapsed)
        self.raw += raw
        self.receipts[event_id] = event
        return True

    def credit_from_history(self, amount):
        raise ValueError("no historical credit or top-up in this epoch")


def synthetic_rows():
    return [{"key": key, "successes": n//2, "n": n} for key, n in registry().items()]


class DesignTests(unittest.TestCase):
    def test_registry(self):
        self.assertEqual(len(registry()), 204)
        self.assertEqual(INTERVAL_SLOTS-len(registry()), 52)
        self.assertEqual(sum(CAPS.values()), 81920)
        self.assertEqual(2*2*5*N, CAPS["confirmation"])
        self.assertEqual(2*2*3*N_MEAS*8, CAPS["counterfactual"])
        self.assertEqual(ALPHA_542+ALPHA_548_RESERVED, .05)

    def test_interval_edges(self):
        tail = ALPHA_542/(2*INTERVAL_SLOTS)
        self.assertAlmostEqual(interval(0,256)[1], 1-tail**(1/256), places=10)
        self.assertAlmostEqual(interval(256,256)[0], tail**(1/256), places=10)

    def test_invalid_counts(self):
        interval(1,4)  # typed cache must not make bool/float counts valid
        for k,n in ((-1,5),(6,5),(0,0),(True,4),(1,4.0)):
            with self.subTest(k=k,n=n), self.assertRaises(ValueError): interval(k,n)

    def test_boundaries(self):
        self.assertEqual(decide((.3,.3),.3,">="),"PASS")
        self.assertEqual(decide((.5,.5),.5,"<"),"FAIL")
        self.assertEqual(decide((.1,.2),.15,">="),"INCONCLUSIVE")
        with self.assertRaises(ValueError): decide((math.nan,1),.5,">=")

    def test_viable_noninferiority(self):
        self.assertEqual(decide(paired(205,205,N),-.10,">="),"PASS")
        self.assertEqual(decide(paired(50,600,N),-.10,">="),"FAIL")

    def test_reference(self):
        self.assertEqual(decide(paired(1150,40,N),.35,">="),"PASS")
        self.assertEqual(decide(paired(400,100,N),.35,">="),"FAIL")
        self.assertEqual(decide(interval(512,N),.5,"<"),"PASS")
        self.assertEqual(decide(interval(1300,N),.5,"<"),"FAIL")

    def test_support(self):
        for count,threshold in ((1024,.30),(900,.25),(600,.10)):
            self.assertEqual(decide(interval(count,N),threshold,">="),"PASS")
        self.assertEqual(decide(interval(100,N),.25,">="),"FAIL")

    def test_measurement(self):
        self.assertEqual(decide(interval(250,256),.80,">="),"PASS")
        self.assertEqual(decide(interval(254,256),.90,">="),"PASS")
        self.assertEqual(decide(interval(0,256),.05,"<="),"PASS")
        self.assertEqual(decide(interval(50,256),.05,"<="),"FAIL")
        self.assertEqual(decide(balanced_gain(128,0,128,0),.10,">="),"PASS")
        self.assertNotEqual(decide(balanced_gain(0,0,0,0),.10,">="),"PASS")

    def test_peer_and_all_abstain(self):
        self.assertEqual(decide(interval(1850,N),.75,">="),"PASS")
        self.assertEqual(decide(interval(0,N),.75,">="),"FAIL")
        self.assertEqual(decide(interval(500,N),.10,">="),"PASS")

    def test_discordance_validation(self):
        with self.assertRaises(ValueError): paired(5,6,10)
        with self.assertRaises(ValueError): paired(True,0,10)

    def test_rows(self):
        validate_counts(synthetic_rows())
        for mode in ("missing","duplicate","extended","foreign"):
            rows=synthetic_rows()
            if mode=="missing": rows.pop()
            if mode=="duplicate": rows.append(rows[0].copy())
            if mode=="extended": rows[0]["n"]+=1
            if mode=="foreign": rows[0]["key"]="detector/accuracy"
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate_counts(rows)

    def test_roots(self):
        roots=[1000000+i for i in range(N)]
        arms={a:roots[:] for a in ("R","B","K1","K2","K3")}
        validate_roots(arms,set(),set())
        with self.assertRaises(ValueError): validate_roots(arms,{roots[0]},set())
        with self.assertRaises(ValueError): validate_roots(arms,None,set())
        arms["K1"][0]=arms["K1"][1]
        with self.assertRaises(ValueError): validate_roots(arms,set(),set())

    def test_ledger(self):
        ledger=Ledger(bound=True)
        self.assertIsNone(ledger.historical_remaining)
        self.assertTrue(ledger.debit("a","candidate-x","confirmation",1))
        self.assertFalse(ledger.debit("a","candidate-x","confirmation",1))
        self.assertEqual(ledger.spent["confirmation"],1)
        with self.assertRaises(ValueError): ledger.debit("a","candidate-x","confirmation",2)
        with self.assertRaises(ValueError): ledger.debit("b","candidate-y","confirmation",1)
        with self.assertRaises(ValueError): ledger.credit_from_history(999)
        with self.assertRaises(ValueError): ledger.debit("c","candidate-x","confirmation",40960)
        with self.assertRaises(ValueError): ledger.debit("d","candidate-x","confirmation",1,cpu=CPU_CAP+1)
        with self.assertRaises(ValueError): ledger.debit("e","candidate-x","confirmation",1,elapsed=ELAPSED_CAP+1)
        with self.assertRaises(ValueError): ledger.debit("f","candidate-x","confirmation",1,raw=RAW_CAP+1)
        with self.assertRaises(ValueError): Ledger().debit("z","x","development",1)
        with self.assertRaises(ValueError): Ledger(bound=True).debit("z","x","548",1)

    def test_cumulative_resources(self):
        ledger=Ledger(bound=True)
        ledger.debit("a","candidate-x","preflight",1,elapsed=10,raw=RAW_CAP-1)
        with self.assertRaises(ValueError):
            ledger.debit("b","candidate-x","preflight",1,elapsed=11,raw=2)
        with self.assertRaises(ValueError):
            ledger.debit("c","candidate-x","preflight",1,elapsed=9)
        self.assertEqual(ledger.raw,RAW_CAP-1)

    def test_effective_seed_alias(self):
        self.assertEqual(effective_seed(17),effective_seed(17+2**32))
        self.assertEqual(effective_seed(-1),2**32-1)
        roots=[1000000+i for i in range(N)]
        arms={a:roots[:] for a in ("R","B","K1","K2","K3")}
        arms["K1"][0]=arms["K1"][1]+2**32
        with self.assertRaises(ValueError): validate_roots(arms,set(),set())

    def test_finite_grid_coverage(self):
        # Exact PMF enumeration at fixed p: synthetic design checks, not
        # empirical simulator results or a proof of uniform coverage.
        delta=ALPHA_542/INTERVAL_SLOTS
        for n in (8,32,64):
            bounds=[interval(k,n) for k in range(n+1)]
            for p in (.0001,.01,.1,.25,.5,.75,.9,.99,.9999):
                coverage=sum(math.comb(n,k)*p**k*(1-p)**(n-k)
                             for k,(lo,hi) in enumerate(bounds) if lo <= p <= hi)
                self.assertGreaterEqual(coverage+1e-10,1-delta)
        # Enumerate each binary finite population for selected small frames.
        for population,n in ((16,8),(40,16)):
            bounds=[interval(k,n) for k in range(n+1)]
            for successes in range(population+1):
                coverage=0.0
                for k in range(max(0,n-(population-successes)),min(n,successes)+1):
                    lo,hi=bounds[k]
                    mass=(math.comb(successes,k)*math.comb(population-successes,n-k)
                          /math.comb(population,n))
                    if lo <= successes/population <= hi: coverage+=mass
                self.assertGreaterEqual(coverage+1e-10,1-delta)


if __name__ == "__main__":
    unittest.main(verbosity=2)
