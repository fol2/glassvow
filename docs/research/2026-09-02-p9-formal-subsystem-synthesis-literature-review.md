# From Open-Ended Mechanic Search to Bounded Formal Synthesis

## A structured integrative literature review for Glassvow Issue #421

**Review date:** 2 September 2026  
**Review type:** structured integrative review  
**Decision scope:** representation, bounded synthesis, causal admission and proof-producing failure for P9  
**Relationship:** the companion review, [`2026-09-02-p9-strategy-diversity-literature-review.md`](2026-09-02-p9-strategy-diversity-literature-review.md), covers repertoire discovery and stochastic confirmation. The operational synthesis is [`../balance/p9-strategy-diversity-system.md`](../balance/p9-strategy-diversity-system.md).

## Abstract

Glassvow P9 requires at least two functionally distinct, viable and reachable strategy packages for each aspect and gated vow, while preserving RandomBuild separation, aspect identity, the Vow-5 ceiling, determinism and reliability. The immediate difficulty is not merely parameter optimisation. The authorised minimum causal classes and additive forms have reached bounded closure without a programme-wide impossibility result. This review asks how a research programme should determine whether a genuinely different subsystem can be expressed, how it should reject renamed or behaviourally equivalent mechanisms, and how a negative result can become scoped evidence rather than another invitation to brainstorm.

The literature separates search within a representation from changing the representation itself. Computational-creativity and design theory explain that an optimiser cannot discover artefacts excluded by its conceptual space. Automated game-design research demonstrates explicit grammars, constraint solvers and pre-playtesting analysis, but remains dependent on the expressive adequacy of those grammars. Program synthesis, counterexample-guided inductive synthesis and syntax-guided synthesis add specifications, finite candidate languages and verifier-produced counterexamples. Unrealizability methods offer bounded no-solution evidence. Region-based Petri-net synthesis and behavioural minimisation supply tests of state separation, independent event enabling and observable non-equivalence. Causal intervention remains necessary because formal novelty does not establish a functioning strategy, while optimal discrimination and quality-diversity methods belong only after representation and causal admission.

The review proposes **Counterexample-Guided Bounded Formal Subsystem Synthesis (CG-BFSS)** as a Glassvow-specific integration of established methods. It is not claimed as a pre-existing named methodology. Its output is one irreducible candidate, a small rival set for a decisive experiment, or a bounded no-survivor/unrealizability receipt.

## 1. Problem formulation

Automated balancing is often treated as selecting values, simulating play and optimising a response surface. That is appropriate only when the searched representation can express the desired behaviour. Once repeated searches close the legal scalar, card, relic, status, timing or additive-carrier families, more rows or a different optimiser do not answer whether the representation itself is inadequate.

For P9, the target cannot be reduced to a deck label or a high win rate. A candidate must supply a player-visible causal structure that competent policies can intentionally enact, must remain distinguishable from other packages, and must survive independent full-fidelity confirmation. The representation question is therefore:

> Can a finite, source-compatible grammar express a bounded, deterministic subsystem whose observable producer–mediator–consumer law is not equivalent to, or merely composed from, an already closed family?

This is a synthesis and verification question before it is an optimisation question.

## 2. Review method

This is a structured integrative review rather than a statistical meta-analysis. Targeted searches covered computational creativity, C–K design theory, automated game design, answer-set programming, planning-based mechanic generation, program synthesis by sketching, CEGIS, SyGuS, synthesis unrealizability, Petri-net and transition-system synthesis, bisimulation minimisation, sufficient-cause interaction, optimal model discrimination, local optima networks and quality-diversity search.

Original papers, doctoral dissertations and peer-reviewed conference work were prioritised. Sources were included when they supplied a formal distinction, an executable representation, a synthesis or verification method, a causal-validation rule, or a diversity-retention method directly relevant to the staged decision. Game-design heuristics and generic optimisation within a fixed parameter vector were not treated as sufficient evidence for the immediate representation problem.

The literature is heterogeneous and does not contain a direct solution for a long-horizon single-player roguelite deckbuilder. Transfer to Glassvow is therefore identified as synthesis, not as an empirical finding of the cited work.

## 3. Representation is distinct from traversal

