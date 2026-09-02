# Continuous, Change-Impact-Driven Certification for an Evolving P9 System

## Frontier research note for Glassvow

**Date:** 2 September 2026  
**Review type:** targeted methodological note  
**Scope:** evidence reuse and recertification after new cards, relics, balance values, encounters or expansions  
**Status:** research synthesis; it does not itself change the release bar

## Abstract

The two P9 literature reviews address the principal scientific questions of the current programme: how to represent and synthesise a genuinely new strategy subsystem, and how to discover and confirm a diverse repertoire under stochastic simulation. They do not fully answer a lifecycle question that becomes dominant after the first successful certification: when content changes, which P9 claims remain valid and which must be re-established?

This note reviews regression-test selection, change-impact analysis for assurance cases, model-based continuous assurance, metamorphic testing, combinatorial interaction testing and time-uniform sequential inference. The literature supports a claim-dependency approach rather than the two extremes of carrying all evidence silently or rerunning the complete P9 programme for every edit. The proposed Glassvow synthesis is a versioned P9 assurance graph whose nodes are scientific claims and whose edges bind those claims to detector, descriptor, package, policy, context, simulator and content identities. A deterministic change classifier invalidates only the reachable claims, while metamorphic relations, constrained interaction coverage and statistically valid sequential evidence provide the cheapest decisive revalidation. Unknown dependencies fail closed and escalate to a broader tier.

This is a methodological transfer from software and safety assurance, not a claim that a commercial game is safety-critical. The transferable principle is disciplined evidence maintenance under change.

## 1. The lifecycle problem

A successful initial P9 campaign is expensive because it must establish the representation, causal packages, detector, behavioural descriptors, stochastic confirmation and endpoint retention. Repeating that complete sequence after every balance scalar or newly authored card would be scientifically unnecessary where the change cannot affect most claims. Carrying the previous result without an explicit impact argument would be equally weak: even a local content edit can alter reward exposure, package reachability, policy behaviour or context interactions.

The decision problem is therefore:

> How can P9 evidence be reused after a change without either silently assuming invariance or paying for a programme-wide rerun when only a bounded claim set can have changed?

The answer requires a model of evidence dependencies, not merely a list of test commands.

## 2. Regression-test selection: select by affected behaviour

Rothermel and Harrold (1997) define regression-test selection as choosing from an existing suite the tests necessary to validate modified software. Their influential technique analyses the changed program and selects tests whose exercised behaviour may be affected. The important concept for P9 is **safety of selection**: a reduced suite is defensible only relative to an explicit dependency model and fault-revealing criterion. A smaller suite chosen because it is convenient is not safe selection.

P9 can transfer this principle at the claim level. A content delta should be mapped to the scientific claims it can affect. For example, changing one admitted package's payoff value may invalidate its viability, RandomBuild movement, Vow-5 and endpoint-retention evidence, but it does not necessarily invalidate the canonical equivalence proof for an unrelated package. By contrast, changing the simulator oracle or behavioural descriptor invalidates every result that depends on that authority.

The limitation is equally important. Classical regression-test selection reasons about executions and code changes; P9 includes statistical and causal claims. The dependency graph must therefore contain semantic and evidence identities, not only source-file paths.

## 3. Assurance-case maintenance and continuous assurance

Jaradat, Graydon and Bate (2014) address the maintenance of safety-case evidence after system change. They note that evidence can be invalidated by changes to design, operation or environmental context, and that the impact may not be obvious. Their method highlights evidence affected by changed assumptions and artefacts.

Wei *et al.* (2024) extend the lifecycle view through ACCESS, a model-based assurance-case-centred engineering methodology. ACCESS connects assurance claims to heterogeneous engineering artefacts and supports automated evaluation as those artefacts evolve. The relevant transfer is not the safety domain itself; it is the architecture:

1. state claims explicitly;
2. bind each claim to the exact artefacts, assumptions and evidence that justify it;
3. version those dependencies;
4. recompute affected argument nodes after change; and
5. retain unaffected evidence only through an explicit trace.

For Glassvow, the P9 receipt should therefore be the output of a machine-readable claim-evidence graph rather than a flat statement that a large exam once passed. At minimum the graph should bind:

- the P9 acceptance version;
- detector implementation and thresholds;
- descriptor/canonicalisation version;
- admitted package definitions;
- product and simulator identities;
- policy grammar and competent/random policies;
- context distribution and vows;
- reward/economy/content identities;
- seed and cohort identities; and
- raw and derived evidence hashes.

