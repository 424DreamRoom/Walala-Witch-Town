extends RefCounted
## Each cell references an editable atlas tile; props and collisions stay separate.
const Source = preload("res://Art/Source/aseprite_source.gd")

static func create(source_path: String) -> TileMapLayer:
	Source.install()
	var scene_path := source_path.get_basename() + ".tilemap.tscn"
	if ResourceLoader.exists(scene_path):
		return (load(scene_path) as PackedScene).instantiate() as TileMapLayer
	var path := source_path.get_basename() + ".tiles.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var tiles := TileMapLayer.new()
	tiles.name = "Ground"
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.tile_set = TileSet.new()
	tiles.tile_set.tile_size = Vector2i(data.tile_size, data.tile_size)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = Source.texture(data.atlas)
	atlas.texture_region_size = tiles.tile_set.tile_size
	for id in int(data.tile_count):
		atlas.create_tile(Vector2i(id % int(data.columns), id / int(data.columns)))
	tiles.tile_set.add_source(atlas, 0)
	for y in data.cells.size():
		for x in data.cells[y].size():
			var id := int(data.cells[y][x])
			if id >= 0: tiles.set_cell(Vector2i(x, y), 0, Vector2i(id % int(data.columns), id / int(data.columns)))
	tiles.set_meta("aseprite_atlas", data.atlas)
	tiles.set_meta("map_source", path)
	return tiles