Wiggins (2006) characterises computational creativity through a conceptual space, rules that define admissible artefacts, and procedures that traverse that space. The key implication is that search can fail because traversal is poor or because the space excludes the desired artefact. Replacing random search with Bayesian optimisation, evolutionary search or reinforcement learning remains exploratory when the grammar and behavioural semantics are unchanged.

C–K theory makes a related distinction between established knowledge and concepts whose truth status is unresolved (Hatchuel and Weil, 2009). Closed Glassvow families belong in the knowledge space: they are not simply unattractive ideas but bounded negative results. A genuinely new subsystem must begin outside those settled equivalence classes and acquire status through formal and empirical tests.

These theories diagnose the transition but do not themselves supply an executable grammar or stopping rule. Their practical contribution is to prevent the programme from confusing “search harder” with “change what can be represented”.

## 4. Explicit design spaces in automated game design

Automated game-design systems show that mechanics can be represented as machine-manipulable structures. Nelson and Mateas (2007) reason about dynamic micro-game rules. Browne and Maire’s Ludi system evolves complete combinatorial games and evaluates them by self-play (Browne and Maire, 2010). These systems establish that machine generation can reach meaningful rule artefacts, but also demonstrate that every result is conditional on the encoding and evaluation function.

Smith and Mateas (2011) make the design space explicit through answer-set programming. Constraints define acceptable artefacts and a domain-independent solver enumerates satisfying designs. Smith’s dissertation develops this into a practice of mechanising exploratory game design, where examples and failures refine the declared space rather than remaining hidden inside procedural code (Smith, 2012).

Zook and Riedl (2014) combine composable planning actions, a constraint solver and automated planning to generate and test mechanics. Cook, Colton and Raad (2018) use abductive analysis to reject rulesets and infer useful properties before expensive playtesting. Together these works support a zero-row first stage: encode dynamics explicitly, reject structurally invalid candidates symbolically, and reserve simulation for claims that require gameplay outcomes.

Their limitation is decisive. A solver can search only the grammar it receives. It does not automatically prove that the grammar contains an irreducible strategy mechanism, and failure to find one is not automatically a no-solution result.

## 5. Program synthesis and counterexample-guided refinement

Program synthesis seeks an implementation satisfying a semantic specification. Solar-Lezama’s sketching approach separates high-level structure from bounded implementation holes (Solar-Lezama, 2008). CEGIS alternates candidate generation with verification: when a candidate fails, the verifier returns a counterexample that constrains the next synthesis round.

For P9, a typed sketch can contain:

`producer -> player-visible mediator -> controllable decision -> independent consumer -> bounded payoff -> expiry/reset`

while leaving topology, state carrier, enabling condition and lifecycle details as bounded holes. Counterexamples can state that the mediator is unreachable, the consumer is not independently enabled, the player has no meaningful choice, exact-null behaviour fails, or the candidate collapses to an existing family after labels are erased.

The important procedural rule is that a counterexample should eliminate an invalid class, not merely blacklist one named mechanic. This turns negative results into cumulative constraints and is substantially more efficient than restarting ideation after every failed implementation.

Syntax-guided synthesis formalises the division between semantics and candidate language (Alur *et al.*, 2013). The semantic formula states required behaviour; the grammar defines the legal implementations. A P9 grammar can constrain fight-local bounded state, deterministic transitions, aspect scope, player visibility and structural cost. The resulting claim remains appropriately scoped: success or failure applies to the frozen grammar, not to every conceivable game system.

Caulfield *et al.* (2015) show that realizability is decidable for some SyGuS fragments and undecidable in general. This argues for a small typed or finitely enumerable grammar rather than maximal expressiveness. The goal is the smallest language capable of answering the product question with an auditable result.

## 6. Bounded unrealizability and minimum complexity

Synthesis is scientifically incomplete if it can find solutions but cannot explain a bounded absence of solutions. Hu *et al.* (2019) translate a SyGuS grammar into a nondeterministic program and use reachability analysis to prove unrealizability for bounded problems. Their approach can also support minimum-cost claims by showing that every cheaper grammar is unrealizable.

This is directly useful at the current #421 frontier. A `NO_SURVIVOR` result can contain:

