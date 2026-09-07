"""Fixed optional fuel-versus-energy price factorial; same capped consumer law."""
from pathlib import Path
from copy import deepcopy
import json,hashlib
R=Path(__file__).resolve().parent
EXPECTED={1:'ca7ceca7b8de004be549e8dc1ce8311e34e0faef4577afe35d864c271dc4f1ce',2:'fecf879236b36d781ba350f4e9002fd953bf8f4013d4ebeda996e400e9fe350d'}
def build():
    out={};(R/'content').mkdir(exist_ok=True)
    for production in (1,2):
        raw=(R.parent/'study/capped_content'/f'production{production}_capped.json').read_bytes()
        assert hashlib.sha256(raw).hexdigest()==EXPECTED[production]
        for energy in (0,1):
            x=json.loads(raw);x['cards']['novaflare']['cost']=energy
            if 'cost' in x['cards']['novaflare']['up']:x['cards']['novaflare']['up']['cost']=energy
            name=f'production{production}_energy{energy}'
            b=raw if energy==1 else (json.dumps(x,ensure_ascii=False,indent=2)+'\n').encode()
            p=R/'content'/(name+'.json');p.write_bytes(b)
            out[name]={'path':str(p),'sha256':hashlib.sha256(b).hexdigest(),'production':production,'energy':energy}
    (R/'content/manifest.json').write_text(json.dumps(out,indent=2)+'\n');return out
if __name__=='__main__':print(json.dumps(build(),indent=2))
