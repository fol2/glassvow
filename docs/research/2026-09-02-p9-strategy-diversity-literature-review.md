# Scientific discovery and validation of strategic diversity in stochastic deckbuilders

## A critical literature review for Glassvow P9

**Review date:** 2 September 2026

**Review type:** structured critical narrative review

**Decision scope:** methodological input to Glassvow P9 and issue #421; this
review does not change P9 acceptance, select a product candidate, or authorise a
new simulation campaign

**Citation convention:** Harvard author–date; published works use the version of
record and DOI where available, while theses, preprints and internal documents
include an access date

**Main-text word count:** 4,661 words, excluding references

**Research value: high —** directly relevant card-game studies establish that
quality-diversity methods can discover repertoires of strong decks, while mature
simulation literature supplies defensible methods for noisy evaluation,
resource allocation and final confirmation. No reviewed work, however, proves
that the same methods will produce the required repertoire in a long-horizon,
single-player roguelite deckbuilder.

## Abstract

Glassvow's P9 release criterion asks for strategic plurality rather than a
single strong policy: planned play must support genuinely different, buildable
winning strategies for both Ashwarden and Duskblade at Vow 0 and Vow 5, without
random deckbuilding becoming equivalent to planned deckbuilding. Existing
Glassvow evidence uses common random numbers, explicit controls, large sampled
landscapes, cross-entropy optimisation and held-out confirmation. It has
successfully suppressed random-build strength and exposed strategy collapse,
but it has not produced the required plurality, particularly for Duskblade.

This review examines quantitative game balance, automated playtesting, player
modelling, evolutionary deckbuilding, quality-diversity optimisation,
stochastic ranking and selection, multi-fidelity search, robust optimisation
and adaptive-data validation. The literature distinguishes three problems that
are easily conflated: defining the desired kind of balance; discovering
candidate strategies; and confirming that discovered strategies are strong,
distinct and reproducible. Single-objective optimisation is well suited to
finding a ceiling but structurally predisposed to converge on one attractor.
Quality-diversity methods instead retain the best candidate in each declared
behavioural niche. Their direct application to Hearthstone is encouraging, but
their validity depends on behavioural descriptors, player-policy fidelity and
noise handling. Simulation-efficient methods such as racing, surrogates and
multi-fidelity optimisation can reduce cost only when their assumptions are
calibrated; none replaces full-fidelity confirmation.

The synthesis recommends a two-loop programme. An adaptive discovery loop
should illuminate a trace-derived behavioural space and maintain multiple
quality-gated candidates. A separate confirmation loop should freeze the
candidate set, use paired seeds and statistically controlled selection, and
evaluate survivors on an untouched full-fidelity holdout. This is a stronger
scientific basis for further P9 work, but it cannot guarantee that the frozen
design space contains a P9-compliant solution.

## 1. Problem definition

Game balance is not a single mathematical property. It can refer to fairness
between players, equality between options, controlled difficulty, the absence
of dominant strategies, meaningful skill expression, or a desirable variety
of experiences. Jaffe (2013) argues that quantitative analysis often fails by
abstracting away the player, and proposes *restricted play*: a balance question
is made concrete by specifying which player behaviours, abilities or strategy
constraints are being evaluated. More recent work similarly treats balance as
player-relative and purpose-specific rather than a universal scalar (Pfau and
El-Nasr, 2024; Shields, 2026).

P9 already supplies a comparatively precise construct. It is not asking for
equal card usage or a globally flat win-rate distribution. It asks whether
multiple strategically different ways of planning a build and playing it
remain viable at two difficulty levels for each aspect. It separately requires
planned construction to outperform random construction and prevents an
overpowered Vow 5 ceiling (Glassvow, 2026a). The reviewed s009 full exam passed that
random-versus-planned separation, but sampled policies occupied only one or two
viable cells per grid, optimisation usually left its seeded non-dominant cell,
and Duskblade remained concentrated around Shatter (Glassvow, 2026b;
Glassvow, 2026c).

The methodological question is therefore:

> How should a bounded autonomous programme discover, distinguish and confirm
> multiple strong strategies in a stochastic, long-horizon deckbuilder without
> mistaking labels, lucky simulations or proxy success for P9 evidence?

This formulation preserves the product requirement. Literature may improve the
search and evidence design, but it cannot lower the number of strategies,
change the Vow levels, redefine a stalled run as a win, or substitute an
academic metric for the signed release criterion.

## 2. Review method

This is a structured critical narrative review, not a systematic review or
meta-analysis. Searches were conducted on 2 September 2026 across publisher
indexes, proceedings libraries, open preprint archives and university thesis
repositories. Broad queries combined terms for *automated game balancing*,
*automated playtesting*, *player modelling*, *deckbuilding*, *strategy
diversity*, *quality diversity*, *MAP-Elites*, *stochastic simulation*,
*ranking and selection*, *common random numbers*, *multi-fidelity optimisation*
and *adaptive holdout*. Targeted searches then followed named methods and
backward citations from the strongest sources.

Sources were included when they contributed at least one of the following:

- a formal account of the balance construct or player-relative evaluation;
- empirical automated balancing or deckbuilding in a card or strategy game;
- a method for discovering several behaviourally different, high-performing
  solutions;
- a method for controlling noise, simulation allocation or selection error; or
- a validity warning directly relevant to adaptive search and confirmation.

Peer-reviewed articles and conference papers were preferred. Doctoral theses
were retained where they supplied substantial synthesis or methods not captured
by a shorter paper. Preprints were used for foundational work or when they were
the accessible primary version. Secondary summaries, commercial claims, forum
posts and unsourced design advice were excluded from substantive conclusions.
Published metadata was checked against DOI or publisher records. Transfer claims
to Glassvow are identified as synthesis rather than reported findings.

The review is comprehensive for the decision at hand but not bibliometrically
exhaustive. It did not run a registered protocol, duplicate-screen a database
export, calculate publication bias, or claim PRISMA compliance. The corpus also
contains far more work on competitive card games, board games, platform games
and robotics than on single-player roguelite deckbuilders. That asymmetry is a
material limitation, not an invitation to infer missing evidence.

## 3. Balance must be defined through players, constraints and outcomes

Jaffe *et al.* (2012) operationalise restricted play by constraining simulated
agents and treating their results against standard agents as design evidence.
The approach is important for P9 because a strategy cannot be established by a
name or card list alone: the build constraints and enacted policy have to be
declared. A nominal Ward strategy that wins by behaving like the dominant
Shatter policy is not an independent strategy under this view.

Automated balancing studies also show why one aggregate outcome is inadequate.
Volz, Rudolph and Naujoks (2016) optimise a card game against several objectives,
including informed-versus-uninformed performance, changes in initiative and
outcome closeness. De Mesentier Silva *et al.* (2019) combine a match-up balance
objective with minimum disruption to the existing card set. These studies do
not define the correct objectives for Glassvow, but they demonstrate that
design intent normally requires several observables and explicit trade-offs.

Ludus is an especially useful warning. Budijono *et al.* (2022) evaluate an
auto-battler through card and line-up win-rate distributions, then optimise
payoff, standard deviation or entropy. The framework can reduce simulation
through sampling and expose influential parameters. However, low variance can
also be achieved by degenerate solutions such as identical cards or universal
draws. The authors further note that average card win rates omit pairwise
match-up structure and that their metrics have not been validated against human
judgements of a healthy metagame. Statistical parity can therefore erase the
very differences a diversity criterion is meant to protect.

Pfau and El-Nasr (2024) reinforce the construct problem at larger scale. Their
analysis joins a 680-participant survey with more than four million Guild Wars 2
fights and finds that player conceptions of balance differ from one another and
from purely data-driven formulations. P9 avoids some of this ambiguity by
predefining its release criterion, but concepts such as "genuinely different"
still require an operational behavioural test. Descriptor choice is therefore
part of measurement validity, not a harmless implementation detail.

## 4. Automated playtesting is powerful but policy-bound

Automated playtesting offers scale, repeatability and access to rare states, but
every result is conditional on the synthetic player's observation space,
policy class and objective. García-Sánchez *et al.* (2016; 2018) use evolutionary
search and game-playing agents to construct Hearthstone decks. Their later work
adds a human-inspired mutation operator and calibrates the playing AI before
using it as an evaluator. Evolved decks outperform selected human reference
decks under that simulator, yet expert review remains necessary and the result
does not establish population-wide human viability. Bhatt *et al.* (2018)
similarly show that deck performance can be opponent-specific and non-transitive:
a candidate strong against its training set may not be generally strong.

Procedural personas address the single-policy problem by representing distinct
player objectives. Holmgård *et al.* (2014) evolve agents for explicit persona
utilities and evaluate playing strength, generalisation and conformity to the
intended style. Holmgård (2015) develops the concept as a broader player
modelling and content-generation programme. Later work evolves persona-specific
Monte Carlo Tree Search heuristics and demonstrates different enacted styles
across a corpus of levels (Holmgård *et al.*, 2019). These methods support the
idea that P9 should test whether a candidate can be played successfully *as its
intended strategy*, rather than only whether its component cards occur.

Fixed personas can still reproduce the designer's assumptions. Ariyurek, Surer
and Betin-Can (2021) find that conventional reinforcement-learning agents tend
to disregard previously explored paths. Their developing personas can change
goals, while their Alternative Path Finder modifies rewards to seek a different
trajectory without abandoning the terminal goal. For Glassvow this suggests a
cheaper principle rather than an immediate requirement to train an RL system:
the discovery policy should retain memory of covered trajectories and receive
search pressure for materially different successful paths.

When sufficient human trace data exist, learned populations can be more
representative than hand-authored personas. Pfau *et al.* (2020) train
individual action models from six months of data from 213 *Aion* players and
test them across 100 enemy configurations using wins, duration and remaining
health on both sides. Glassvow does not currently possess an equivalent human
dataset, so importing the conclusion without the prerequisite data would be
invalid. The transferable point is narrower: a population of imperfect,
style-specific agents reveals different balance boundaries from one optimal
agent.

## 5. Why single-objective search is an incomplete discovery method