This makes evidence expiry explainable. A change does not “keep P9 green” because a human thinks it is small; it keeps specified claim nodes green because their dependencies are unchanged and the required relations still pass.

## 4. Metamorphic testing: check invariants when a direct oracle is costly

Metamorphic testing was introduced by Chen, Cheung and Yiu (1998/2020) for situations in which a conventional test oracle is unavailable or impractical. Instead of judging one output in isolation, it checks necessary relations between executions under controlled input transformations.

P9 has several useful metamorphic relations:

- renaming or reordering content dictionaries must not change seeded behaviour;
- absent/identity configuration must preserve the exact legacy path;
- a Dusk-only mediator must be exact-null on Ashwarden and when disabled;
- adding non-semantic telemetry must not change gameplay outcomes or RNG identity;
- two implementations claimed to encode the same observable topology must reduce to the same canonical behaviour;
- a replay with the same complete identity must be byte- or event-equivalent under the frozen determinism contract; and
- a change classified as unrelated to a package must not move that package's direct activation or guardrail controls beyond a preregistered tolerance.

Metamorphic evidence is especially valuable for low-cost `D1` and `D2` changes. It cannot establish package viability or strategic plurality by itself. A relation failure is a strong escalation trigger; a relation pass justifies carrying only the claims that the relation actually covers.

## 5. Combinatorial and sequence coverage for new content

Kuhn, Kacker and Lei (2010) describe t-way combinatorial testing: instead of exhausting every configuration, construct a covering array so every interaction of up to a declared strength is exercised. Kuhn *et al.* (2012) extend the approach to event sequences, ensuring selected events occur in every relevant t-way order.

This is directly useful when a new card, relic or expansion adds factors across:

- aspect and vow;
- package and competing package;
- acquisition channel;
- reward/route context;
- policy competence and build mode;
- encounter/intent class; and
- producer/mediator/consumer event order.

A constrained covering array can provide a cheap impact screen before full-run evidence. The strength must follow measured interaction order and risk; it must not be chosen post hoc to obtain a pass. High-order or known causal interactions are included explicitly even when a lower general strength is used.

Combinatorial coverage is not P9 acceptance. It is an efficient method for detecting whether the change creates an interaction that invalidates a carried claim. A detected movement expands the exact causal/full-fidelity panel. Unknown or unmodelled factors fail closed rather than being treated as covered.

## 6. Sequential inference without invalid repeated peeking

Future content development may add rows progressively as uncertainty remains. Ordinary fixed-horizon confidence intervals become invalid when repeatedly inspected and stopped adaptively. Howard *et al.* (2021) develop time-uniform confidence sequences that maintain coverage over time under stated conditions, allowing evidence to be monitored at arbitrary stopping times.

For P9, confidence sequences can support a bounded sequential rule such as:

- stop early when an affected-package regression is decisively outside tolerance;
- stop when a required effect is decisively above the admission boundary;
- continue only while the interval overlaps a decision threshold; and
- preserve a declared family-wise error budget across the affected claims.

They do not authorise reusing a repeatedly exposed final holdout, changing the estimand after outcomes, or carrying evidence across semantic versions. Each content delta still requires a frozen question, dependency set, cohort policy and stopping contract. Protected final acceptance identities remain untouched until the authorised exact-SHA boundary.

## 7. Proposed P9 lifecycle architecture

The literature supports a five-part lifecycle mechanism.

### 7.1 Versioned claim-evidence graph

Represent each P9 claim as a node with exact dependencies and evidence. Examples include:

- package formal distinctness;
- causal activation;
- acquisition reachability;
- competent-policy exploitability;
- RandomBuild separation;
- Vow-5 ceiling;
- descriptor reproducibility;
- detector directional/rank performance; and
- endpoint retention.

The graph is content-addressed. A receipt names the exact graph version and every evidence leaf.

### 7.2 Deterministic impact classifier

Classify each change by semantic surface, not file count. The operational classes are:

- `D0` no gameplay/selection effect;
- `D1` semantics-preserving implementation, telemetry or harness;
- `D2` local parameter/acquisition change inside an admitted package;
- `D3` new card/relic/effect in the admitted grammar;
- `D4` expansion/context/economy/policy-support change; and
- `D5` detector, descriptor, simulator oracle, RNG/save/ID or primary-system change.

The classifier outputs affected graph nodes and the minimum gate. Ambiguous or unknown inputs escalate one level.

### 7.3 Metamorphic and deterministic preflight

