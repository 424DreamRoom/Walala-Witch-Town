from download_audio import ROOT, fetch
import zipfile, hashlib, json
license_url = 'https://creativecommons.org/publicdomain/zero/1.0/'
entries = []
def save(name, data, title, author, source, download, member=None):
    p = ROOT / name
    if p.exists(): raise FileExistsError(p)
    p.write_bytes(data)
    entries.append(dict(file=name,title=title,author=author,source=source,download=download,archive_member=member,license='CC0 1.0 Universal',license_url=license_url,changes='Original bytes, renamed only; runtime volume/loop settings',sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
for name, title, url, page in [('day_town.mp3','Town','https://opengameart.org/sites/default/files/Town_0.mp3','https://opengameart.org/content/town'),('night_town3.mp3','Town 3','https://opengameart.org/sites/default/files/Town%203_3.mp3','https://opengameart.org/content/town-3')]:
    save(name,fetch(url),title,'Alex McCulloch / Pro Sensory',page,url)
packs = [('interface','https://kenney.nl/assets/interface-sounds','https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip','Kenney', [('gather.ogg','Audio/pluck_001.ogg'),('serve.ogg','Audio/confirmation_001.ogg'),('ui.ogg','Audio/click_001.ogg')]),('rpg','https://kenney.nl/assets/rpg-audio','https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip','Kenney',[('process.ogg','Audio/chop.ogg'),('cook.ogg','Audio/metalPot1.ogg'),('coins.ogg','Audio/handleCoins.ogg')]),('rain','https://opengameart.org/content/rain-loopable','https://opengameart.org/sites/default/files/Rain%20OGG.zip','Ylmir',[('rain.ogg','1.ogg')]),('wind','https://opengameart.org/content/wind','https://opengameart.org/sites/default/files/wind.zip','IgnasD',[('wind.ogg','wind/Wind.ogg')])]
for pack, source, url, author, members in packs:
    with zipfile.ZipFile(ROOT/'Archives'/(pack+'.zip')) as z:
        if 'License.txt' in z.namelist():
            text=z.read('License.txt')
            (ROOT/'Licenses'/(pack+'_License.txt')).write_bytes(text)
            print(text.decode(errors='replace'))
        for name,member in members:
            save(name,z.read(member),pack+' / '+member,author,source,url,member)
(ROOT/'manifest.json').write_text(json.dumps(dict(checked='2026-10-10',assets=entries),ensure_ascii=False,indent=2),encoding='utf-8')
print('Selected',len(entries),'files',sum(e['bytes'] for e in entries),'bytes')