An optimiser answers the objective it is given. If the objective is expected
win rate, independent searches can rationally converge on the same high-win
attractor even when the product goal values several strategies. This does not
make cross-entropy optimisation scientifically defective. It makes it a good
ceiling finder and a poor repertoire objective.

Novelty search was introduced to address deceptive objectives by rewarding
behavioural difference rather than proximity to a presumed goal (Lehman and
Stanley, 2011a). It can escape paths on which incremental objective improvement
leads to a dead end, but novelty alone can preserve unusual and ineffective
solutions. Novelty Search with Local Competition adds niche-relative quality,
foreshadowing modern quality-diversity optimisation (Lehman and Stanley,
2011b).

MAP-Elites makes the repertoire explicit. A user defines behavioural measures,
partitions that space into cells, and retains the highest-quality candidate in
each occupied cell (Mouret and Clune, 2015). Its product is an illumination map,
not one champion. Pugh, Soros and Stanley (2016) frame quality-diversity as the
simultaneous pursuit of coverage and local quality, and warn that an unhelpful
behaviour characterisation can impair discovery. The recent field survey by Qin
*et al.* (2026) confirms that containers, selection and variation operators have
all diversified substantially, but the user-defined feature space remains a
central modelling decision.

This distinction maps closely to P9. C1 asks for several viable cells and C3
asks optimised islands to remain strong without all drifting towards the same
destination. A quality-diversity archive would make those local cells part of
the search objective rather than inspecting plurality only after a global
optimiser has run. It would not, by itself, prove that the cells correspond to
genuine strategies.

## 6. Direct card-game evidence for quality-diversity search

Fontaine *et al.* (2019) provide the closest direct precedent. Their MAP-Elites
with Sliding Boundaries method searches Hearthstone decks while retaining strong
solutions across mean and variance of mana cost. The boundaries follow
empirical quantiles rather than fixed-width bins, reducing empty or conflated
regions when feasible behaviours are unevenly distributed. Decks are evaluated
over 200 games, using total hero-health difference as fitness. The study finds
strong decks across the declared space and uses recurring card patterns to
identify possible rebalance targets.

The result is encouraging but narrower than it first appears. Mana-curve
statistics are proxies for play style; gameplay policy is held constant. Moving
the cell boundaries also changes their interpretation over time. A deck that is
compositionally different may still enact the same strategy, while a single
deck may support several policies. P9 therefore needs behavioural measures
derived from play traces as well as, or instead of, deck composition.

Zhang *et al.* (2022) address MAP-Elites' evaluation cost with Deep
Surrogate-Assisted MAP-Elites. An online neural surrogate predicts the objective
and behavioural measures; a cheap inner search proposes an archive, and an outer
loop evaluates its elites through 200 real simulator games each. Those results
update both the training data and a separate ground-truth archive. Online
training outperforms the reported random-offline and linear-surrogate baselines.
Crucially, the published result is the ground-truth archive: surrogate
predictions are search guidance, not final evidence.

Policy-level quality-diversity is also possible. Pérez-Liébana *et al.* (2021)
combine a portfolio of strategy scripts, Monte Carlo Tree Search and MAP-Elites
to generate competitive play styles in a turn-based strategy game, including
tests on unseen levels. This is closer to P9's behavioural claim, although its
coverage is bounded by the supplied script portfolio and descriptors.

Yao *et al.* (2023) provide a broader theoretical warning from non-transitive
games: a population can increase under a chosen policy-diversity metric without
improving its approximation to equilibrium or reducing exploitability. Their
specific equilibrium method is not directly transferable to a single-player
roguelite, but the measurement principle is. Behavioural separation must be
linked to the performance or robustness property the repertoire is meant to
provide. Distance alone is not value.

## 7. Noise can corrupt both quality and strategy identity

In a stochastic deckbuilder, a candidate does not have one fixed fitness or one
fixed descriptor. Draw order, offered rewards, route, encounter sequence and
policy decisions create distributions. A candidate can appear strong through a
lucky seed and can be assigned to the wrong behavioural cell because its trace
features fluctuate.

Canonical elitist MAP-Elites is vulnerable to both errors. Justesen, Risi and
Mouret (2019) introduce adaptive sampling and drifting elites: promising
candidates receive more evaluations, archived elites are re-evaluated, and an
elite can move when its estimated descriptor changes. Flageat and Cully (2020)
instead keep a population within each deep cell, using accumulated neighbours
to improve stability without explicitly resampling every candidate. On their
benchmarks, ordinary single-sample MAP-Elites was badly destabilised by noise,
while deep cells improved corrected coverage and sample efficiency. Neither
method is universally superior; their behaviour depends on noise structure and
budget.

Flageat and Cully (2024) subsequently formalise uncertain quality-diversity and
an evaluation protocol. Final archives are independently re-evaluated to create
a *corrected* archive, after which apparent and corrected QD-score, coverage,
quality loss and descriptor reproducibility can be compared. This is directly
applicable to P9. Discovery cells should remain provisional until repeated
full-fidelity runs establish both performance and cell identity.