Before simulator rows, test identity, null behaviour, canonical equivalence, content order invariance, replay determinism and observation integrity. Any failure invalidates the associated evidence and blocks statistical interpretation.

### 7.4 Constrained interaction screen

For `D2`–`D4`, generate the smallest covering set across affected factors and event order. Use CRN where comparative estimands permit it. Escalate only observed or predeclared high-risk interactions to causal/full-run panels.

### 7.5 Delta confirmation and receipt

Re-estimate only invalidated claims with a frozen sequential or fixed design. Recompute corrected descriptor membership where relevant. Record carried evidence, invalidated evidence, fresh identities, results and whether a full-P9 trigger was crossed.

## 8. What must always trigger broad revalidation

A complete or near-complete P9 rerun is required when a change alters:

- the detector objective, implementation or thresholds;
- descriptor features, canonicalisation or package identity;
- simulator/gameplay oracle semantics;
- deterministic RNG/replay identity;
- policy grammar or the definition of competent/random play;
- context/vow distribution used by acceptance;
- reward/economy rules broadly enough to change every package's reachability; or
- a primary subsystem on which multiple package claims depend.

A local edit also escalates when its delta screen detects unexpected global movement, descriptor drift, a new interaction, an unknown dependency or a hard guardrail breach.

## 9. Limits

No reviewed method proves that a selected regression suite is sufficient without a correct dependency model. No covering array guarantees detection of interactions above its declared strength. Metamorphic testing is only as sound as its relations. Confidence sequences require their own probabilistic assumptions and cannot repair adaptive changes to the scientific question. Model-based assurance can become ceremony if the graph is not executable and content-addressed.

Accordingly, Glassvow should implement the smallest deterministic graph/classifier that changes real decisions. It should not build a general certification platform, safety-case editor or statistical framework before the initial P9 detector and package registry establish the concrete claim vocabulary.

## 10. Conclusion

The lifecycle literature confirms the user's concern: rerunning an open-ended P9 research campaign for each future card or expansion is avoidable, but only after the initial programme produces reusable claim and identity boundaries. The proper replacement is not a permanently green detector. It is a continuously maintained, versioned evidence argument in which every content change receives a deterministic impact classification, unaffected claims carry through explicit dependencies, affected claims receive the smallest decisive gate, and uncertainty or unknown coupling escalates fail-closed.

This preserves the spirit of P9 while changing its economics. The first certification remains demanding; subsequent changes pay in proportion to the claims they can actually invalidate.

## References

Chen, T.Y., Cheung, S.C. and Yiu, S.M. (1998) *Metamorphic testing: a new approach for generating next test cases*. Technical Report HKUST-CS98-01. Hong Kong: Hong Kong University of Science and Technology. Accessible reprint: arXiv:2002.12543.

Howard, S.R., Ramdas, A., McAuliffe, J. and Sekhon, J. (2021) ‘Time-uniform, nonparametric, nonasymptotic confidence sequences’, *The Annals of Statistics*, 49(2), pp. 1055–1080. https://doi.org/10.1214/20-AOS1991.

Jaradat, O., Graydon, P. and Bate, I. (2014) ‘An approach to maintaining safety case evidence after a system change’, in *Proceedings of the 10th European Dependable Computing Conference*. IEEE. Available at: https://arxiv.org/abs/1404.6846.

Kuhn, D.R., Kacker, R.N. and Lei, Y. (2010) *Practical combinatorial testing*. NIST Special Publication 800-142. Gaithersburg, MD: National Institute of Standards and Technology. https://doi.org/10.6028/NIST.SP.800-142.

Kuhn, D.R., Higdon, J.M., Lawrence, J.F., Kacker, R.N. and Lei, Y. (2012) ‘Combinatorial methods for event sequence testing’, in *2012 IEEE Fifth International Conference on Software Testing, Verification and Validation*. IEEE, pp. 601–609. https://doi.org/10.1109/ICST.2012.147.

Rothermel, G. and Harrold, M.J. (1997) ‘A safe, efficient regression test selection technique’, *ACM Transactions on Software Engineering and Methodology*, 6(2), pp. 173–210. https://doi.org/10.1145/248233.248262.

Wei, R., Foster, S., Mei, H., Yan, F., Yang, R., Habli, I., O’Halloran, C., Tudor, N., Kelly, T. and Nemouchi, Y. (2024) ‘ACCESS: Assurance Case Centric Engineering of Safety-critical Systems’, *Journal of Systems and Software*, 213, 112034. https://doi.org/10.1016/j.jss.2024.112034.
