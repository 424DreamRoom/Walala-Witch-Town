extends "res://Scenes/Gameplay/verify_loop.gd"
## Existing two-day assertions unchanged; don't overwrite prior screenshots.
func shot(title: String) -> void:
	if not render: return
	await frames(3)
	RenderingServer.force_draw(false)
	var dir = "res://Sounds/Walala/Verification/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	check("audio regression screenshot " + title, lane.viewport.get_texture().get_image().save_png(dir + title + ".png") == OK)

func check(title: String, ok: bool) -> void:
	super.check(title, ok)
	if title == "settlement credits once":
		super.check("success sounds once per day", loop.audio.counts.get("gather",0) == loop.state.day*2 and loop.audio.counts.get("process",0) == loop.state.day and loop.audio.counts.get("cook",0) == loop.state.day and loop.audio.counts.get("serve",0) == loop.state.day and loop.audio.counts.get("coins",0) == loop.state.day)