Surrogates add another source of uncertainty. Gaier, Asteroth and Mouret (2018)
show that uncertainty-aware surrogate-assisted illumination can reduce expensive
evaluations in engineering design. However, any model can be exploited by the
search outside its reliable region. A P9 surrogate would need prospective
out-of-sample calibration, uncertainty-aware acquisition and a demonstrated
wall-time advantage. The literature does not justify building one before those
conditions are met.

## 8. Efficient simulation requires separate search and selection claims

Simulation optimisation distinguishes *finding* candidates from *selecting*
among a finite set. Boesel, Nelson and Kim (2003) explicitly recommend using
heuristic search to discover alternatives and a statistically controlled
ranking-and-selection procedure to clean up afterwards. The guarantee applies
to the best encountered candidate, not to an unobserved global optimum. That is
an appropriate claim boundary for P9.

Common random numbers (CRN) compare alternatives on matched random inputs. When
candidate outcomes respond positively to the same seed difficulty, pairing can
reduce the variance of their difference. Nelson and Matejcik (1995) show how CRN
can be combined with indifference-zone selection and simultaneous comparisons,
while also showing that validity depends on the induced dependence structure.
CRN is therefore an experimental design that must be preserved and analysed,
not a universal variance-reduction guarantee.

Kim and Nelson (2001) provide a fully sequential procedure for a finite set of
alternatives with unknown and unequal variances. The analyst predeclares a
practically insignificant difference, a confidence level and initial sampling;
inferior alternatives are eliminated as paired evidence accumulates. Under the
stated normal or batch-mean assumptions, the method guarantees a minimum
probability of selecting the best when the true gap exceeds the indifference
threshold. Multiple P9 cells or contrasts additionally require family-wise or
false-discovery control. Malek *et al.* (2017) show how valid time-uniform
sequential p-values can support sequential versions of common multiple-testing
procedures. Repeatedly inspecting ordinary fixed-horizon p-values does not
provide that control.

Racing methods are cheaper but make different claims. Successive Halving gives
many candidates a small resource and progressively concentrates resource on
survivors (Jamieson and Talwalkar, 2016). Hyperband repeats this process across
brackets with different exploration-versus-resource allocations (Li *et al.*,
2018). Their guarantees concern convergent resource-loss sequences under stated
conditions; a small seed batch in a stochastic game is not automatically such a
sequence. Early Dusk results may rank candidates differently from capacity
results. Racing is admissible only after retrospective or prospective evidence
shows that the proposed early fidelity preserves decisions well enough.

Multi-fidelity Bayesian optimisation has the same boundary. Kandasamy *et al.*
(2016) use cheap approximations until uncertainty and bias conditions justify an
expensive target evaluation. The method assumes known fidelity costs and bounds
on disagreement with the target. Pearce, Poloczek and Branke (2022) model seeds
directly and choose between reusing a seed and drawing a new one, but this is an
allocation policy rather than a final acceptance test. These approaches may
reduce discovery cost; neither can promote a candidate on proxy evidence.

Robust optimisation provides a complementary context model. Kirschner *et al.*
(2020) optimise against the worst distribution within a declared ambiguity set
rather than only the empirical mean context. Encounter, draw, reward and policy
mix could be treated as P9 contexts, but the reference distribution and
ambiguity radius are substantive product and measurement choices. They cannot
be tuned after observing which setting favours a candidate, and a robust-regret
result is not an acceptance probability.

Finally, adaptivity threatens the holdout. Dwork *et al.* (2015) demonstrate
that repeated feedback from the same validation data can produce spurious
discoveries. Their reusable-holdout guarantee requires a protected release
mechanism; simply calling repeatedly observed seeds a holdout does not preserve
validity. P9 confirmation should therefore use an untouched seed and context
bank, or explicitly adopt and validate a reusable-holdout protocol.

## 9. What the literature says about the existing P9 protocol

The literature does not invalidate the existing work. Several parts are already
strong and should be retained. The mismatch is between the discovery objective
and the repertoire outcome.

| Existing feature | Literature assessment | Consequence |
|---|---|---|
| Planned/random build and play controls | Strong restricted-play design (Jaffe *et al.*, 2012) | Retain; they separate strategy, construction and execution claims. |
| Common random seeds | Established comparative simulation design (Nelson and Matejcik, 1995) | Retain pairing and analyse differences, not isolated win rates. |
| Training versus held-out CEM results | Correct separation in principle (Boesel, Nelson and Kim, 2003) | Preserve; do not let training fitness enter acceptance. |
| Fixed deck-size and Shatter/Smolder cells | Useful, auditable first descriptors but partly authored proxies | Validate against trace-level distinctness and descriptor reproducibility before treating occupancy as strategic diversity. |
| CEM islands | Appropriate for ceilings and attractor diagnosis | Do not expect unconstrained single-objective islands to maintain several niches. |
| Large full landscape after a cheap Phase A | Scientifically conservative but wall-time expensive | Calibrate sequential elimination or fidelity screening before using it; never assume the cheap gate predicts the full gate. |
| Fail-closed stalls, ceilings and unchanged exams | Strong no-compromise evidence discipline | Retain in final confirmation and count stalls as the contract requires. |

