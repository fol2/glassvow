"""Lossless transport of generated research JSON, with independent byte checks.

This is a publication codec, never an estimator or evidence generator. It avoids
manual copying of long numeric arrays. An envelope is accepted only if its exact
uncompressed bytes match the recorded size, SHA-256 and Git blob identity.
"""
from pathlib import Path
import base64
import hashlib
import json
import sys
import zlib

FORMAT = 'p9-primary-zlib-v1'
LIMIT = 16 * 1024 * 1024


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def encode(data, filename):
    if len(data) > LIMIT:
        raise ValueError('Publication exceeds transport bound')
    json.loads(data)
    return {'format': FORMAT, 'source_filename': filename,
            'uncompressed_bytes': len(data),
            'sha256': hashlib.sha256(data).hexdigest(), 'git_blob': blob(data),
            'payload': base64.b64encode(zlib.compress(data, 9)).decode('ascii')}


def decode(envelope):
    if envelope.get('format') != FORMAT:
        raise ValueError('Unknown transport format')
    size = envelope['uncompressed_bytes']
    if type(size) is not int or not 0 < size <= LIMIT:
        raise ValueError('Invalid declared byte length')
    compressed = base64.b64decode(envelope['payload'], validate=True)
    d = zlib.decompressobj()
    data = d.decompress(compressed, size + 1)
    if len(data) != size or not d.eof or d.unused_data or d.unconsumed_tail:
        raise ValueError('Incomplete, oversized or concatenated compressed data')
    if hashlib.sha256(data).hexdigest() != envelope['sha256']:
        raise ValueError('SHA-256 mismatch')
    if blob(data) != envelope['git_blob']:
        raise ValueError('Git blob mismatch')
    json.loads(data)
    return data


def load(path):
    data = Path(path).read_bytes()
    obj = json.loads(data)
    if isinstance(obj, dict) and obj.get('format') == FORMAT:
        data = decode(obj)
    return json.loads(data)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('encode', 'decode'):
        raise SystemExit('usage: primary_codec.py encode|decode FILE')
    p = Path(sys.argv[2])
    if sys.argv[1] == 'encode':
        print(json.dumps(encode(p.read_bytes(), p.name), separators=(',', ':')))
    else:
        sys.stdout.buffer.write(decode(json.loads(p.read_bytes())))
