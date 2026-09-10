"""Research-only Hand effect views with unchanged default-on game and controller."""
import hashlib
import re

COMBAT = '3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0'
PUBLIC = '5fa5655a93b06d05ad88d8b7a8bff2f93fac44e0'
OBSERVER = 'f1a60da814b2eff8b5c10bc7d2ce29e00d12268f'
FLAGS = ('hand_preparation_enabled','hand_surge_enabled','hand_phantom_enabled')
BODY = '''func card_data(inst: CardInst) -> Dictionary:
\tvar original: Dictionary = _hand_original_card_data(inst)
\tvar id: String = String(inst.id)
\tvar suppress_draw: bool = (id == "preparation" and not hand_preparation_enabled) or (id == "surge" and not hand_surge_enabled)
\tvar suppress_payoff: bool = id == "phantomBlades" and not hand_phantom_enabled
\tif not suppress_draw and not suppress_payoff:
\t\treturn original
\tvar result: Dictionary = original.duplicate(true)
\tvar effects: Array = []
\tfor effect: Dictionary in result.get("effects", []):
\t\tif suppress_draw and str(effect.get("kind", "")) == "draw":
\t\t\tcontinue
\t\tif suppress_payoff and str(effect.get("kind", "")) == "special" and str(effect.get("id", "")) == "phantom":
\t\t\teffect["n"] = 0
\t\teffects.append(effect)
\tresult["effects"] = effects
\treturn result

'''


def require(ok,why):
    if not ok: raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()


def once(s,old,new):
    require(s.count(old)==1,'ANCHOR:'+old[:50])
    return s.replace(old,new,1)


def functions(s):
    found=list(re.finditer(r'^(?:static )?func (\w+)\(',s,re.M))
    require(len({m[1] for m in found})==len(found),'DUPLICATE_FUNCTION')
    return {m[1]:s[m.start():found[i+1].start() if i+1<len(found) else len(s)].strip()
            for i,m in enumerate(found)}


def patch(combat,public,observer):
    require(sha(combat)==COMBAT and blob(public)==PUBLIC and blob(observer)==OBSERVER,'INPUT_IDENTITIES')
    c0,p0,o0=(b.decode() for b in (combat,public,observer))
    c=once(c0,'var content: ContentDB',''.join('var '+f+': bool = true\n' for f in FLAGS)+'var content: ContentDB')
    c=once(c,'func card_data(inst: CardInst) -> Dictionary:',BODY+'func _hand_original_card_data(inst: CardInst) -> Dictionary:')
    p=once(p0,'"bloodfire_consumer_enabled"]','"bloodfire_consumer_enabled", '+', '.join('"'+f+'"' for f in FLAGS)+']')
    o=once(o0,'\tg.last_ret = clone_value(last_ret, memo)\n\treturn g',
           '\tg.last_ret = clone_value(last_ret, memo)\n\tfor flag: String in ['+', '.join('"'+f+'"' for f in ('bloodfire_enabled','bloodfire_producer_enabled','bloodfire_consumer_enabled',*FLAGS))+']:\n\t\tg.rules.set(flag, rules.get(flag))\n\treturn g')
    before,after=functions(c0),functions(c)
    require(set(after)==set(before)|{'_hand_original_card_data'},'FUNCTION_SET')
    require(all(after[k]==v for k,v in before.items() if k!='card_data'),'UNRELATED_FUNCTION_CHANGED')
    require(after['_hand_original_card_data']==before['card_data'].replace('func card_data(', 'func _hand_original_card_data(',1),'ORIGINAL_RESOLUTION')
    require('inst.uid' not in BODY and 'inst.id' in BODY,'INSTANCE_GENERALITY')
    return c.encode(),p.encode(),o.encode()
