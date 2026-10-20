"""Audit dialogue, refresh authoring metadata, and record the revision scope."""
import collections
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
DRAFT = ROOT / 'Narrative/Rebuild_20261020'
manifest = json.loads((DRAFT / '场景索引.json').read_text(encoding='utf-8'))
runtime = json.loads((ROOT / 'Scenes/Campaign/content.json').read_text(encoding='utf-8'))
report = dict(status='passed', scene_count=11, chapter_count=10, dialogue_lines=0,
              han_characters=0, format_and_instruction_issues=[], repeated_lines=[], scenes=[])
changes = []
texts = []
combined = []
speakers = {'薇尔莉娅':'player','萤萝':'yingluo','奥萝':'orla','陶陶':'toma',
            '露米':'lumi','茉莉':'mori','余烬':'ember','皮普':'pip','澪':'nagi',
            '芦苇':'reed','霜铃':'yuki','星芒':'aster'}
beats = [sum([s['dialogue'] for s in runtime['opening']], [])] + [q['dialogue'] for q in runtime['quests']]
for scene, compiled in zip(manifest['scenes'], beats):
    path = DRAFT / scene['file']
    lines = path.read_text(encoding='utf-8').splitlines()
    old = (OUT / 'before' / path.relative_to(ROOT)).read_text(encoding='utf-8').splitlines()
    assert len(lines) == len(old) == len(compiled)
    count = 0
    for number, (line, previous, beat) in enumerate(zip(lines, old, compiled), 1):
        assert re.fullmatch(r'[^：\s]+：.+', line), (path, number)
        name, text = line.split('：', 1)
        assert beat['speaker'] == speakers[name] and beat['text'] == text, (path, number)
        assert not re.search(r'点击|快捷键|鼠标|按下|走近.*后|按[住动一]|键盘', text), text
        count += len(re.findall(r'[\u3400-\u9fff]', text))
        texts.append(text)
        if line != previous:
            changes.append(dict(scene=scene['id'], line=number, before=previous, after=line))
    report['scenes'].append(dict(id=scene['id'], file=scene['file'], lines=len(lines), han_characters=count))
    report['dialogue_lines'] += len(lines)
    report['han_characters'] += count
    if scene['id'] != 'opening':
        combined += lines
assert (DRAFT / '主线剧情对白.txt').read_text(encoding='utf-8').splitlines() == combined
assert report['dialogue_lines'] == 436
report['repeated_lines'] = [text for text, n in collections.Counter(texts).items() if n > 1]
(DRAFT / '校验记录.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(OUT / 'reviewed_changes.json').write_text(json.dumps(changes, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
manifest['dialogue_tone'] = '日常口语；先回答问题，讲清原因；保留自然停顿和轻松反应，减少刻意机锋、抽象比喻、格言式收尾和集中宣读条款。'
manifest['canon']['protagonist'] = '薇尔莉娅在雾港后厨工作三年，攒钱想自己开一家小食堂。雾港租金太贵，她响应公开招租，提前写信联系后来到山谷。没有隐瞒的身世使命。'
manifest['tone_revision'] = dict(date='2026-10-20', opening_lines_rewritten=43,
    mainline_lines_revised=len([c for c in changes if c['scene'] != 'opening']),
    intro_captions_rewritten=5, quest_briefings_rewritten=10,
    references=[
        dict(game='多洛可小镇', url='https://www.bilibili.com/video/BV1aaMg66Exf/',
             scope='开场初见片段；自然介绍身份，交流当下生活需要。'),
        dict(game='东方夜雀食堂', url='https://www.bilibili.com/video/BV164596sEsT/',
             scope='序章公开预览片段；先聊营业和饭菜，再用直接反应建立熟悉感。')],
    reference_limits='录像只核对了可访问的开场片段，未获得完整对白转录；正文为原创，不转录原作台词。')
(DRAFT / '场景索引.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
originals = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (ROOT / 'MyArt').rglob('*') if p.is_file()}
assert originals == json.loads((OUT / 'originals_before.json').read_text(encoding='utf-8'))
print(json.dumps(dict(dialogue_lines=436, revised_lines=len(changes), manuscript_runtime_match=True,
                     myart_unchanged=True, format_and_instruction_issues=[]), ensure_ascii=False))
