"""Verify preserved source and raw bytes without replaying the engine.
Usage: python verify_packet.py STUDY_ROOT EXPECTED_MANIFEST_SHA256 OUTPUT_RECEIPT
The caller supplies the expected manifest from the publication snapshot. Local
verification is not remote preservation: venue is explicitly caller-supplied.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import audit_capture


def main(root, expected, receipt, venue):
    root, receipt = Path(root).resolve(), Path(receipt).resolve()
    audit_capture.require(not receipt.exists(), 'RECEIPT_EXISTS')
    payload = (root/'PACKET-MANIFEST.json').read_bytes()
    audit_capture.require(hashlib.sha256(payload).hexdigest() == expected, 'MANIFEST_BINDING')
    entries = json.loads(payload)
    count = audit_capture.verify_files(root, entries)
    expected_paths = {e['path'] for e in entries}
    found = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    audit_capture.require(found == expected_paths | {'PACKET-MANIFEST.json'}, 'COMPLETE_PACKET_FILE_SET')
    for rel in expected_paths:
        audit_capture.require(not (root/rel).is_symlink(), 'SYMLINK_NOT_PERMITTED')
    with tempfile.TemporaryDirectory(prefix='p9-causal-readback-') as directory:
        recreated = Path(directory)/'audit'
        result = audit_capture.audit(root, recreated)
        for name in ('REVIEW.json','CAUSAL-FIELDS.json'):
            audit_capture.require((recreated/name).read_bytes() == (root/'review-1'/name).read_bytes(), 'AUDIT_BYTE_REPRODUCTION:'+name)
    result = {'kind':'SOURCE_UTILITY_PACKET_BYTE_READBACK', 'venue':venue,
              'manifest_sha256':expected,'files_verified_including_manifest':count+1,
              'frozen_source_reproduced':True,'full_raw_reconstructed':True,
              'original_result_reproduced':True,'causal_fields_reproduced':True,
              'runtime_archive_members_verified':result['runtime_members_verified'],
              'native_invocations':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
              'remote_preservation_claim':False,
              'note':'This executable verifies bytes available to it; remote origin/published commit must be proven by the publisher separately. Venue text is not an attestation.'}
    receipt.parent.mkdir(parents=True,exist_ok=True)
    receipt.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root');parser.add_argument('expected_manifest');parser.add_argument('receipt')
    parser.add_argument('--venue',required=True,choices=('local-cold-checkout','remote-cold-checkout'))
    a=parser.parse_args();main(a.root,a.expected_manifest,a.receipt,a.venue)
