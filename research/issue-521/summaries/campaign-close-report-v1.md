# Issue #521 campaign close report

## Decision

The campaign returns one precisely bounded negative and stops at the first native-mechanism gate. The complete seven-direction detector suite and adaptive joint policy-content co-design were not run.

## Decisive matched-identity evidence

- Selective RandomBuild regression failed: RandomBuild delta 0.000 versus the required at most -0.150; the optimised global-mean delta was -0.030.
- The global-difficulty comparator remained distinguishable: optimised global-mean delta -0.177.
- Route separation failed: single-route and multi-route mean viable-policy counts were both 6.75, giving a difference of 0.00 versus the required at least 1.00.
- Reliability failed: identity and random-regression had zero stalls, while single-route had 99 and multi-route had 11 30-turn stalls. Native sampling reduced the old duplicate-emulation counts of 129 and 24, but did not meet the zero-additional-stall rule.

## Bound support

- Source `0f005282e8881d970da284f4868caedf60cc8142`; Godot `4.7.2.stable.official.ed1daf0bf`; M1 Max 64 GB.
- Sampler `keyed-exponential-race-v1`, without replacement, fixed per-lane common-random-number uniforms and unchanged outer RunState cursor.
- Exact #520 conditioning: neutral single route weight 9; separated routes weight 5 except reveal-added `resonantLance` weight 4; `hex` weight 24 in common, uncommon and rare.
- Frozen cohort: sixteen #519 registered functional policies plus RandomBuild and RandomPlay; four aspect x vow grids; research seeds 20300-20315.
- Rows: 1,152 reused #520 baseline rows and 5,760 new first-gate rows. All five proposed content files were simulated. The 504 #519 resume-drift identities remained excluded; intersection zero.

## Quarantine and stop

The reused #520 baseline versus reserialised identity-catalogue whole-run comparison and a non-inherited aspect event proxy were confounded, so neither is used in the finding. Direct identity reward checks and 321 frozen legacy trace rows passed. Removing those readouts does not change the stop: all three decisive matched-identity failures above remain.

No full-suite, QD/BO, beam/MCTS/RL, acceptance-seed or reserve-seed row was spent. No product branch, product file, PR, GitHub Actions run or successor issue was created.