The s009 exam is thus substantive progress: it shows that suppressing random
builds is insufficient to create strategic breadth and that a global optimiser
usually abandons non-dominant cells (Glassvow, 2026c). It is negative evidence
against that candidate and search grammar, not evidence that P9 is impossible.
The prior campaign history can seed descriptor and fidelity calibration, but it
must not be relabelled as new independent data.

## 10. A literature-grounded method for the next P9 programme

The strongest synthesis is a two-loop design with a hard promotion boundary.
It follows Glassvow's existing discovery-versus-delivery model (Glassvow,
2026d), but makes discovery itself repertoire-aware.

### 10.1 Stage 0 — retrospective calibration without new simulation

Use frozen historical rows only to ask three methodological questions:

1. Do proposed trace descriptors assign repeated runs of the same strategy
   consistently while separating known different strategies?
2. Do cheap sample sizes or Phase A scores preserve the decisions reached by
   later capacity/full-landscape evidence?
3. Which sources of context — seed, encounter, reward path, Vow and policy —
   account for material outcome and descriptor variance?

This stage may reject a descriptor or low-fidelity gate. It cannot discover or
accept a new strategy because the data were generated adaptively for earlier
questions.

### 10.2 Stage 1 — freeze the scientific construct

Specify the candidate unit, quality constraints and behavioural measures before
search. A candidate may be content, a build policy, a play policy, or a declared
combination; those objects are not interchangeable. A defensible descriptor set
should be computed from realised traces and kept small enough to support each
cell. Candidate dimensions include damage timing, resource generation and
spend, Ward conversion, target distribution, cycle intensity, survival cost and
acquisition route. These are hypotheses for calibration, not predetermined P9
strategies.

Quality should include more than mean win rate: opportunity/reachability,
conditional completion, stalls, resource or health margin, Vow robustness and
performance across declared contexts. The P9 control and ceiling conditions
remain hard constraints rather than terms that can be traded away in one
weighted score.

### 10.3 Stage 2 — quality-diversity discovery

Run a MAP-Elites-style archive whose objective is the best quality within each
validated behavioural niche. Use sliding or data-adaptive boundaries only if
their changing semantics are recorded; otherwise freeze interpretable bins
after calibration. Keep reserve candidates or deep cells where descriptor
noise would allow a lucky elite to block a niche. Variation should operate on
the smallest currently authorised design representation.

Alternative-path pressure may be added when new candidates repeat covered
trajectories. It should reward a different successful trace, not novelty for its
own sake. A surrogate is a later optimisation: introduce it only after enough
ground-truth data exist to test prospective accuracy, uncertainty calibration
and real wall-time savings.

### 10.4 Stage 3 — controlled allocation inside and across niches

Pair candidates on the same seeds and contexts. Use a predeclared practical
difference and error budget to eliminate clearly inferior candidates within a
niche. If several niches and claims are tested, allocate family-wise error
explicitly. A racing or multi-fidelity layer may precede this step only when
Stage 0 demonstrates acceptable agreement with full-fidelity rankings. Record
every elimination and preserve negative results; do not retune thresholds after
seeing the survivors.

### 10.5 Stage 4 — corrected archive and untouched confirmation

Freeze the finalists, code/content identity, descriptors, player policies,
context distribution, seeds, sample size, success rules and stop rules. Re-run
all finalists at full fidelity on an untouched bank. Recalculate descriptor
membership as well as performance, allowing apparent elites to move or fail.
Report apparent versus corrected coverage, per-cell quality distributions,
descriptor reproducibility, pairwise differences, stalls and replay keys.

A strategy counts towards P9 only when it remains buildable, behaviourally
distinct and viable after correction. The discovery archive, surrogate score,
training fitness, candidate name and visual deck difference are all
insufficient by themselves.

### 10.6 Stage 5 — player-facing validation

Automated evidence can establish simulator-relative strategic plurality. It
cannot establish enjoyment, comprehensibility, perceived fairness or whether
players recognise and can intentionally pursue the strategies. Those claims
require human playtesting or later telemetry against an explicit player model.
This does not weaken P9's automated gate; it prevents that gate from being
overclaimed as the whole commercial balance decision.

## 11. Fit with AI-native SDLC and the four operating rules

The proposed method is compatible with the governing development model rather
than an additional research ceremony.

1. **AI-native SDLC DNA.** Once the construct and authority are fixed, one agent
   can own the experiment contract, implementation, focused evidence, review
   and promotion. Human input is reserved for a genuinely product-defining
   ambiguity, not routine candidate approval.
2. **Minimum wall time / maximum effectiveness.** Quality-diversity searches
   several relevant niches in one programme. Paired seeds and valid sequential
   elimination concentrate expensive full runs on candidates that can still
   change the decision.
3. **Minimum model-token and compute.** Historical rows are used once for
   calibration. No deep surrogate, RL platform, compatibility layer or new
   runner is justified until it beats the simpler existing path on measured
   cost and decision quality.
