"""Compare the five day-flow failures with the exact prior animation setup.

Only writes comparison fixtures under output/witch-aseprite32/baseline;
never swaps or rewrites live project files.
"""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT / "output/witch-aseprite32/baseline"
BASE.mkdir(parents=True, exist_ok=True)
PREFIX = "res://output/witch-aseprite32/baseline/"

def fixture(source, target, replacements):
    text=(ROOT/source).read_text(encoding="utf-8")
    for before,after in replacements:
        assert before in text, before
        text=text.replace(before,after)
    (BASE/target).write_text(text,encoding="utf-8")

fixture("Scenes/LanternLane/lantern_lane.gd","lane.gd",[
    ('res://Scenes/Gameplay/game_loop.gd',PREFIX+'game_loop.gd')])
fixture("Scenes/Gameplay/game_loop.gd","game_loop.gd",[
    ('res://Scenes/Gameplay/harvest_actions.gd',PREFIX+'harvest_actions.gd')])
fixture("Scenes/Gameplay/harvest_actions.gd","harvest_actions.gd",[
    ('const SHEET := WitchAnimation.SHEET','const SHEET := "res://Art/Character/Storybook/WalalaTools32/witch-tools-32.png"'),
    ('\tWitchAnimation.configure(actor)','\tactor.texture = load(SHEET)\n\tactor.hframes = 5\n\tactor.vframes = 12'),
    ('WitchAnimation.frame_for("cast", loop.lane.facing, FARM_CAST_SECONDS - farm_cast_left, FARM_CAST_SECONDS)',
     '32 + loop.lane.facing * 3 + mini(2, int((FARM_CAST_SECONDS - farm_cast_left) / (FARM_CAST_SECONDS / 3.0)))'),
    ('WitchAnimation.frame_for("cast", row, elapsed, loop.state.swing_seconds(target.resource_kind))',
     '(0 if action == "chop" else 16) + row * 4 + mini(3, int(elapsed / (loop.state.swing_seconds(target.resource_kind) / 4.0)))'),
    ('WitchAnimation.frame_for("fish-cast", row, elapsed, 0.45)','32 + row * 3 + mini(2, int(elapsed / 0.15))'),
    ('WitchAnimation.frame_for("fish-wait", row, elapsed)','44 + row'),
    ('WitchAnimation.frame_for("fish-reel", row, elapsed, 0.6)','48 + row * 3 + mini(2, int(elapsed / 0.2))'),
    ('\tvar fishing_animation := "fish-cast" if action == "cast" else "fish-reel" if action == "reel" else "fish-wait"\n'
     '\tvar animation_seconds := 0.45 if action == "cast" else 0.6 if action == "reel" else 0.0\n'
     '\tvar tip := WitchAnimation.fishing_tip(fishing_animation, loop.lane.facing, elapsed, animation_seconds)',
     '\tvar tip: Vector2 = [Vector2(14, -26), Vector2(12, -29), Vector2(14, -26), Vector2(-15, -26)][loop.lane.facing]')])
fixture("Scenes/Gameplay/verify_harvest.gd","test.gd",[
    ('res://Scenes/LanternLane/lantern_lane.tscn',PREFIX+'lane.tscn'),
    ('Vector2(8, 19)','Vector2(5, 12)')])
(BASE/"lane.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="'+PREFIX+'lane.gd" id="1"]\n[node name="LanternLane" type="Node2D"]\nscript = ExtResource("1")\n',encoding="utf-8")
(BASE/"run.gd").write_text('extends "'+PREFIX+'test.gd"\nfunc _initialize() -> void:\n'
    '\tpreload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "'+PREFIX+'preferences.cfg"\n'
    '\tpreload("res://Scenes/Save/save_store.gd").directory = "'+PREFIX+'saves"\n'
    '\tpreload("res://Scenes/Save/save_store.gd").end_session()\n'
    '\tcapture_output = "'+PREFIX+'captures/"\n\trun.call_deferred()\n',encoding="utf-8")
env=os.environ.copy()
for name in ("APPDATA","LOCALAPPDATA"):
    p=BASE/"profile"/name; p.mkdir(parents=True,exist_ok=True); env[name]=str(p)
info=subprocess.STARTUPINFO(); info.dwFlags|=subprocess.STARTF_USESHOWWINDOW; info.wShowWindow=0
log=BASE/"baseline.log"
with log.open("w",encoding="utf-8") as stream:
    result=subprocess.run(["C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe",
        "--headless","--path",str(ROOT),"--script",PREFIX+"run.gd"],env=env,cwd=ROOT,
        startupinfo=info,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
text=log.read_text(encoding="utf-8",errors="replace")
print("baseline exit=",result.returncode,"PASS=",text.count(": PASS"),"FAIL=",text.count(": FAIL"))
for line in text.splitlines():
    if "FAIL" in line or "ERROR" in line: print(line)
current=(BASE.parent/"harvest.log").read_text(encoding="utf-8",errors="replace")
baseline_failures=[line for line in text.splitlines() if ": FAIL" in line]
current_failures=[line for line in current.splitlines() if ": FAIL" in line]
assert baseline_failures==current_failures and len(baseline_failures)==5, (baseline_failures,current_failures)
print("PASS: the same five day-flow failures occur with prior harvesting art and frame selection")
