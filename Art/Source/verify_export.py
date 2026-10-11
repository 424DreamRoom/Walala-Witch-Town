"""Exercise editor loading and a real PCK with source files, no PNGs present."""
from pathlib import Path
import json
import shutil
import subprocess
import os
from build_sources import ROOT, godot_bin

FIXTURE = ROOT/('output/aseprite_migration/export_fixture_' + str(os.getpid()))
FIXTURE.mkdir(parents=True,exist_ok=True)
FILES = ['Art/Source/aseprite_source.gd','Art/Source/tile_ground.gd','Art/Source/sheets.json',
         'addons/walala_aseprite/plugin.gd','addons/walala_aseprite/plugin.cfg',
         'Art/UI/NativeIcons/wand.aseprite','MyArt/Icon/Food/bread.aseprite',
         'Art/Character/Storybook/WalalaWitchAseprite32/walala-witch.aseprite',
         'Art/Environment/Hearthwood/home_empty_0.tilemap.tscn',
         'Art/Environment/Hearthwood/Tiles/home_empty_0.tres',
         'Art/Environment/Hearthwood/Tiles/home_empty_0.aseprite']
for relative in FILES:
    target=FIXTURE/relative;target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/relative,target)
(FIXTURE/'project.godot').write_text('''config_version=5
[application]
config/name="Aseprite Source Verification"
run/main_scene="res://main.tscn"
[editor_plugins]
enabled=PackedStringArray("res://addons/walala_aseprite/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf8')
(FIXTURE/'main.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://smoke.gd" id="1"]
[node name="SourceVerification" type="Node"]
script = ExtResource("1")
''',encoding='utf8')
(FIXTURE/'smoke.gd').write_text('''extends Node
const Source = preload("res://Art/Source/aseprite_source.gd")
func _ready() -> void:
    Source.install()
    var wand := Source.texture("res://Art/UI/NativeIcons/wand.aseprite")
    assert(wand.get_width() == 24)
    assert(not FileAccess.file_exists("res://Art/UI/NativeIcons/wand.png"))
    assert(Source.texture("res://MyArt/Icon/Food/bread.aseprite").get_width() > 0)
    var witch := Source.texture("res://Art/Character/Storybook/WalalaWitchAseprite32/walala-witch.aseprite")
    assert(witch.get_size() == Vector2(256, 608))
    assert(witch.get_meta("aseprite_tags").size() == 28)
    var map: TileMapLayer = load("res://Art/Environment/Hearthwood/home_empty_0.tilemap.tscn").instantiate()
    assert(map.get_used_cells().size() > 100)
    assert(map.tile_set.get_source(0).texture.resource_path.ends_with(".aseprite"))
    map.free()
    print("PACKED ASEPRITE SOURCES PASS")
    get_tree().quit()
''',encoding='utf8')
(FIXTURE/'export_presets.cfg').write_text('''[preset.0]
name="Source Test"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.aseprite,*.json"
exclude_filter=""
export_path="source_test.pck"
[preset.0.options]
binary_format/embed_pck=false
''',encoding='utf8')
for label, args in [('editor',['--editor','--quit']),('pack',['--export-pack','Source Test',str(FIXTURE/'source_test.pck')]),('packed',['--main-pack',str(FIXTURE/'source_test.pck')])]:
    p=subprocess.run([godot_bin(),'--headless','--path',str(FIXTURE)]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    text=p.stdout.decode('utf8',errors='replace')
    (FIXTURE.parent/('export_'+label+'.log')).write_text(text,encoding='utf8')
    assert p.returncode == 0 and 'ERROR:' not in text and 'SCRIPT ERROR' not in text,(label,text[-3000:])
    if label=='packed': assert 'PACKED ASEPRITE SOURCES PASS' in text
    print(label,'PASS')
assert not list((FIXTURE/'MyArt').rglob('*.import'))
assert not list((FIXTURE/'MyArt').rglob('*.uid'))
print('EXPORT SOURCE VERIFICATION PASS; PNG-free PCK; original source directory has no sidecars')
