"""Two targeted factors motivated by actual health-loss attribution, not route labels."""
from pathlib import Path
from copy import deepcopy
import json,hashlib
R=Path(__file__).resolve().parent
BASE_SHA='35a0e20202b6a6031773d6252eddd3daa0709bd04e9aa47bea8f8c77e880d922'
def make():
    p=R/'content/scarce_conditional.json'
    assert hashlib.sha256(p.read_bytes()).hexdigest()==BASE_SHA
    base=json.loads(p.read_text());records={}
    for finisher in [False,True]:
        for ashfall in [False,True]:
            name=('both' if finisher and ashfall else 'lighter_finisher' if finisher else 'lighter_ashfall' if ashfall else 'control')
            x=deepcopy(base)
            if finisher:
                c=x['cards']['oblivionStrike'];c['effects'][0]['n']=18;c['up']['effects'][0]['n']=27
                c['text']='Deal @18@ damage. Chip 2 extra Facets.'
                c['up']['text']='Deal @27@ damage. Chip 3 extra Facets.'
            if ashfall:
                for fx in x['arts']['ashfall']['effects']:
                    if fx.get('id')=='poison':fx['n']=1
                x['arts']['ashfall']['text']='Apply 1 Smolder to ALL enemies and gain 5 Ward.'
            path=R/'shortcut_content'/f'{name}.json';path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
            records[name]={'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'finisher_factor':finisher,'ashfall_factor':ashfall}
    (R/'SHORTCUT_RECIPES.json').write_text(json.dumps(records,indent=2)+'\n')
    return records
if __name__=='__main__':print(json.dumps(make(),indent=2))
