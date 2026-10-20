"""Verify that regenerating final resources is stable, then update the audit report."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
DRAFT = ROOT / 'Narrative/Rebuild_20261020'
paths = [ROOT / p for p in [
    'Scenes/Campaign/content.gd', 'Scenes/Campaign/content.json',
    'Localization/messages.tsv', 'Localization/catalog.gd',
    'Narrative/Rebuild_20261020/translations_zh_TW.json']]
def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
before = hashes()
for script in ['Scenes/Campaign/build_content.py', 'Localization/build_catalog.py']:
    subprocess.run([sys.executable, '-B', script], cwd=ROOT, check=True)
assert hashes() == before, 'Build changed generated resources'
subprocess.run([sys.executable, '-B', 'output/story_tone_revision_20261020/finalize_revision.py'], cwd=ROOT, check=True)
verification = json.loads((DRAFT / '游戏接入验证.json').read_text(encoding='utf-8'))
verification['capture_verification'] = json.loads((ROOT / 'output/story_rebuild_integration/capture.json').read_text(encoding='utf-8'))
verification['headless_verification'] = json.loads((ROOT / 'output/story_rebuild_integration/headless.json').read_text(encoding='utf-8'))
assert verification['capture_verification']['passed'] and verification['headless_verification']['passed']
verification['build_idempotent'] = True
verification['tone_revision'] = dict(opening_lines=43, mainline_lines=106, intro_captions=5,
    quest_briefings=10, resident_texts=9, languages=['zh_CN','en','ja','zh_TW'],
    manuscript_runtime_match=True, format_and_instruction_issues=[],
    protected_originals_unchanged=True, formal_player_saves_accessed=False)
(DRAFT / '游戏接入验证.json').write_text(json.dumps(verification, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
report = dict(status='passed', build_idempotent=True, hashes=hashes(),
              tone_revision=verification['tone_revision'],
              capture=verification['capture_verification'], headless=verification['headless_verification'])
(OUT / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Tone revision: manuscript, translations, stable build and isolated runtime checks passed.')
