"""Reproduce original-arm arithmetic from preserved per-seed outcomes, not raw.

No simulations, model fitting or fresh independent confirmation. The immutable
bitmap contains only win/loss; the native writer checked every stall/error zero.
"""
from pathlib import Path
import collections, hashlib, json, re, sys
import numpy as np
from scipy.stats import beta
C = Path(__file__).resolve().parent
PRIMARY_SHA = '5c6220adc9433c45dec016fb1025f28712026d2b0b80c1c151d7339bb73888d5'

def read(path):
    p = Path(path)
    assert hashlib.sha256(p.read_bytes()).hexdigest() == PRIMARY_SHA
    x = json.loads(p.read_text())
    assert x['format'] == 'p9-original-arm-win-bitmap-v1'
    assert (x['rows'],x['runs_per_cell'],x['seed0']) == (2048,64,45010000)
    assert x['catalogue_indices'] == ['original','candidate']
    assert x['aspect_indices'] == ['duskblade','ashwarden']
    assert x['columns'] == ['catalogue_index','aspect_index','vow','arm','outcomes_hex']
    expected = {(c,a,v,k) for c in (0,1) for a in (0,1) for v in (0,5) for k in (1,2,3,4)}
    groups = {}; cells = []; counts = collections.Counter()
    for c,a,v,k,encoded in x['cells']:
        key = (c,a,v,k)
        assert key in expected and key not in groups and re.fullmatch(r'[0-9a-f]{16}',encoded)
        bits = f'{int(encoded,16):064b}'
        groups[key] = np.asarray([b == '1' for b in bits],dtype=float)
        wins = bits.count('1'); counts['win'] += wins; counts['loss'] += 64-wins
        ci = [0.0 if wins == 0 else float(beta.ppf(.025,wins,65-wins)),
              1.0 if wins == 64 else float(beta.ppf(.975,wins+1,64-wins))]
        name = f'{x["catalogue_indices"][c]}-{x["aspect_indices"][a]}-v{v}-arm{k}'
        cells.append({'id':name,'wins':wins,'n':64,'rate':wins/64,'nominal_ci95':ci})
    assert set(groups) == expected
    totals = {k:counts.get(k,0) for k in ('win','loss','stall','error')}
    assert totals == x['counts'] == {'win':382,'loss':1666,'stall':0,'error':0}
    ix = np.random.default_rng(45019999).integers(0,64,size=(10000,64))
    gaps = []
    for a in (0,1):
        for v in (0,5):
            for k in (1,2,3,4):
                d = groups[(1,a,v,k)]-groups[(0,a,v,k)]
                gaps.append({'aspect':x['aspect_indices'][a],'vow':v,'arm':k,
                    'candidate_minus_original':float(d.mean()),
                    'nominal_seed_bootstrap95':np.quantile(d[ix].mean(axis=1),[.025,.975]).tolist()})
    return {'status':'PUBLISHED_ORIGINAL_ARM_DIAGNOSTIC_NOT_P9',
        'execution_classification':'REPRODUCTION_OF_POSSIBLY_EXPOSED_ASSIGNMENT_NOT_FRESH_CONFIRMATION',
        'rows':2048,'seeds':[45010000,45010063],'source_sha256':PRIMARY_SHA,
        'counts':totals,'cells':cells,'paired_catalogue_gaps':gaps,'full_raw_included':False,
        'limits':['Original arm definitions on diagnostic seeds; no signed C2 receipt.',
            'No model refit, content/policy change or simulations in this reader.',
            'Original controller results do not replace stronger research-controller evidence.',
            'Nominal intervals are descriptive; no package, seven-direction detector or P9 admission.']}

if __name__ == '__main__':
    p = Path(sys.argv[1]) if len(sys.argv) > 1 else C/'ORIGINAL-PRIMARY.json'
    result = read(p); out = p.with_name('ORIGINAL-PUBLISHED-RESULTS.json')
    data = json.dumps(result,indent=2)+'\n'
    if out.exists():
        assert out.read_text() == data, 'Refusing to overwrite a different readout'
    else:
        out.write_text(data)
    print(result['counts'])
