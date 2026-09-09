"""Retrospective complete-capture attribution of the fixed support failure.
No native run, new sample, counterfactual optimiser or changed decision.
"""
from collections import defaultdict
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile
import sys
import read_pair

require=read_pair.require
sha=read_pair.sha


def functions(source):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',source,re.M))
    return {m.group(1):source[m.start():matches[i+1].start() if i+1<len(matches) else len(source)] for i,m in enumerate(matches)}


def main(repo,folder,out):
    repo,folder,out=map(Path,(repo,folder,out));require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    p=json.loads((folder/'RESOLVED-PROTOCOL.json').read_bytes())
    t=json.loads((folder/'TERMINAL.json').read_bytes())
    receipt=json.loads((folder/'REMOTE-READBACK.json').read_bytes())
    require(receipt['all_bytes_equal'] and receipt['reproduced_stages']==list(t['stages']),'UNVERIFIED_INPUT')
    require(t['status']=='INHERITED_ASH_PAIR_SUPPORT_FAIL_IN_FIXED_POLICY_FAMILY' and t.get('v0_skipped') is True,'EXPECTED_FIXED_TERMINAL')
    result=(folder/'v5/RESULTS.json').read_bytes()
    rr=json.loads(result);flags={r['row_key']:r for r in rr['row_results']}
    row_counts=defaultdict(int);policies=defaultdict(set);pipeline=[]
    for first in range(0,p['policies'],p['policies_per_cell']):
        stem=f'v5-{first:03d}';cfg={'root':p['policy_root'],'first':first,'count':p['policies_per_cell'],'seeds':p['seeds'],'vow':5,'integration':False}
        rows=read_pair.outcome_records(folder/'v5'/(stem+'.outcomes.jsonl.xz'),cfg,p)
        for r in rows:
            f=flags[r['row_key']];events=r['row']['packageEvents'];deck=set(r['row']['deckIds'])
            features={'source_offered':events.get('bloodRiteOffered',0)>0,'consumer_offered':events.get('leechBladeOffered',0)>0,
                'both_roles_offered':events.get('bloodRiteOffered',0)>0 and events.get('leechBladeOffered',0)>0,
                'source_in_final_deck':'bloodRite' in deck,'consumer_in_final_deck':'leechBlade' in deck,
                'both_in_final_deck':{'bloodRite','leechBlade'}<=deck,
                'source_played':events.get('bloodRitePlayed',0)>0,'consumer_played':events.get('leechBladePlayed',0)>0,
                'bloodfire_applied':f['applied']>0,'bloodfire_consumed':f['consumed']>0,
                'registered_active':f['bloodfire'],'incremental_hp':f['bloodfire_incremental_hp'],
                'win_and_active':f['bloodfire'] and r['row']['outcome']=='win',
                'win_and_hand_active':f['hand'] and r['row']['outcome']=='win'}
            for name,v in features.items():
                row_counts[name]+=int(v)
                if v:policies[name].add(r['index'])
            pipeline.append({'row_key':r['row_key'],'index':r['index'],'seed':r['seed'],**features})
    require(len(pipeline)==512 and len({r['row_key'] for r in pipeline})==512,'FULL_ROW_COVERAGE')
    require(len(policies['registered_active'])==15 and len(policies['incremental_hp'])==15,'DECISION_RECONCILIATION')
    raw=(folder/'runtime-source.tar.xz').read_bytes();manifest=json.loads((folder/'SOURCE-MANIFEST.json').read_bytes())
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as tf:
        pilot=tf.extractfile('tools/balance_pilot.gd').read();sim=tf.extractfile('tools/balance_sim.gd').read()
    require(sha(pilot)==manifest['tools/balance_pilot.gd']['sha256'],'PILOT_SOURCE')
    require(sha(sim)==manifest['tools/balance_sim.gd']['sha256'],'SIM_SOURCE')
    fs=functions(pilot.decode());status=fs['_status_value'];special=fs['_special_value'];card=fs['card_score']
    require('"bloodfire"' not in status and 'return 0.0' in status,'STATUS_VALUATION')
    require('id: String, dusk: bool' in special and 'fx[' not in special,'SPECIAL_VALUE_INPUT')
    require('_special_value(str(fx.get("id", "")), dusk)' in card,'SPECIAL_CALL_BINDING')
    require('_bump("%sOffered" % str(row.get("id", "")))' in sim.decode(),'OFFER_COUNTER_SOURCE')
    history=repo/'research/p9-six-route/ash-inheritance-20260909/binding-1/inputs/harness.tar.gz'
    b=history.read_bytes();require(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()=='0e963a6dfadb87912f9b1074b78d8629bbad2a47','HISTORICAL_ARCHIVE')
    with tarfile.open(fileobj=io.BytesIO(b),mode='r:gz') as tf:
        historic=functions(tf.extractfile('source/tools/balance_pilot.gd').read().decode())
    selected={k:v for k,v in historic.items() if k in ('_status_value','card_reward_score','_combat_score')}
    (out/'HISTORICAL-CONTROLLER-SOURCE.json').write_text(json.dumps(selected,indent=2)+'\n')
    source={'current_pilot_sha256':sha(pilot),'current_functions':{k:fs[k] for k in ('card_score','_status_value','_special_value')},
            'bloodfire_setup_status_marginal_reward_value':0,
            'special_reward_score_reads_bonus_amount':False,
            'counterfactual_improved_controller_executed':False,
            'limit':'Source blindness does not prove that a particular controller repair improves complete-run performance. Current combat preview may still exploit already acquired Bloodfire; only these acquisition valuation functions are being characterised.'}
    (out/'CONTROLLER-SOURCE.json').write_text(json.dumps(source,indent=2)+'\n')
    result={'kind':'COMPLETE_RETAINED_SUPPORT_BOTTLENECK_AUDIT','rows':512,'policy_configurations':128,
            'input_result_sha256':sha((folder/'v5/RESULTS.json').read_bytes()),
            'row_pipeline_counts':dict(row_counts),'policy_pipeline_counts':{k:len(v) for k,v in policies.items()},
            'policy_sets':{k:sorted(v) for k,v in policies.items()},'row_pipeline':pipeline,
            'decision_unchanged':t['status'],'v0_not_run':True,
            'source_findings':{k:v for k,v in source.items() if k!='current_functions'},
            'next_action':'Qualify a specifically source-bound research-controller capability change using the retained historical Bloodfire valuation/acquisition functions or already evidenced stronger controller. Do not change product scalars or retry random policy roots. Establish exact affected public-state interfaces and preserved null/signed-control semantics before any new fixed matched-cost controller experiment. No replacement is selected or qualified by this audit.',
            'limits':['Offers are exposure, not proof an item was affordable or should be selected.','Pipeline counts and shared source blindness are descriptive, not a causal claim about why a whole run lost.','Historical controller source is read, not installed; empirical results are not carried.','The fixed policy-family failure and all previous failed candidates remain closed.'],
            'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    (out/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('policy_sets','row_pipeline')},indent=2))

if __name__=='__main__':main(*sys.argv[1:])
