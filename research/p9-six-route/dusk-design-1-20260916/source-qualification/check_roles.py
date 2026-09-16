"""Corrective source evidence only; does not calculate scientific eligibility.

The previous equal-recipe checks are removed. K2's accepted standalone evidence
is reused by exact predecessor, not rerun here. Peer checks use its unchanged law.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from copy import deepcopy
from itertools import product
from role_model import Enemy, card, play, physical
from corrective_model import ProductState as State, play_named as act, boundary, observe

MUTANTS = ("drop-printed-chip", "drop-stun", "wrong-target", "per-hit-chips",
           "retain-anchor", "sticky-anchor", "wrong-return-target",
           "eager-settlement", "sorted-pending", "clamp-amount")


def canonical(x):
    return json.dumps(x, sort_keys=True, separators=(",", ":"))


def rle(xs):
    out = []
    for x in xs:
        if out and x == out[-1][1]:
            out[-1][0] += 1
        else:
            out.append([1, x])
    return out


def hits_since(s, start, t=0):
    return sum(e[4] for e in s.events[start:] if e[0] == "hit" and e[1] == t)


def run(mutant="", export_cells=None):
    checks = []
    def check(name, ok, observed):
        checks.append({"name": name, "pass": bool(ok), "observed": observed})
    def fresh(**kw):
        return State(enemies=[Enemy(0, hp=80, chips=3), Enemy(1, hp=80)], **kw)
    def command(s, name, uid, target=0, **kw):
        return act(s, name, uid, target, mutant=mutant, **kw)

    grid = []
    guard_errors, payoff_errors = [], []
    stream = hashlib.sha256()
    if export_cells:
        export_cells.write('')
    # Ordering and domains were committed in CORRECTION.json before these runs.
    for up_p, up_c, hp, block, strength, weak, adamant, facet in product(
            (False, True), (False, True), (2, 80), (0, 40), (0, 2),
            (False, True), (False, True), (3, 5)):
        for chips in range(facet):
            cfg = [up_p, up_c, hp, block, strength, weak, adamant, facet, chips]
            row = []
            for p_on, c_on in product((False, True), repeat=2):
                s = State(enemies=[Enemy(0, hp=hp, block=block, chips=chips,
                    facet=facet, adamant=adamant), Enemy(1, hp=80)],
                    strength=strength, weak=weak)
                command(s, 'chisel', 1, up=up_p, p_on=p_on)
                e = s.enemies[0]
                before = [e.hp, e.block, e.chips, e.facet, e.cracked, e.stunned, e.spent]
                # Independent source arithmetic for the narrowly declared grid.
                pd = (7 if up_p else 4) + strength
                if weak:
                    pd = pd * 3 // 4
                loss = max(0, pd - block)
                alive = loss < hp
                total = chips + ((1 + int(p_on)) if loss > 0 and alive else 0)
                crossed = total >= facet and alive
                predicted = [max(0, hp-loss), max(0, block-pd),
                             total-facet if crossed else total,
                             facet+int(crossed),
                             2 if crossed and not adamant else 0,
                             crossed and not adamant, crossed and adamant]
                if before != predicted:
                    guard_errors.append([len(grid), int(p_on), int(c_on)])
                gate = e.stunned or e.cracked > 0
                start = len(s.events)
                result = command(s, 'resonantLance', 2, up=up_c, c_on=c_on)
                amount = None if result != 'PLAYED' else hits_since(s, start)
                expected = None
                if alive:
                    d = (10 if up_c else 7) * (2 if predicted[4] > 0 and c_on else 1) + strength
                    if weak:
                        d = d * 3 // 4
                    if predicted[4] > 0:
                        d = d * 3 // 2
                    expected = min(predicted[0], max(0, d-predicted[1]))
                if amount != expected:
                    payoff_errors.append([len(grid), int(p_on), int(c_on)])
                row.append([int(result == 'PLAYED'), int(gate), amount])
                full = [cfg, [p_on, c_on], before, result, observe(s)]
                line = canonical(full) + '\n'
                stream.update(line.encode())
                if export_cells:
                    export_cells.write(line)
            grid.append(row)
    check('K1-source-threshold-predictions', not guard_errors,
          {'contexts': len(grid), 'mismatches': guard_errors})
    check('K1-source-consumer-predictions', not payoff_errors,
          {'component_cells': len(grid)*4, 'mismatches': payoff_errors})

    cells = {}
    for p_on, c_on in product((False, True), repeat=2):
        s = fresh()
        command(s, 'chisel', 1, p_on=p_on)
        start = len(s.events)
        command(s, 'resonantLance', 2, c_on=c_on)
        cells[f'{int(p_on)}{int(c_on)}'] = hits_since(s, start)
    check('K1-nonredundant-producer-and-reader', list(cells.values()) == [7,7,10,21], cells)
    a=fresh(); command(a,'resonantLance',2)
    check('missing-producer-consumer-independently-playable',physical(a)==7 and a.cards==1,a.events)
    a=fresh(); command(a,'chisel',1)
    check('missing-consumer-preserves-producer-not-complete-chain',
          physical(a)==4 and a.enemies[0].stunned and a.cards==1,a.events)
    a, b = fresh(), fresh()
    command(a, 'chisel', 1); command(b, 'chisel', 1)
    b.enemies[0].stunned = False; b.enemies[0].cracked = 0
    command(a, 'resonantLance', 2); command(b, 'resonantLance', 2)
    check('K1-joint-mediator-intervention-not-gameplay', physical(a) > physical(b),
          {'intact': physical(a), 'joint_stun_cracked_erased': physical(b)})
    a, b = fresh(), fresh()
    command(a, 'chisel', 1); command(b, 'warCry', 1)
    check('K1-versus-complete-direct-Cracked-producer',
          a.enemies[0].stunned and not b.enemies[0].stunned and a.embers > b.embers,
          {'chisel': observe(a), 'warCry': observe(b)})
    a = State(enemies=[Enemy(0, block=40), Enemy(1)])
    b = deepcopy(a)
    command(a, 'chisel', 1); command(b, 'eclipseSlash', 1)
    check('reverse-separation-blocked-direct-status',
          a.enemies[0].cracked == 0 and b.enemies[0].cracked == 1,
          [a.enemies[0].cracked, b.enemies[0].cracked])
    a = fresh(); a.enemies[0].chips = 4
    command(a, 'strike', 1)
    start = len(a.events); command(a, 'resonantLance', 2)
    check('ordinary-chip-is-genuine-producer-substitute', hits_since(a,start) == 21,
          {'lance_hp': hits_since(a,start), 'trace': a.events})
    a = fresh(); a.enemies[0].chips = 0; a.enemies[0].cracked = 1
    command(a,'resonantLance',2)
    check('direct-Cracked-is-genuine-guard-substitute', physical(a) == 21, a.events)
    a = fresh(); command(a,'chisel',1); command(a,'resonantLance',2,c_on=False)
    check('disabled-echo-is-not-whole-command-zero', physical(a) == 14, a.events)
    a = fresh(); command(a,'resonantLance',2); command(a,'chisel',1)
    check('reverse-order-cannot-change-earlier-hit',
          next(e[4] for e in a.events if e[0]=='hit') == 7, a.events)
    a = fresh(); command(a,'chisel',1)
    start=len(a.events); command(a,'resonantLance',2,1)
    check('K1-selected-target-read',hits_since(a,start,1)==7,a.events)
    a = fresh(); a.enemies[0].adamant=True
    command(a,'chisel',1)
    check('Adamant-is-not-real-Shatter',
          [a.enemies[0].stunned,a.enemies[0].cracked,a.enemies[0].spent,a.embers]==[False,0,True,0],observe(a))
    a = fresh(); command(a,'chisel',1)
    branches = ['skip' if e.stunned else 'act' for e in a.enemies]
    boundary(a,mutant); mid=[a.enemies[0].stunned,a.enemies[0].cracked]
    boundary(a,mutant)
    check('coupled-skip-and-decay-not-Boolean-echo-quotient',
          branches==['skip','act'] and mid==[False,1] and a.enemies[0].cracked==0,
          {'source_enemy_phase_branches':branches,'after_one_boundary':mid,'after_two':a.enemies[0].cracked})
    a,b=fresh(),fresh(); a.enemies[0].chips=2
    command(a,'chisel',1); command(b,'chisel',1)
    check('partial-Facet-remainder-cannot-be-erased',
          not a.enemies[0].stunned and b.enemies[0].stunned,[observe(a),observe(b)])
    for label,s,uid in [('energy',fresh(energy=0),1),('copy',fresh(hand=[9]),1),
                         ('terminal',fresh(over=True),1)]:
        before=deepcopy(s); result=command(s,'chisel',uid)
        check('unavailable-'+label,result=='ILLEGAL_UNAVAILABLE' and s==before,
              {'result':result,'unchanged':s==before,'tail':'UNKNOWN'})
    a=fresh(); a.enemies[0].hp=2
    command(a,'chisel',1); result=command(a,'resonantLance',2)
    check('producer-death-denies-consumer-not-zero',result=='ILLEGAL_UNAVAILABLE',{'tail':'UNKNOWN','trace':a.events})
    a=fresh(energy=1,discount=1)
    res=[command(a,'chisel',1),command(a,'resonantLance',2)]
    check('effective-cost-discount-retained',res==['PLAYED','PLAYED'] and a.energy==0,observe(a))
    a=fresh(); b=deepcopy(a)
    for s,controls,p_on,c_on in [(a,True,True,True),(b,False,False,False)]:
        command(s,'chisel',1,controls=controls,p_on=p_on)
        command(s,'resonantLance',2,controls=controls,c_on=c_on)
    check('K1-wrapper-off-is-exact-stock-projection',observe(a)==observe(b),{'equal':observe(a)==observe(b)})
    others=[]
    for p_on,c_on in product((False,True),repeat=2):
        s=fresh(dusk=False)
        command(s,'chisel',1,p_on=p_on); command(s,'resonantLance',2,c_on=c_on)
        others.append(observe(s))
    check('K1-other-aspect-wrapper-null',all(o==others[0] for o in others),others[0])
    a=fresh(hp=2); a.enemies[0].thorns=3
    command(a,'chisel',1)
    check('producer-lethal-Thorns-suppresses-settlement',a.over and a.enemies[0].chips==3,observe(a))
    a=State(enemies=[Enemy(0,hp=2),Enemy(1)])
    command(a,'resonantLance',2)
    check('native-amount-overkill-physical-separated',next(e[2:5] for e in a.events if e[0]=='hit')==[7,5,2],a.events)

    # Same product, same initial resources/targets. These are source peer probes,
    # not reruns of either accepted standalone suite or strategy labels.
    peers={}
    for producer,consumer in product(('chisel','empower','setTheAngle'),
                                    ('resonantLance','flurry','crosscut')):
        s=fresh(); command(s,producer,1,0)
        producer_state=observe(s)
        start=len(s.events); command(s,consumer,2,1 if consumer=='crosscut' else 0)
        peers[producer+'->'+consumer]={'producer_state':producer_state,
            'hits': [e for e in s.events[start:] if e[0]=='hit'],
            'player': [s.block,s.strength], 'counts':[s.cards,s.attacks]}
    check('peer-producer-snapshots-are-value-copies',
          all(v['producer_state']['zones'][0] == [2,3,4] and
              2 not in v['producer_state']['zones'][1] for v in peers.values()),
          {k: v['producer_state']['zones'] for k,v in peers.items()})
    def targets(key): return [h[1] for h in peers[key]['hits']]
    check('peer-all-six-cross-substitutions-retained',
          targets('chisel->crosscut')==[1] and targets('empower->crosscut')==[1] and
          targets('setTheAngle->crosscut')==[1,0] and
          len(targets('setTheAngle->flurry'))==3 and
          peers['chisel->flurry']['player'][1]==0 and
          peers['empower->resonantLance']['hits'][0][4]==9,peers)
    # Two continuations for each producer retain different target/lifetime laws.
    matrix={}
    for route,prod,cons in [('K1','chisel','resonantLance'),('K2','empower','flurry'),('DD1','setTheAngle','crosscut')]:
        vals=[]
        for t in (0,1):
            s=fresh(); command(s,prod,1,0)
            start=len(s.events); command(s,cons,2,t)
            vals.append([e for e in s.events[start:] if e[0]=='hit'])
        matrix[route]=vals
    check('peer-target-binding-patterns',
          [h[4] for h in matrix['K1'][0]]==[21] and [h[4] for h in matrix['K1'][1]]==[7] and
          [h[4] for h in matrix['K2'][0]]==[4,4,4] and [h[4] for h in matrix['K2'][1]]==[4,4,4] and
          [h[1] for h in matrix['DD1'][0]]==[0] and [h[1] for h in matrix['DD1'][1]]==[1,0],matrix)
    a=fresh(energy=10,hand=list(range(1,9))); a.enemies[0].hp=a.enemies[1].hp=200
    for name,uid,t in [('setTheAngle',1,0),('chisel',2,0),('empower',3,0),
                       ('crosscut',4,1),('resonantLance',5,0),('flurry',6,0)]:
        command(a,name,uid,t)
    direct=[e[4] for e in a.events if e[0]=='hit']
    check('same-product-mixed-chains-not-one-hot',direct==[4,7,10,24,6,6,6],observe(a))
    a=fresh(); a.enemies[0].chips=0
    command(a,'setTheAngle',1,0); command(a,'crosscut',2,1); command(a,'crosscut',3,1)
    check('peer-anchor-consumed-not-persistent-Strength',
          len([e for e in a.events if e[0]=='hit' and e[1]==0])==1,observe(a))
    a=fresh(); command(a,'setTheAngle',1,0); boundary(a,mutant)
    command(a,'crosscut',2,1)
    check('peer-anchor-expires-not-persistent-Strength',
          [e[1] for e in a.events if e[0]=='hit']==[1],observe(a))
    a=fresh(); a.anchor=Enemy(0,hp=80)
    command(a,'crosscut',2,1)
    check('peer-anchor-object-identity-not-matching-key',
          [e[1] for e in a.events if e[0]=='hit']==[1],observe(a))
    # Both targets close to a threshold, primary index 1 before return index 0.
    # Bell kills target 0 only after its return, in correct native ordering.
    a=State(enemies=[Enemy(0,hp=9,chips=4),Enemy(1,hp=80,chips=4)],bell=True)
    command(a,'setTheAngle',1,0); command(a,'crosscut',2,1)
    chips=[e[1] for e in a.events if e[0]=='chip']
    direct=[e for e in a.events if e[0]=='hit']
    check('peer-insertion-order-and-return-before-Bell',
          len(direct)>=3 and direct[0][1:5]==[1,5,0,5] and
          direct[1][1:5]==[0,5,0,5] and chips==[1],observe(a))
    # Null DD1 does not remove generic native collateral or turn it into DD1 credit.
    a=State(enemies=[Enemy(0,hp=80),Enemy(1,hp=80,chips=4)],bell=True)
    command(a,'setTheAngle',1,0,dd1_on=False); command(a,'crosscut',2,1,dd1_on=False)
    check('collateral-can-hit-anchor-with-DD1-off',physical(a,0)==4,observe(a))
    # Corrected label only: enabled power-cycle has no draw-Skill and is unarmed.
    a=State()
    play(a,card('empower'),1,family='power-cycle',enabled=True)
    play(a,card('flurry'),2,family='power-cycle',enabled=True)
    check('power-cycle-enabled-but-unarmed-no-draw',
          not a.flow and a.ready and a.enemies[0].chips==1,
          {'flow':a.flow,'form':a.ready,'chips':a.enemies[0].chips,'not_port_ON':True})
    # Native interpretation must not run three chip settlements for Flurry.
    a=fresh(); a.enemies[0].chips=4
    command(a,'empower',1); command(a,'flurry',2)
    check('mixed-Strength-three-hits-before-single-settlement',
          [e[0] for e in a.events].count('chip')==1 and
          [e[4] for e in a.events if e[0]=='hit']==[4,4,4],a.events)
    failed=[x['name'] for x in checks if not x['pass']]
    return {'schema':'DD1-SOURCE-1-CORRECTED-CHECKS-1','native':False,'certificate':False,
            'mutant':mutant,'checks':checks,
            'grid':{'order':'upP,upC,HP,Block,Strength,Weak,Adamant,facet,all remainders; settings 00,01,10,11',
                    'cell_columns':['consumer_legal','preconsumer_OR_guard','consumer_physical_HP_or_null'],
                    'rows_rle':rle(grid),'expanded_trace_sha256':stream.hexdigest()},
            'summary':{'named_checks':len(checks),'q1_contexts':len(grid),'component_cells':len(grid)*4,
                       'peer_substitutions':9,'failed':failed},
            'interpretation':'Transcription, state separation and adverse evidence; source eligibility is a separate author proof, not this return value.'}


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--mutant',choices=('',)+MUTANTS,default='')
    p.add_argument('--export-cells',help='Optional complete deterministic constructed cell traces; never native records.')
    args=p.parse_args()
    if args.export_cells:
        with open(args.export_cells,'w',encoding='utf-8') as f:
            result=run(args.mutant,f)
    else:
        result=run(args.mutant)
    print(canonical(result))
    raise SystemExit(2 if result['summary']['failed'] else 0)
