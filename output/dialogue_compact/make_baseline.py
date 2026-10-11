from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
source = (root / "Scenes/UI/game_hud.gd").read_text(encoding="utf-8")
start = source.index('\tvar name_plate :=', source.index('func start_dialogue'))
end = source.index('\tvar text_panel :=', start)
source = source[:start] + '\tvar name_plate := button(speaker,Rect2(152,200,220,22),dialogue_layout,func(): pass)\n\tname_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE\n' + source[end:]
source = source.replace('\tchoices_root = Control.new()\n', '\tbutton("回看",Rect2(520,200,64,22),dialogue_layout,toggle_history,"")\n\tchoices_root = Control.new()\n', 1)
start = source.index('\tchoices_root.name = "DialogueChoices"')
end = source.index('\tdialogue_layout.add_child(choices_root)', start)
source = source[:start] + '\tchoices_root.position = Vector2(364,86 - maxi(0, choices.size() - 3) * 29)\n' + source[end:]
source = source.replace('Rect2(0,i*20,118,18)', 'Rect2(0,i*29,220,25)')
source = source.replace('\t\t\tentry.clip_text = true\n\t\t\tentry.size = Vector2(118,18)\n', '')
(out / "baseline_hud.gd").write_text(source, encoding="utf-8")
