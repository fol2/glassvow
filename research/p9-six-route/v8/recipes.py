"""Deterministic, order-preserving exploratory content variants; not release candidates."""
from pathlib import Path
from copy import deepcopy
import json, hashlib
BASE = Path(__file__).resolve().parent


def write_json(path, obj):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')


def number(card, field, value, upgrade=False, effect=0):
    obj = card.setdefault('up', {}) if upgrade else card
    if field in ('cost', 'rarity', 'exhaust'):
        obj[field] = value
    else:
        if 'effects' not in obj: obj['effects'] = deepcopy(card['effects'])
        obj['effects'][effect][field] = value


def make():
    original = BASE/'project/content/full-content.json'
    base = json.loads(original.read_text()); result = {'original': original}
    variants = {}
    for name, s in {
        'finite_access': {},
        'combo3': {'ashfall': 3, 'cycle': (2,10), 'multi': (1,3), 'fervor':3},
        'combo4': {'ashfall': 4, 'cycle': (2,10), 'multi': (1,3), 'fervor':3},
        'reserve3': {'ashfall':3,'cycle':(2,10),'multi':(1,3),'fervor':3,'reserve':True},
        'reserve4': {'ashfall':4,'cycle':(2,10),'multi':(1,3),'fervor':3,'reserve':True},
        'reserve4_access': {'ashfall':4,'cycle':(2,10),'multi':(1,3),'fervor':3,'reserve':True,'access':True},
    }.items():
        x = deepcopy(base); c = x['cards']
        number(c['preparation'],'exhaust',True,True)
        number(c['preparation'],'n',3,True)
        c['preparation']['up']['text']='Draw 3 cards. Kindle.'
        for cid in ['quakeblow','resonantLance','nightSight','tithe','pyreheart','novaflare','emberdance']:
            tier=c[cid]['rarity']
            if cid not in x['cardPools'][tier]:x['cardPools'][tier].append(cid)
        for cid in ['empower','flurry','momentum','nightSight']:
            for tier in ['common','uncommon','rare']:
                x['cardPools'][tier]=[z for z in x['cardPools'][tier] if z!=cid]
            x['cardPools']['common'].append(cid);c[cid]['rarity']='common'
        number(c['pyreheart'],'cost',1)
        if 'ashfall' in s:
            for fx in x['arts']['ashfall']['effects']:
                if fx.get('kind')=='status' and fx.get('id')=='poison':fx['n']=s['ashfall']
        if 'cycle' in s:
            n,g=s['cycle']
            for up in (False,True):
                number(c['momentum'],'n',n+(1 if up else 0),up)
                number(c['momentum'],'grow',g+(2 if up else 0),up)
            c['momentum']['text']='Deal @2@ damage. Each play, this card gains +10 damage this combat.'
            c['momentum']['up']['text']='Deal @3@ damage. Each play, this card gains +12 damage this combat.'
        if 'multi' in s:
            n,t=s['multi']
            for up in (False,True):
                number(c['flurry'],'n',n+(1 if up else 0),up)
                number(c['flurry'],'times',t,up)
            c['flurry']['text']='Deal @1@ damage 3 times.';c['flurry']['up']['text']='Deal @2@ damage 3 times.'
        if 'fervor' in s:
            for up in (False,True):number(c['empower'],'n',s['fervor']+(1 if up else 0),up)
            c['empower']['text']='Gain 3 Fervor.';c['empower']['up']['text']='Gain 4 Fervor.'
        if s.get('reserve'):
            for cid, n, reserve in [('phantomBlades',5,3),('novaflare',6,3)]:
                for up in (False,True):
                    number(c[cid],'n',n+(1 if up else 0),up)
                    number(c[cid],'reserve',reserve,up)
                label='card in your hand' if cid=='phantomBlades' else 'Ember in your lantern'
                c[cid]['text']=f'Deal @{n}@ damage for each {label} above {reserve}.'
                c[cid]['up']['text']=f'Deal @{n+1}@ damage for each {label} above {reserve}.'
        if s.get('access'):
            for cid in ['phantomBlades','novaflare','pyreheart','catalyst']:
                for tier in ['common','uncommon','rare']:x['cardPools'][tier]=[z for z in x['cardPools'][tier] if z!=cid]
                x['cardPools']['uncommon'].append(cid);c[cid]['rarity']='uncommon'
        path=BASE/'contents'/f'{name}.json';write_json(path,x);result[name]=path
        variants[name]={'recipe':s,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    write_json(BASE/'contents/recipes.json',variants)
    return result


if __name__=='__main__':
    print({k:str(v) for k,v in make().items()})
