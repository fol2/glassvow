"""Inspect existing incomplete transport; never execute native code or certify it.
Delete from the active path once the complete 55-file packet is published.
"""
import hashlib,json,lzma
from pathlib import Path
HERE=Path(__file__).resolve().parent
EXPECTED=['be051195e62289252b149e98076725891552b7e3','7d1619834208d68e0712ddddaf8f54f66a530dc0','022b26e31fef7cfa3f980410123a5e489617d023','5171c138eed893983f437aee52ff010a3083055c','1caf2966b7592357f7e2c130d6fc72d3fa50656d','1524817b8cc77359a8252d0f334c47b7624ca821','fb3c7b996b1806c9095ee2d3641969acd347ef29']
parts=[]
for i,want in enumerate(EXPECTED):
 b=(HERE/f'part-{i:03d}.xzpart').read_bytes()
 actual=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 if actual!=want:raise ValueError('PART_IDENTITY')
 parts.append(b)
dec=lzma.LZMADecompressor(); raw=dec.decompress(b''.join(parts)); text=raw.decode('utf-8',errors='strict')
start=text.index('"nodes":[')+len('"nodes":[')
parser=json.JSONDecoder(); nodes=[]; pos=start
while pos<len(text):
 if text[pos]==']':break
 if text[pos]==',':pos+=1
 try:n,end=parser.raw_decode(text,pos)
 except json.JSONDecodeError:break
 nodes.append(n);pos=end
values=[]
for n in nodes:
 if n[0]=='v':v=n[2]
 elif n[0]=='a':v=[values[i] for i in n[1]]
 elif n[0]=='d':v={values[k]:values[i] for k,i in n[1]}
 else:raise ValueError('NODE_TAG')
 values.append(v)
sequences=[v for v in values if isinstance(v,dict) and v.get('kind')=='sequence']
counts={s:sum(v.get('source')==s for v in sequences) for s in ['bloodRite','preparation','surge']}
result={'kind':'INCOMPLETE_TRANSPORT_PREFIX_DIAGNOSTIC','part_bytes':[len(b) for b in parts],'raw_prefix_bytes':len(raw),'xz_complete':dec.eof,'complete_nodes':len(nodes),'nodes_array_closed':pos<len(text) and text[pos]==']','sequence_nodes_by_source':counts,'tail_after_nodes':text[pos:pos+5000],'prefix_tail':text[-1200:],'native_runs':0,'remote_packet_complete':False}
(HERE/'PREFIX-DIAGNOSTIC.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
