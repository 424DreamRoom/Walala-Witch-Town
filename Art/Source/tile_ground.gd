extends RefCounted
## Each cell references an editable atlas tile; props and collisions stay separate.
const Source = preload("res://Art/Source/aseprite_source.gd")

static func create(source_path: String, scene_override: String = "") -> TileMapLayer:
	Source.install()
	var scene_path := source_path.get_basename() + ".tilemap.tscn" if scene_override.is_empty() else scene_override
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

static func preview(source_path: String, scene_override: String = "") -> Texture2D:
	var tiles := create(source_path, scene_override)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path.get_basename() + ".tiles.json"))
	var picture := Image.create(int(data.size[0]), int(data.size[1]), false, Image.FORMAT_RGBA8)
	var tile_size := tiles.tile_set.tile_size
	var atlases: Dictionary = {}
	for cell in tiles.get_used_cells():
		var source_id := tiles.get_cell_source_id(cell)
		var atlas: TileSetAtlasSource = tiles.tile_set.get_source(source_id)
		if not atlases.has(source_id): atlases[source_id] = atlas.texture.get_image()
		var region := atlas.get_tile_texture_region(tiles.get_cell_atlas_coords(cell))
		var tile: Image = atlases[source_id].get_region(region)
		var transform := tiles.get_cell_alternative_tile(cell)
		if transform & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
			tile.rotate_90(CLOCKWISE)
			tile.flip_x()
		if transform & TileSetAtlasSource.TRANSFORM_FLIP_H: tile.flip_x()
		if transform & TileSetAtlasSource.TRANSFORM_FLIP_V: tile.flip_y()
		picture.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), cell * tile_size)
	tiles.free()
	return ImageTexture.create_from_image(picture)