4. **No compromise.** Cheap or learned evidence remains discovery-only. Every
   proven failure mode — stalls, random-build leakage, ceiling breaches,
   descriptor drift and holdout contamination — is represented by a relevant
   final boundary. Unknown fidelity or invalid descriptors fail closed.

## 12. Limitations and unresolved questions

The most important external-validity gap is genre. Hearthstone research usually
optimises a deck before a competitive match under a fixed playing policy.
Glassvow builds a deck across a stochastic run whose reward opportunities,
routes, encounters and survival state co-determine whether a strategy is even
reachable. Results from competitive metagames, short card games and robotic
controllers are structurally informative but not direct evidence of P9
feasibility.

The proposed framework also leaves several empirical questions open:

- whether trace-derived descriptors are stable, interpretable and causally
  connected to distinct strategic decisions;
- whether the existing simulator and competent policy can enact all relevant
  strategies rather than favouring familiar ones;
- whether any cheap fidelity preserves full-run ranking well enough to save
  wall time;
- how much resampling is needed for reliable performance and cell identity;
- which context distribution represents P9 rather than a convenient subset;
- whether the authorised content and policy space contains the required Dusk
  repertoire at all; and
- whether automated strategies remain legible and enjoyable to human players.

These questions should become explicit calibration or stop gates. They should
not be answered by adding complexity in advance.

## 13. Conclusion

The literature supports a better scientific programme, not a guaranteed
solution. Existing P9 work already contains credible confirmation mechanisms:
restricted controls, CRN, full-fidelity landscapes, held-out ceilings and
fail-closed verdicts. Its principal weakness is that discovery has largely
optimised global performance and assessed repertoire breadth afterwards.
Repeated convergence on one attractor is consequently an informative result,
but not an efficient method for discovering several niches.

Quality-diversity optimisation is the strongest directly supported alternative.
It changes the search product from one champion to a map of locally strong,
behaviourally distinct candidates. Direct Hearthstone studies demonstrate its
feasibility, while uncertain-QD research supplies the necessary correction for
noisy quality and descriptor estimates. Sequential selection, CRN and calibrated
multi-fidelity allocation can reduce cost; an untouched final holdout preserves
the acceptance claim.

The appropriate next step is therefore not another Dusk hypothesis and not an
immediate deep-learning system. It is a bounded retrospective calibration of
behavioural descriptors and low-fidelity validity, followed—only if those gates
pass—by a quality-diversity discovery contract with independent full-fidelity
confirmation. A negative result from that programme would mean that no P9
repertoire was found within the frozen representation, contexts and budget. It
would not justify weakening P9 or claiming that strategic diversity is
impossible.

## References

Ariyurek, S., Surer, E. and Betin-Can, A. (2021) ‘Playtesting: what is beyond
personas’, *arXiv* 2107.11965. Available at:
https://arxiv.org/abs/2107.11965 (Accessed: 2 September 2026).

Bhatt, A., Lee, S., de Mesentier Silva, F., Watson, C.W., Togelius, J. and
Hoover, A.K. (2018) ‘Exploring the Hearthstone deck space’, *Proceedings of the
13th International Conference on the Foundations of Digital Games*, article 18,
pp. 1–10. https://doi.org/10.1145/3235765.3235791.

Boesel, J., Nelson, B.L. and Kim, S.-H. (2003) ‘Using ranking and selection to
“clean up” after simulation optimization’, *Operations Research*, 51(5),
pp. 814–825. https://doi.org/10.1287/opre.51.5.814.16751.

Budijono, N., Goldman, P., Maloney, J., Mueller, J.B., Walker, P., Ladwig, J.
and Freedman, R.G. (2022) ‘Ludus: an optimization framework to balance auto
battler cards’, *Proceedings of the AAAI Conference on Artificial Intelligence*,
36(11), pp. 12727–12734. https://doi.org/10.1609/aaai.v36i11.21550.

De Mesentier Silva, F., Canaan, R., Lee, S., Fontaine, M.C., Togelius, J. and
Hoover, A.K. (2019) ‘Evolving the Hearthstone meta’, *2019 IEEE Conference on
Games*, pp. 1–8. https://doi.org/10.1109/CIG.2019.8847966.

Dwork, C., Feldman, V., Hardt, M., Pitassi, T., Reingold, O. and Roth, A.
(2015) ‘The reusable holdout: preserving validity in adaptive data analysis’,
*Science*, 349(6248), pp. 636–638. https://doi.org/10.1126/science.aaa9375.

Flageat, M. and Cully, A. (2020) ‘Fast and stable MAP-Elites in noisy domains
using deep grids’, *Proceedings of the 2020 Conference on Artificial Life*,
pp. 273–282. https://doi.org/10.1162/isal_a_00316.

Flageat, M. and Cully, A. (2024) ‘Uncertain quality-diversity: evaluation
methodology and new methods for quality-diversity in uncertain domains’, *IEEE
Transactions on Evolutionary Computation*, 28(4), pp. 891–902.
https://doi.org/10.1109/TEVC.2023.3273560.

