"""Descriptive completion of the registered signed-vector readout, not admission.

All 64 seeds, zeros and negative per-run sums are retained. These stratified
post-decision effects are neither whole-run treatments nor independent probes.
"""
from pathlib import Path
import hashlib, json
import numpy as np
from read_published_validation import load_cells, ANCHOR, ROLES
from read_mixed_validation import vectors, predict
C = Path(__file__).resolve().parent

def read():
    cells,_ = load_cells()
    model_path = C.parent/'FROZEN-DESCRIPTOR.json'
    assert hashlib.sha256(model_path.read_bytes()).hexdigest() == '2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    model = json.loads(model_path.read_text())['models']
    ix = np.random.default_rng(44019999).integers(0,64,size=(10000,64))
    rows = []
    for a,routes in ANCHOR.items():
        for v in (0,5):
            for route,anchor in routes.items():
                records = [r for b in range(4) for r in cells[f'a{a}-{route}-v{v}-b{b}']['rows']]
                assert len(records) == 64
                allv = np.asarray([vectors(r) for r in records]); j = ROLES.index(anchor)
                interaction = allv[:,j,5].astype(float)
                bmeans = interaction[ix].mean(axis=1)
                wins = np.asarray([r[0] == 'win' for r in records])
                active = allv[:,j,1] > 0
                unresolved = np.asarray([predict(model,a,r).startswith('unresolved') for r in records])
                positive_any = allv[:,:,1].sum(axis=1) > 0
                rows.append({'aspect':a,'vow':v,'route':route,'anchor':anchor,'n':64,
                    'consumer_positive_runs':int(active.sum()),
                    'wins_without_anchor_positive_sample':int((wins & ~active).sum()),
                    'interaction_sum':int(interaction.sum()),
                    'interaction_positive_run_sums':int((interaction>0).sum()),
                    'interaction_negative_run_sums':int((interaction<0).sum()),
                    'nominal_seed_bootstrap95_mean':np.quantile(bmeans,[.025,.975]).tolist(),
                    'bootstrap_positive_mean_fraction':float((bmeans>0).mean()),
                    'unresolved_runs':int(unresolved.sum()),
                    'unresolved_despite_any_positive_sample':int((unresolved & positive_any).sum())})
    return {'status':'DESCRIPTIVE_SIGNED_CONTRIBUTION_READOUT_NOT_P9',
        'source_readout_sha256':hashlib.sha256((C/'PUBLISHED-VALIDATION.json').read_bytes()).hexdigest(),
        'rows':rows,'new_simulations':0,'model_refit':False,
        'limits':['Selected dimension is frozen: catalyst net poison, other route anchors immediate actual HP removed.',
            'Per-run sums use first zero/positive stratum samples per combat, not an all-action average.',
            'Nominal bootstrap summaries are descriptive, not the admitted detector sign-agreement test.',
            'Wins without an observed anchor do not estimate removal effects or prove dispensability.',
            'No full native-event/acquisition recovery, package admission or whole-run causal certification.']}

if __name__ == '__main__':
    r = read(); p = C/'CONTRIBUTION-READOUT.json'; s = json.dumps(r,indent=2)+'\n'
    if p.exists():
        assert p.read_text() == s
    else:
        p.write_text(s)
    for row in r['rows']: print(row)
