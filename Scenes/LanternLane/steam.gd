extends Node2D
var time := 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	for source in [Vector2(409,163), Vector2(469,163), Vector2(150,172)]:
		for i in range(5):
			var age := fmod(time * 0.36 + i * 0.2, 1.0)
			var p: Vector2 = source + Vector2(sin(age * 7 + source.x) * 3, -age * 22)
			draw_rect(Rect2(p.round(), Vector2(3 + int(age * 3),2)), Color(0.9,0.86,0.68,(1-age)*0.36))
