extends "res://Scenes/Storage/verify_grid.gd"
## The regression's original positions assume the expanded house.
func new_chest(state, point: Vector2 = Vector2(400, 384)) -> int:
	state.furniture.house_level = Catalog.House.MAX_LEVEL
	return super.new_chest(state, point)
