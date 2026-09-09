"""Delivery-only repair: compare the reader's serialized bytes, not int/string keys.
The original run, raw capture, reader, protocol and scientific verdict are immutable.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest


def require(ok, why):
    if not ok:
        raise ValueError(why)


def render(value):
    return (json.dumps(value, indent=2) + '\n').encode()


def check_result(value, recorded):
    require(render(value) == recorded, 'EXACT_SERIALIZED_READOUT_MISMATCH')


class Tests(unittest.TestCase):
    def test_original_failure_is_reproducible(self):
        r = {'paired_discordance': {0: 126, 1: 2}}
        self.assertNotEqual(r, json.loads(render(r)))
        check_result(r, render(r))
    def test_changed_count_is_not_hidden(self):
        with self.assertRaisesRegex(ValueError, 'MISMATCH'):
            check_result({'paired_discordance': {0: 125, 1: 3}}, render({'paired_discordance': {0:126, 1:2}}))
    def test_changed_verdict_is_not_hidden(self):
        with self.assertRaisesRegex(ValueError, 'MISMATCH'):
            check_result({'status':'PASS'}, render({'status':'FAIL'}))
    def test_equal_decoded_but_different_bytes_still_rejected(self):
        with self.assertRaisesRegex(ValueError, 'MISMATCH'):
            check_result({'x':1}, b'{"x":1}')


def verify(repo, source, cold, output):
    repo, source, cold, output = map(Path, (repo, source, cold, output))
    require(not output.exists(), 'OUTPUT_EXISTS')
    entries = json.loads((source/'FILES.json').read_bytes())
    for r in entries:
        p = Path(r['path'])
        require(not p.is_absolute() and '..' not in p.parts, 'MANIFEST_PATH')
        a, b = (source/p).read_bytes(), (cold/p).read_bytes()
        require(a == b and len(a) == r['bytes'] and hashlib.sha256(a).hexdigest() == r['sha256'], 'COLD_BYTE_IDENTITY:'+str(p))
    require((source/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(), 'MANIFEST_IDENTITY')
    reader_path = repo/'research/p9-six-route/guardrail-confirmation-20260909/read_control.py'
    data = reader_path.read_bytes()
    require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()=='2515bcbb7d9dc998d81654882abaa9173cd66c82', 'IMMUTABLE_READER')
    spec=importlib.util.spec_from_file_location('unchanged_reader',reader_path)
    reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
    protocol=json.loads((cold/'RESOLVED-PROTOCOL.json').read_bytes())
    result=reader.analyze(cold/'raw',protocol)
    recorded=(cold/'RESULTS.json').read_bytes()
    check_result(result,recorded)
    original_comparison_failed=result != json.loads(recorded)
    require(original_comparison_failed,'DIAGNOSIS_NOT_REPRODUCED')
    transformed=json.loads(render(result))
    require(transformed==json.loads(recorded),'NORMALIZED_VALUES_DIFFER')
    output.parent.mkdir(parents=True,exist_ok=True)
    receipt={'kind':'BLOODFIRE_SCREEN_COLD_READBACK_WITH_SERIALIZATION_REGRESSION',
             'files_checked':len(entries)+1,'all_bytes_equal':True,'readout_reproduced_byte_for_byte':True,
             'result_sha256':hashlib.sha256(recorded).hexdigest(),'scientific_status':result['status'],
             'rows':result['rows'],'original_failure':'in-memory integer Counter keys compared with JSON string object keys',
             'old_comparison_failure_reproduced':original_comparison_failed,
             'repair':'Compare exactly json.dumps(result,indent=2)+newline bytes, the original writer format. No rounding, projection, source or verdict change.',
             'grids':[{'aspect':r['aspect'],'vow':r['vow'],'baseline_wins':r['baseline_wins'],
                       'candidate_wins':r['candidate_wins'],'n':r['n'],'gates':r['gates']} for r in result['grids']],
             'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    output.write_bytes(render(receipt));print(json.dumps(receipt,sort_keys=True))

if __name__=='__main__':
    if sys.argv[1:] == ['--self-test']: unittest.main(argv=[sys.argv[0]],verbosity=2)
    else: verify(*sys.argv[1:])
