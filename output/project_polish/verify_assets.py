from pathlib import Path
import hashlib
import json
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
art=root/'Art/WorldPolish'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def products():
    return {p.name:digest(p) for p in art.iterdir() if p.suffix in ('.json','.png','.aseprite')}
before=products()
for _ in range(2):
    subprocess.run([sys.executable,str(art/'tools/build_regions.py')],cwd=root,check=True)
    assert products()==before, 'Region build is not deterministic'
original=json.loads((root/'output/project_polish/myart_before.json').read_text(encoding='utf-8-sig'))
after=[{'Path':row['Path'],'Hash':digest(Path(row['Path'])).upper()} for row in original]
assert original==after, 'Protected source hash mismatch'
(root/'output/project_polish/myart_after.json').write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
result={'deterministic_rebuilds':2,'generated_files':len(before),'protected_files':len(after),'protected_hashes_unchanged':True}
(root/'output/project_polish/asset_check.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
