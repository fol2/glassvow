"""Rehydrate v16's declared factors; new hashes, never a claim of the lost bytes."""
import hashlib, json
from copy import deepcopy
from pathlib import Path
ROOT = Path(__file__).resolve().parent
REFERENCE = 'de41f69c9cd28cbd09e16880450957b80675f21b53125cd68a42594e41fbf747'
def build():
    reference = ROOT/'content/fixed.json'
    assert hashlib.sha256(reference.read_bytes()).hexdigest() == REFERENCE
    base = json.loads(reference.read_text())
    records = {}
    def tier(x, cid, rarity):
        for pool in ['common', 'uncommon', 'rare']:
            x['cardPools'][pool] = [v for v in x['cardPools'][pool] if v != cid]
        x['cardPools'][rarity].append(cid)
        x['cards'][cid]['rarity'] = rarity
    for scarce in [False, True]:
        for conditional in [False, True]:
            x = deepcopy(base)
            name = ('scarce' if scarce else 'available')+'_'+('conditional' if conditional else 'reference')
            if scarce:
                tier(x, 'nightSight', 'rare')
                x['relics']['ashenCore']['startSmolder'] = 1
                for fx in x['arts']['ashfall']['effects']:
                    if fx.get('id') == 'poison': fx['n'] = 3
            if conditional:
                for up in [False, True]:
                    def card(cid): return x['cards'][cid]['up'] if up else x['cards'][cid]
                    n, grow = (1, 17) if up else (0, 14)
                    card('momentum')['effects'] = [{'kind':'special','id':'momentum','n':n,'grow':grow},{'kind':'draw','n':1}]
                    card('momentum')['text'] = f'Deal @{n}@ damage. Each play, this card gains +{grow} damage this combat. Draw 1 card.'
                    card('flurry')['effects'] = [{'kind':'dmg','n':int(up),'times':5}]
                    card('flurry')['text'] = f'Deal @{int(up)}@ damage 5 times.'
                    for cid, sid, unit in [('phantomBlades','phantom','card in your hand'),('novaflare','emberNova','Ember in your lantern')]:
                        card(cid)['effects'] = [{'kind':'special','id':sid,'n':8+int(up),'reserve':4}]
                        card(cid)['text'] = f'Deal @{8+int(up)}@ damage for each {unit} above 4.'
                tier(x,'phantomBlades','common')
                tier(x,'resonantLance','uncommon')
            path = ROOT/'content'/f'{name}.json'
            text = json.dumps(x, ensure_ascii=False, indent=2)+'\n'
            path.write_text(text)
            records[name] = {'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'support_contraction':scarce,'conditional_payoff':conditional}
    (ROOT/'RECIPES_RESTORED.json').write_text(json.dumps(records,indent=2)+'\n')
    return records
if __name__ == '__main__':
    print(json.dumps(build(),indent=2))