Fontaine, M.C., Lee, S., Soros, L.B., de Mesentier Silva, F., Togelius, J. and
Hoover, A.K. (2019) ‘Mapping Hearthstone deck spaces through MAP-Elites with
sliding boundaries’, *Proceedings of the Genetic and Evolutionary Computation
Conference*, pp. 161–169. https://doi.org/10.1145/3321707.3321794.

Gaier, A., Asteroth, A. and Mouret, J.-B. (2018) ‘Data-efficient design
exploration through surrogate-assisted illumination’, *Evolutionary
Computation*, 26(3), pp. 381–410. https://doi.org/10.1162/evco_a_00231.

García-Sánchez, P., Tonda, A., Squillero, G., Mora, A.M. and Merelo, J.J.
(2016) ‘Evolutionary deckbuilding in HearthStone’, *2016 IEEE Conference on
Computational Intelligence and Games*, pp. 1–8.
https://doi.org/10.1109/CIG.2016.7860426.

García-Sánchez, P., Tonda, A., Mora, A.M., Squillero, G. and Merelo, J.J.
(2018) ‘Automated playtesting in collectible card games using evolutionary
algorithms: a case study in Hearthstone’, *Knowledge-Based Systems*, 153,
pp. 133–146. https://doi.org/10.1016/j.knosys.2018.04.030.

Glassvow (2026a) *Release candidate bar*. Internal project document. Available
at: [docs/rc-bar.md](../rc-bar.md) (Accessed: 2 September 2026).

Glassvow (2026b) *Strategy landscape — 14 August 2026*. Internal project
document. Available at:
[docs/balance/2026-08-14-strategy-landscape.md](../balance/2026-08-14-strategy-landscape.md)
(Accessed: 2 September 2026).

Glassvow (2026c) *s009 unchanged #215/#216 full exam — FAIL*. Internal project
document. Available at:
[docs/balance/2026-08-25-421-s009-full-exam.md](../balance/2026-08-25-421-s009-full-exam.md)
(Accessed: 2 September 2026).

Glassvow (2026d) *Glassvow AI-native SDLC*. Internal project document.
Available at: [docs/agents/ai-sdlc.md](../agents/ai-sdlc.md) (Accessed: 2
September 2026).

Holmgård, C. (2015) *Procedural personas for player decision modeling and
procedural content generation*. PhD thesis. IT University of Copenhagen.
Available at:
https://en.itu.dk/-/media/EN/Research/PhD-Programme/PhD-defences/2015/Holmgard2015_Procedural_Personas_for_Player_Decision_Modeling_and_Procedural_Content_Generation-1-pdf.pdf
(Accessed: 2 September 2026).

Holmgård, C., Liapis, A., Togelius, J. and Yannakakis, G.N. (2014) ‘Evolving
personas for player decision modeling’, *2014 IEEE Conference on Computational
Intelligence and Games*, pp. 405–412.
https://doi.org/10.1109/CIG.2014.6932911.

Holmgård, C., Green, M.C., Liapis, A. and Togelius, J. (2019) ‘Automated
playtesting with procedural personas through MCTS with evolved heuristics’,
*IEEE Transactions on Games*, 11(4), pp. 352–362.
https://doi.org/10.1109/TG.2018.2808198.

Jaffe, A.B. (2013) *Understanding game balance with quantitative methods*. PhD
thesis. University of Washington. Available at: http://hdl.handle.net/1773/22797
(Accessed: 2 September 2026).

Jaffe, A., Miller, A., Andersen, E., Liu, Y.-E., Karlin, A. and Popovic, Z.
(2012) ‘Evaluating competitive game balance with restricted play’,
*Proceedings of the AAAI Conference on Artificial Intelligence and Interactive
Digital Entertainment*, 8(1), pp. 26–31.
https://doi.org/10.1609/aiide.v8i1.12513.

Jamieson, K. and Talwalkar, A. (2016) ‘Non-stochastic best arm identification
and hyperparameter optimization’, *Proceedings of the 19th International
Conference on Artificial Intelligence and Statistics*, PMLR 51, pp. 240–248.
Available at: https://proceedings.mlr.press/v51/jamieson16.html (Accessed: 2
September 2026).

Justesen, N., Risi, S. and Mouret, J.-B. (2019) ‘MAP-Elites for noisy domains
by adaptive sampling’, *Proceedings of the Genetic and Evolutionary Computation
Conference Companion*, pp. 121–122.
https://doi.org/10.1145/3319619.3321904.

Kandasamy, K., Dasarathy, G., Oliva, J.B., Schneider, J. and Póczos, B. (2016)
‘Gaussian process bandit optimisation with multi-fidelity evaluations’,
*Advances in Neural Information Processing Systems*, 29, pp. 992–1000.
Available at:
https://proceedings.neurips.cc/paper_files/paper/2016/file/605ff764c617d3cd28dbbdd72be8f9a2-Paper.pdf
(Accessed: 2 September 2026).

Kim, S.-H. and Nelson, B.L. (2001) ‘A fully sequential procedure for
indifference-zone selection in simulation’, *ACM Transactions on Modeling and
Computer Simulation*, 11(3), pp. 251–273.
https://doi.org/10.1145/502109.502111.

