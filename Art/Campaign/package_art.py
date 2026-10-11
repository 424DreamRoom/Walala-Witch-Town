"""Package the editable source art, runtime sprites, tiles and content reference."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[1]
target=OUT/'walala_campaign_art.zip'
with ZipFile(target,'w',ZIP_DEFLATED) as archive:
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path.suffix in {'.png','.aseprite','.json','.tres','.py'} and '__pycache__' not in path.parts:
            archive.write(path,'Art/Campaign/'+path.relative_to(OUT).as_posix())
    for name in ['content.json','README.md']:
        archive.write(ROOT/'Scenes/Campaign'/name,'Reference/'+name)
with ZipFile(target) as archive:
    assert archive.testzip() is None
    pngs=sum(x.endswith('.png') for x in archive.namelist())
    sources=sum(x.endswith('.aseprite') for x in archive.namelist())
    assert sources==177 and pngs>=177
print('ART PACKAGE',target,'PNG',pngs,'ASEPRITE',sources,'BYTES',target.stat().st_size)
