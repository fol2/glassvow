"""Source-bound ji implementation refinement; no change to the research policy."""
from __future__ import annotations
import hashlib
from pathlib import Path

REL = Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
REFERENCE = 'ef6f7e6c5c987874b9ee6adc19a5a2733cb220624d246fcbcc2c6a72650d32b2'
FLOAT_BRANCH = ''' if typeof(v)==TYPE_FLOAT:
  var value: float=v
  if value>=-1024.0 and value<=1024.0:
   var whole: int=int(value)
   if value==float(whole):return whole
'''


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def transform(source: bytes) -> bytes:
    require(sha(source) == REFERENCE, 'REFERENCE_SOURCE')
    text = source.decode('utf-8')
    anchor = ' return super.ji(v)\n'
    require(text.count(anchor) == 1 and text.count('func ji(v: Variant) -> int:\n') == 1,
            'EXACT_CONVERSION_ANCHOR')
    refined = text.replace(anchor, FLOAT_BRANCH + anchor, 1)
    require(refined.replace(FLOAT_BRANCH, '', 1) == text, 'UNRELATED_DELTA')
    return refined.encode('utf-8')


def shim(source: bytes) -> bytes:
    """Test only the exact conversion; whole-policy integration is a separate gate."""
    text = source.decode('utf-8')
    marker = 'func ji(v: Variant) -> int:\n'
    require(text.count(marker) == 1, 'SHIM_SOURCE')
    method = marker + text.split(marker, 1)[1]
    require(method.count(' return super.ji(v)\n') == 1, 'SHIM_FALLBACK')
    method = method.replace(' return super.ji(v)\n', ' return int(float(str(v)))\n', 1)
    return ('extends RefCounted\n' + method).encode('utf-8')


def build(repo: Path, target: Path) -> dict:
    source = (repo / REL / 'continuation-integer-v1/bound-source/continuation_cache.gd').read_bytes()
    refined = transform(source)
    require(not target.exists(), 'OUTPUT_EXISTS')
    target.mkdir(parents=True)
    for name, data in [('reference_cache.gd', source), ('continuation_cache.gd', refined),
                       ('reference_ji.gd', shim(source)), ('refined_ji.gd', shim(refined))]:
        (target / name).write_bytes(data)
    return {'reference_sha256': sha(source), 'refined_sha256': sha(refined),
            'change': 'One exactly integral bounded TYPE_FLOAT branch; all other source bytes unchanged.'}
