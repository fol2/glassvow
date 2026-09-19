"""Task-local ELF/DT_NEEDED/version reader. Never executes inspected binaries."""
from pathlib import Path
import hashlib,json,re,subprocess,datetime
ROOT=Path(__file__).resolve().parent
BIN=ROOT/'Godot_v4.7.2-stable_linux.x86_64'
STAGE=ROOT/'runtime';STAGE.mkdir(exist_ok=True)
commands=[]
def readelf(path,*flags):
    argv=['readelf',*flags,str(path)]
    p=subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=15)
    row=dict(argv=argv,exit_code=p.returncode,stdout=p.stdout.decode(),stderr=p.stderr.decode())
    commands.append(row)
    if p.returncode: raise RuntimeError(row)
    return row['stdout']
def inspect(path):
    dyn=readelf(path,'-dW')
    prog=readelf(path,'-lW')
    version=readelf(path,'--version-info')
    needed=re.findall(r'\(NEEDED\).*?\[(.*?)\]',dyn)
    interps=re.findall(r'Requesting program interpreter: (.*?)\]',prog)
    needs={}; definitions=set();current=None;area=None
    for line in version.splitlines():
        if line.startswith('Version definition'): area='def'
        if line.startswith('Version needs'): area='need'
        if area=='def':
            m=re.search(r'Name: (\S+)',line)
            if m: definitions.add(m[1])
        if area=='need':
            m=re.search(r'File: (\S+)',line)
            if m:current=m[1];needs[current]=[]
            m=re.search(r'Name: (\S+)',line)
            if m and current:needs[current].append(m[1])
    return dict(needed=needed,interpreter=interps[0] if interps else None,required_symbol_versions=needs,defined_versions=sorted(definitions))
items={}; queue=[BIN];found={}
while queue:
    original=queue.pop(0);path=original.resolve(strict=True);name=path.name
    if name in items:continue
    raw=path.read_bytes();info=inspect(path)
    info.update(origin_path=str(original),resolved_path=str(path),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),original_nlink=path.stat().st_nlink)
    items[name]=info
    for n in [*info['needed'],*( [info['interpreter']] if info['interpreter'] else [])]:
        candidates=[Path(n)] if n.startswith('/') else [Path(d)/n for d in ['/lib/x86_64-linux-gnu','/usr/lib/x86_64-linux-gnu','/lib64']]
        hits=[x for x in candidates if x.is_file()]
        if not hits:raise RuntimeError('Missing dependency '+n)
        p=hits[0].resolve();found[n]=p.name;queue.append(p)
for name,item in items.items():
    for soname,wanted in item['required_symbol_versions'].items():
        target=items[found[soname]]
        missing=sorted(set(wanted)-set(target['defined_versions']))
        if missing:raise RuntimeError(f'Missing versions for {name}/{soname}: {missing}')
    original=Path(item['resolved_path']);staged=STAGE/name
    raw=original.read_bytes()
    if staged.exists():assert staged.read_bytes()==raw
    elif original!=BIN:staged.write_bytes(raw);staged.chmod(0o400)
    item['staged_path']=str(BIN if original==BIN else staged)
    item['staged_nlink']=Path(item['staged_path']).stat().st_nlink
    assert hashlib.sha256(Path(item['staged_path']).read_bytes()).hexdigest()==item['sha256']
report=dict(operation='DD1-LINUX-ENTRY-1',observed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='STATIC_DT_NEEDED_AND_SYMBOL_VERSION_CLOSURE_ONLY',items=items,closed_dt_needed=True,all_required_symbol_versions_present=True,total_payload_bytes=sum(x['bytes'] for x in items.values()),limitations=['Does not execute engine, loader, ldd, imports, or backend','Does not prove dynamic dlopen closure, plugin/native-extension closure, syscalls, thread count, or runtime compatibility','Staged copies are private regular read-only files, not an admitted B1 root or workload'],engine_launches=0,live_account_writes=0)
(ROOT/'RUNTIME-CLOSURE.json').write_text(json.dumps(report,indent=2)+'\n')
(ROOT/'RUNTIME-READELF-RAW.json').write_text(json.dumps(commands,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='items'},indent=2))
for k,v in items.items():print(k,v['bytes'],v['sha256'],v['needed'])