- the frozen grammar and aliases;
- required and forbidden traces;
- exact legality and source constraints;
- canonical structural cost order;
- counterexamples or separation witnesses; and
- a deterministic verifier receipt.

A surviving candidate can likewise be accompanied by evidence that lower-complexity alternatives fail. The output is therefore informative on both branches: a smallest legal mechanism or a bounded no-solution statement.

The method must retain an `INCONCLUSIVE` state. General unrealizability is difficult, and CEGIS need not converge on every unrealizable problem. A correction or compute cap cannot be misreported as a universal impossibility. Explicit boundedness is a strength, not an embarrassment.

## 7. Petri-net and transition-system synthesis

Mechanics are temporal interactive systems. Static attributes such as “uses a counter” or “has a card tag” do not determine whether the player experiences a distinct law. Labelled transition systems and bounded Petri nets represent observable states, enabled actions, production and consumption of state, and lifecycle closure.

A minimal mapping is:

- places or markings: player-visible mediator conditions;
- producer transitions: create or move the mediator;
- controllable transitions: player choices;
- consumer transitions: independently enabled by the mediator and context;
- output labels: observable payoff; and
- reset transitions: expiry or fight-local cleanup.

Region theory synthesises Petri nets from required transition behaviour. Two separation properties are especially relevant. The **state separation property** asks whether states that must behave differently can be represented distinctly. The **event/state separation property** asks whether an event that must be disabled in a state can actually be inhibited (Badouel, Bernardinello and Darondeau, 2015). Their failure yields a structural witness: the grammar cannot distinguish a required mediator state or cannot provide an independent consumer law.

Petri-net synthesis is not the only possible implementation. A direct finite-state enumerator, ASP model or SMT/SyGuS formulation may be cheaper for the actual source grammar. Its value is the formal vocabulary for reachability, enabling, boundedness and separation.

## 8. Behavioural equivalence and label erasure

Different code or content names do not imply different behaviour. A candidate may add state, tags or cards yet remain observationally equivalent to a closed mechanism. Bisimulation and partition refinement provide a principled method for minimising transition systems while preserving observable behaviour (Kanellakis and Smolka, 1990; Paige and Tarjan, 1987).

The Glassvow comparison should therefore:

1. erase names, internal IDs and whether a carrier is implemented as a card, relic, status or effect;
2. retain player-visible states, controllable choices, enabling conditions, ordering, payoff and expiry;
3. minimise the resulting transition system; and
4. compare it with the canonical closed-family library.

A candidate fails novelty if it is equivalent to a closed family, if added states disappear under minimisation, or if it decomposes only into a union/sequence of closed components without an independent law. Graph isomorphism alone is insufficient because redundant implementation states can make equivalent systems look different.

Quantitative bisimulation metrics may help rank approximately similar candidates, but the initial novelty gate should remain exact where the finite model permits it. Approximate distance is not a substitute for proving a material product distinction.

## 9. Formal novelty is not causal or strategic validity

A formally distinct topology may still be unreachable, too weak, generically powerful or irrelevant to competent play. Causal intervention must establish the complete chain. A minimal factorial design varies producer, mediator and consumer availability and measures whether the payoff appears only through the full mechanism.

The evidence should show:

- producer relevance to the mediator;
- mediator intervention changing consumer eligibility or consequence;
- consumer removal eliminating the payoff;
- proper subsets failing to reproduce the full effect;
- exact-null behaviour when disabled and on the other aspect; and
- no global power, RandomBuild movement, stalls or duration change masquerading as package value.

A three-way statistical interaction can be a useful screen, but it is not automatically mechanistic interaction. Sufficient-cause work by VanderWeele and Robins (2008) explains why statistical interaction and mechanistic claims require different assumptions. P9 should therefore use intervention structure and manipulation checks, not a regression coefficient alone.

## 10. The smallest decisive experiment

When two or three formal rivals survive, broad landscape simulation is wasteful. Optimal model-discrimination design selects contexts in which rival models make maximally different predictions. Atkinson and Fedorov’s T-optimal design is a classical formulation for discriminating among competing models (Atkinson and Fedorov, 1975).

