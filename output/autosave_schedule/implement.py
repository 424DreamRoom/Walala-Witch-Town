from pathlib import Path
import re
base=Path('output/autosave_schedule');base.mkdir(exist_ok=True)
(base/'.gdignore').touch()
Path('output/recovery/.gdignore').touch()
def edit(relative,pairs):
 p=Path(relative);old=p.read_bytes();s=old.decode('utf-8').replace('\r\n','\n')
 for before,after in pairs:
  if before.startswith('\tif autosave_left <='):
   match=re.search(r'\tif autosave_left <=[^\n]*\n[\s\S]*?\t\tautosave_left = 30\.0',s)
   assert match,relative
   before=match.group()
  assert before in s,(relative,before[:100])
  s=s.replace(before,after,1)
 assert s and len(s)>len(old.decode('utf-8'))/2
 backup=base/'before'/relative
 backup.parent.mkdir(parents=True,exist_ok=True)
 if not backup.exists():backup.write_bytes(old)
 assert p.read_bytes()==old,(relative,'concurrent edit')
 p.write_bytes(s.encode('utf-8'))
edit('Scenes/Gameplay/game_loop.gd',[
 ('var autosave_left := 30.0','const AUTOSAVE_INTERVAL_MINUTES := 6.0 * 60.0\nconst AUTOSAVE_RETRY_SECONDS := 30.0\nvar next_autosave_at := 0.0\nvar autosave_retry_left := 0.0'),
 ('\t_sync_phase()\n\trestoring_save = false','\t_sync_phase()\n\t_schedule_next_autosave()\n\trestoring_save = false'),
 ('\tif result.ok:\n\t\tautosave_left = 30.0\n\treturn result\n\nfunc _autosave() -> void:\n\tif restoring_save or Saves.active_slot == 0 or save_menu == null:\n\t\treturn\n\tsave_menu.report_save(save_progress(), true)',
  '\tif result.ok:\n\t\t_schedule_next_autosave()\n\treturn result\n\nfunc _game_time_minutes() -> float:\n\treturn (state.day - 1) * 1440.0 + state.get_time_minutes()\n\nfunc _schedule_next_autosave() -> void:\n\t# Fixed 06:00 / 12:00 / 18:00 / 24:00 boundaries also survive loading.\n\t# Manual saves between boundaries do not postpone the next automatic save.\n\tnext_autosave_at = (floori(_game_time_minutes() / AUTOSAVE_INTERVAL_MINUTES) + 1) * AUTOSAVE_INTERVAL_MINUTES\n\tautosave_retry_left = 0.0\n\nfunc _autosave() -> void:\n\t# Gameplay events share this gate and never cause extra writes.\n\tif restoring_save or Saves.active_slot == 0 or save_menu == null:\n\t\treturn\n\tif paused_for_test or get_tree().paused or harvest.busy() or autosave_retry_left > 0.0:\n\t\treturn\n\tif _game_time_minutes() < next_autosave_at:\n\t\treturn\n\tvar result := save_progress()\n\tsave_menu.report_save(result, true)\n\tif not result.ok:\n\t\t# Leave the boundary pending without retrying a failed write every frame.\n\t\tautosave_retry_left = AUTOSAVE_RETRY_SECONDS'),
 ('\t\t\tautosave_left -= delta','\t\t\tautosave_retry_left = maxf(0.0, autosave_retry_left - delta)'),
 ('\tif autosave_left <= 0.0 and not harvest.busy() and not paused_for_test:\n\t\tif last_phase == state.phase:\n\t\t_autosave()\n\t\t# On disk errors retry after a delay instead of writing every frame.\n\t\tautosave_left = 30.0','\tif last_phase == state.phase:\n\t\t_autosave()'),
 ('\taudio.set_context(state.phase, location, lane.weather.get_weather())\n\tif state.message != last_message:','\taudio.set_context(state.phase, location, lane.weather.get_weather())\n\t_autosave()\n\tif state.message != last_message:'),
 ('\t\tif state.phase == "result":\n\t\t\taudio.reset_footsteps()\n\t\tif state.phase == "result":\n\t\t\taudio.reset_footsteps()\n','\t\tif state.phase == "result":\n\t\t\taudio.reset_footsteps()\n'),
 ('\tif world_data.location != "town":\n\t\tenter(world_data.location)','\tif world_data.location != "town":\n\t\tvar was_restoring := restoring_save\n\t\trestoring_save = true\n\t\tenter(world_data.location)\n\t\trestoring_save = was_restoring'),
 ('\t\tmenu_buttons[i].text = I18n.format("%s  %d金", [state.DISHES[i], state.PRICES[i]])\n\t\tcook_buttons[i].text = I18n.format("做%s", [state.DISHES[i]])\n',''),
 ('\tfor i in range(3):\n\t\tmenu_buttons[i].visible = show_menu','\tfor i in range(3):\n\t\tmenu_buttons[i].text = I18n.format("%s  %d金", [state.DISHES[i], state.PRICES[i]])\n\t\tcook_buttons[i].text = I18n.format("做%s", [state.DISHES[i]])\n\t\tmenu_buttons[i].visible = show_menu'),
])
edit('Scenes/Campaign/campaign_controller.gd',[
 ('\tif preload("res://Scenes/Save/save_store.gd").active_slot > 0:\n\t\tvar result: Dictionary = loop.save_progress()\n\t\tif not result.ok:\n\t\t\tloop.state.campaign.player_name = ""\n\t\t\tnaming.show_save_error(result.get("code", "invalid"))\n\t\t\treturn\n','\t# Naming follows the normal six-hour / manual / exit save schedule.\n')
])
edit('Scenes/Save/verify_saving_indicator.gd',[
 ('check("initial autosave cue finishes", not indicator.visible)','check("map change does not start a save cue", not indicator.visible)'),
 ('loop._autosave()','loop.save_progress()'),('loop._autosave()','loop.save_progress()')
])
edit('Scenes/Save/verify_saves.gd',[
 ('loop.autosave_left = 0.0','loop.state.remaining = State.DAY_SECONDS * 0.5 + 0.025'),
 ('\tloop.end_phase()\n\tcheck("phase transition autosaves",','\tloop.paused_for_test = false\n\tloop.end_phase()\n\tloop._autosave()\n\tloop.paused_for_test = true\n\tcheck("18:00 boundary autosaves",'),
 ('\tloop.end_phase()\n\tcheck("settlement autosaves",','\tloop.paused_for_test = false\n\tloop.end_phase()\n\tloop._autosave()\n\tcheck("24:00 boundary autosaves",'),
 ('\tloop.end_phase()\n\tcheck("next day autosaves",','\tloop.end_phase()\n\tloop._autosave()\n\tloop.paused_for_test = true\n\tcheck("next day 06:00 boundary autosaves",')
])
edit('Scenes/Equipment/verify_equipment.gd',[
 ('check("NPC purchase autosaves ranks", Saves.read_slot(1).data.state.equipment == loop.state.equipment)','check("NPC purchase waits for scheduled save", Saves.read_slot(1).data.state.equipment != loop.state.equipment)\n\tcheck("manual save preserves purchased ranks", loop.save_progress().ok and Saves.read_slot(1).data.state.equipment == loop.state.equipment)')
])
edit('Scenes/Storage/verify_storage.gd',[
 ('check("storage autosave preserves items and upgraded tool", Saves.read_slot(1).ok and','check("manual save preserves items and upgraded tool", loop.save_progress().ok and Saves.read_slot(1).ok and')
])
edit('Scenes/Storage/verify_grid.gd',[
 ('check("autosave preserves exact positions", Saves.read_slot(1).ok and','check("manual save preserves exact positions", loop.save_progress().ok and Saves.read_slot(1).ok and')
])
print('Six-hour schedule implemented with current file backups and concurrency guards.')