Kirschner, J., Bogunovic, I., Jegelka, S. and Krause, A. (2020)
‘Distributionally robust Bayesian optimization’, *Proceedings of the 23rd
International Conference on Artificial Intelligence and Statistics*, PMLR 108,
pp. 2174–2184. Available at: https://proceedings.mlr.press/v108/kirschner20a.html
(Accessed: 2 September 2026).

Lehman, J. and Stanley, K.O. (2011a) ‘Abandoning objectives: evolution through
the search for novelty alone’, *Evolutionary Computation*, 19(2), pp. 189–223.
https://doi.org/10.1162/EVCO_a_00025.

Lehman, J. and Stanley, K.O. (2011b) ‘Evolving a diversity of creatures through
novelty search and local competition’, *Proceedings of the Genetic and
Evolutionary Computation Conference*, pp. 211–218.
https://doi.org/10.1145/2001576.2001606.

Li, L., Jamieson, K., DeSalvo, G., Rostamizadeh, A. and Talwalkar, A. (2018)
‘Hyperband: a novel bandit-based approach to hyperparameter optimization’,
*Journal of Machine Learning Research*, 18(185), pp. 1–52. Available at:
https://www.jmlr.org/papers/volume18/16-558/16-558.pdf (Accessed: 2 September
2026).

Malek, A., Katariya, S., Chow, Y. and Ghavamzadeh, M. (2017) ‘Sequential
multiple hypothesis testing with Type I error control’, *Proceedings of the
20th International Conference on Artificial Intelligence and Statistics*, PMLR
54, pp. 1468–1476. Available at:
https://proceedings.mlr.press/v54/malek17a.html (Accessed: 2 September 2026).

Mouret, J.-B. and Clune, J. (2015) ‘Illuminating search spaces by mapping
elites’, *arXiv* 1504.04909. Available at: https://arxiv.org/abs/1504.04909
(Accessed: 2 September 2026).

Nelson, B.L. and Matejcik, F.J. (1995) ‘Using common random numbers for
indifference-zone selection and multiple comparisons in simulation’,
*Management Science*, 41(12), pp. 1935–1945.
https://doi.org/10.1287/mnsc.41.12.1935.

Pearce, M.A.L., Poloczek, M. and Branke, J. (2022) ‘Bayesian optimization
allowing for common random numbers’, *Operations Research*, 70(6),
pp. 3457–3472. https://doi.org/10.1287/opre.2021.2208.

Pérez-Liébana, D., Guerrero-Romero, C., Dockhorn, A., Xu, L., Hurtado, J. and
Jeurissen, D. (2021) ‘Generating diverse and competitive play-styles for
strategy games’, *2021 IEEE Conference on Games*, pp. 1–8.
https://doi.org/10.1109/CoG52621.2021.9619094.

Pfau, J. and El-Nasr, M.S. (2024) ‘On video game balancing: joining player-
and data-driven analytics’, *Games: Research and Practice*, 2(3), article 27,
pp. 1–30. https://doi.org/10.1145/3675807.

Pfau, J., Liapis, A., Volkmar, G., Yannakakis, G.N. and Malaka, R. (2020)
‘Dungeons & Replicants: automated game balancing via deep player behavior
modeling’, *2020 IEEE Conference on Games*, pp. 431–438.
https://doi.org/10.1109/CoG47356.2020.9231958.

Pugh, J.K., Soros, L.B. and Stanley, K.O. (2016) ‘Quality diversity: a new
frontier for evolutionary computation’, *Frontiers in Robotics and AI*, 3,
article 40. https://doi.org/10.3389/frobt.2016.00040.

Qin, H., Xiang, Y., Zhang, H., Han, Y., Wang, Y., Tao, X. and Liu, Y. (2026)
‘A survey on quality-diversity optimization: approaches, applications, and
challenges’, *Swarm and Evolutionary Computation*, 100, article 102240.
https://doi.org/10.1016/j.swevo.2025.102240.

Shields, S.M. (2026) *Procedural, player-centric game balancing*. PhD thesis.
University of California, Santa Cruz. Available at:
https://escholarship.org/uc/item/97z569b3 (Accessed: 2 September 2026).

Volz, V., Rudolph, G. and Naujoks, B. (2016) ‘Demonstrating the feasibility of
automatic game balancing’, *Proceedings of the Genetic and Evolutionary
Computation Conference*, pp. 269–270.
https://doi.org/10.1145/2908812.2908913.

Yao, J., Liu, W., Fu, H., Yang, Y., McAleer, S., Fu, Q. and Yang, W. (2023)
‘Policy space diversity for non-transitive games’, *Advances in Neural
Information Processing Systems*, 36. Available at:
https://papers.nips.cc/paper_files/paper/2023/hash/d61819e9b4a607b8448de762235148c4-Abstract-Conference.html
(Accessed: 2 September 2026).

Zhang, Y., Fontaine, M.C., Hoover, A.K. and Nikolaidis, S. (2022) ‘Deep
surrogate assisted MAP-Elites for automated Hearthstone deckbuilding’,
*Proceedings of the Genetic and Evolutionary Computation Conference*,
pp. 158–167. https://doi.org/10.1145/3512290.3528718.