Applied to P9, each survivor should declare pre-row predictions over legal encounter, intent, deck, mediator and consumer contexts. Deterministic code then selects the smallest CRN-compatible panel that maximises disagreement while preserving the same policies, baseline and stopping rules. A result eliminates a topology or advances one to causal admission.

This gate protects against a common failure mode: spending thousands of whole-run rows before confirming that candidates differ on the mechanism they claim to implement.

## 11. Retention and quality diversity come later

The companion review establishes that quality-diversity methods can maintain a repertoire of locally strong candidates and that uncertain-QD methods are needed when fitness and descriptor membership are noisy. Those methods do not solve a representation failure. MAP-Elites can preserve candidates only in dimensions already defined; a poor descriptor can protect nominally different entries that enact the same strategy.

Local optima networks represent optima and their basins as a graph, providing a way to study whether independent search starts converge to one attractor or remain distributed across distinct endpoints (Ochoa *et al.*, 2014). This is relevant to P9 retention, but only after the package descriptor has formal and causal validity.

The correct order is therefore:

`bounded representation -> equivalence screen -> causal admission -> descriptor validation -> repertoire discovery -> corrected confirmation -> fresh endpoint retention`

not QD first with the hope that search will invent a missing causal law.

## 12. CG-BFSS for Glassvow

The combined literature supports the following bounded protocol.

### Stage 1 — freeze the specification

Declare required and forbidden observable traces, product invariants, structural cost, exact-null conditions, canonicalisation rules and the finite grammar before candidates or rows.

### Stage 2 — deterministic synthesis

Enumerate or solve the legal grammar. Use finite enumeration, ASP, SMT/SyGuS or region synthesis according to the smallest auditable method. No model call occurs per candidate.

### Stage 3 — counterexample closure

For every invalid candidate, emit a root-cause witness and convert it into a grammar constraint or closed equivalence class. Preserve the failed representation and verifier receipt.

### Stage 4 — behavioural quotient

Erase labels and implementation carriers, minimise observable behaviour and reject equivalence, redundant state and decompositions of closed families.

### Stage 5 — survivor control

Return zero to three canonical survivors. Zero produces a bounded no-survivor/unrealizability receipt. More than three means the grammar or ranking is not yet decisive and no simulator budget opens.

### Stage 6 — discriminating direct experiment

For rival survivors, freeze the smallest context panel that separates their predictions. Close losing topologies before full-run evidence.

### Stage 7 — causal admission

Run producer/mediator/consumer controls, exact-null tests, policy-sensitivity witnesses and guardrails. A candidate becomes a strategy package only after these pass.

### Stage 8 — repertoire and confirmation

Use the companion review’s deterministic baseline, conditional QD, corrected untouched archive and statistically controlled selection. Archive occupancy alone is not retention.

### Stage 9 — one promotion boundary

Promote at most one minimum reproducible detector/content packet into a clean current-main branch and run the exact-SHA release protocol.

## 13. Limitations

No cited method guarantees a P9-compliant subsystem in the Glassvow source. Formal models necessarily abstract implementation details, and a wrong abstraction can produce a misleading equivalence or unrealizability result. Petri-net separation may be too restrictive for a mechanic naturally expressed through richer data. SyGuS and CEGIS may be inconclusive. Causal experiments remain simulator-relative, and competent policies may fail to express a mechanism that human players could exploit.

These limitations strengthen, rather than weaken, the staged design. Each claim must retain its scope: formal feasibility, behavioural novelty, causal operation, strategic viability and commercial feel are separate evidence questions.

## 14. Conclusion

The literature does not supply a hidden card or mechanic that solves #421. It supplies a better scientific object and a terminating research structure. The current frontier should not be treated as a request for more unbounded ideation or a more fashionable optimiser. It should be treated as a bounded synthesis problem over required observable behaviour.

CG-BFSS preserves the product spirit while changing the economics of research. It can produce one smallest irreducible candidate, a small rival set for a decisive experiment, or a scoped no-solution result. Every valid failure removes a class rather than consuming another isolated hypothesis, and expensive stochastic search begins only after the representation is shown to be legal, non-equivalent and causally operative.

## References

