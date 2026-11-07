class_name Tiles
## Builds the ground TileSet from the tiles atlas (32x32 cells in one row).

enum { GRASS, TILLED, WET, PATH, LOCKED, COBBLE }

const SIZE := 32


static func make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/tiles.png")
	src.texture_region_size = Vector2i(SIZE, SIZE)
	for i in 6:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	return ts


static func atlas_sprite(path: String, frame: int, frame_size: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
	s.centered = false
	s.offset = Vector2(-frame_size.x / 2.0, -frame_size.y)  # origin at the feet for y-sorting
	return s