Alur, R., Bodík, R., Juniwal, G., Martin, M.M.K., Raghothaman, M., Seshia, S.A., Singh, R., Solar-Lezama, A., Torlak, E. and Udupa, A. (2013) ‘Syntax-guided synthesis’, in *2013 Formal Methods in Computer-Aided Design*. IEEE, pp. 1–8.

Atkinson, A.C. and Fedorov, V.V. (1975) ‘The design of experiments for discriminating between two rival models’, *Biometrika*, 62(1), pp. 57–70. https://doi.org/10.1093/biomet/62.1.57.

Badouel, E., Bernardinello, L. and Darondeau, P. (2015) *Petri net synthesis*. Berlin: Springer. https://doi.org/10.1007/978-3-662-47967-4.

Browne, C. and Maire, F. (2010) ‘Evolutionary game design’, *IEEE Transactions on Computational Intelligence and AI in Games*, 2(1), pp. 1–16. https://doi.org/10.1109/TCIAIG.2010.2041928.

Caulfield, B., Rabe, M.N., Seshia, S.A. and Tripakis, S. (2015) ‘What’s decidable about syntax-guided synthesis?’, in *Automated Technology for Verification and Analysis*. Cham: Springer, pp. 134–148. https://doi.org/10.1007/978-3-319-24953-7_10.

Cook, M., Colton, S. and Raad, A. (2018) ‘Inferring design constraints from game ruleset analysis’, in *Proceedings of the IEEE Conference on Computational Intelligence and Games*. IEEE.

Hatchuel, A. and Weil, B. (2009) ‘C-K design theory: an advanced formulation’, *Research in Engineering Design*, 19, pp. 181–192. https://doi.org/10.1007/s00163-008-0043-4.

Hu, Q., Breck, J., Cyphert, J., D’Antoni, L. and Reps, T. (2019) ‘Proving unrealizability for syntax-guided synthesis’, in *Computer Aided Verification*. Cham: Springer, pp. 335–352. https://doi.org/10.1007/978-3-030-25540-4_18.

Kanellakis, P.C. and Smolka, S.A. (1990) ‘CCS expressions, finite state processes, and three problems of equivalence’, *Information and Computation*, 86(1), pp. 43–68. https://doi.org/10.1016/0890-5401(90)90025-D.

Nelson, M.J. and Mateas, M. (2007) ‘Towards automated game design’, in *AI*IDE 2007*. Menlo Park, CA: AAAI Press.

Ochoa, G., Tomassini, M., Vérel, S. and Darabos, C. (2014) ‘A study of NK landscapes’ basins and local optima networks’, in *Proceedings of the Genetic and Evolutionary Computation Conference*. ACM, pp. 555–562.

Paige, R. and Tarjan, R.E. (1987) ‘Three partition refinement algorithms’, *SIAM Journal on Computing*, 16(6), pp. 973–989. https://doi.org/10.1137/0216062.

Smith, A.M. (2012) *Mechanizing exploratory game design*. PhD thesis. University of California, Santa Cruz.

Smith, A.M. and Mateas, M. (2011) ‘Answer set programming for procedural content generation: a design space approach’, *IEEE Transactions on Computational Intelligence and AI in Games*, 3(3), pp. 187–200. https://doi.org/10.1109/TCIAIG.2011.2158545.

Solar-Lezama, A. (2008) *Program synthesis by sketching*. PhD thesis. University of California, Berkeley. Technical Report UCB/EECS-2008-176.

VanderWeele, T.J. and Robins, J.M. (2008) ‘Empirical and counterfactual conditions for sufficient cause interactions’, *Biometrika*, 95(1), pp. 49–61. https://doi.org/10.1093/biomet/asm090.

Wiggins, G.A. (2006) ‘A preliminary framework for description, analysis and comparison of creative systems’, *Knowledge-Based Systems*, 19(7), pp. 449–458. https://doi.org/10.1016/j.knosys.2006.04.009.

Zook, A. and Riedl, M.O. (2014) ‘Automatic game design via mechanic generation’, in *Proceedings of the AAAI Conference on Artificial Intelligence and Interactive Digital Entertainment*, 10(1), pp. 136–142. https://doi.org/10.1609/aiide.v10i1.12735.
