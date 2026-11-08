extends Node2D
class_name Market
## The town square: a separate area the player travels to.
## Placeholder stalls until the PixelLab art is ready.

const T := Tiles.SIZE
const SIZE := Vector2i(30, 18)

## id -> [label, cell, color]
const STALLS := {
	"player_stall": ["Your Stand (drop goods)", Vector2i(5, 6), Color("#d8b04a")],
	"seeds": ["Seed Vendor", Vector2i(11, 6), Color("#5ea63c")],
	"blacksmith": ["Blacksmith", Vector2i(17, 6), Color("#6e6670")],
	"carpenter": ["Carpenter", Vector2i(23, 6), Color("#a8693a")],
	"livestock": ["Livestock Dealer", Vector2i(8, 12), Color("#c8b8a0")],
	"butcher": ["Butcher", Vector2i(20, 12), Color("#a8463a")],
}

var objects: Node2D
var stand: Stand


func _ready() -> void:
	stand = Stand.new()
	stand.name = "Stand"
	add_child(stand)
	var ground := TileMapLayer.new()
	ground.tile_set = Tiles.make_tileset()
	add_child(ground)
	for y in SIZE.y:
		for x in SIZE.x:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(Tiles.PATH if x == 15 and y < 3 else Tiles.COBBLE, 0))
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	for id: String in STALLS:
		var s: Array = STALLS[id]
		var stall := Node2D.new()
		stall.position = Vector2(s[1].x * T + T / 2.0, (s[1].y + 1) * T)
		var body := ColorRect.new()
		body.color = s[2]
		body.size = Vector2(64, 40)
		body.position = Vector2(-32, -40)
		stall.add_child(body)
		var label := Label.new()
		label.text = s[0]
		label.add_theme_font_size_override("font_size", 8)
		label.position = Vector2(-32, -54)
		stall.add_child(label)
		objects.add_child(stall)


func stall_near(local_pos: Vector2, radius: float = 40.0) -> String:
	for id: String in STALLS:
		var c: Vector2i = STALLS[id][1]
		var p := Vector2(c.x * T + T / 2.0, (c.y + 1) * T + 12)
		if local_pos.distance_to(p) < radius:
			return id
	return ""


func arrival() -> Vector2:
	return Vector2(15 * T + T / 2.0, 2 * T)


func exit_to_farm(local_pos: Vector2) -> bool:
	return local_pos.y <= 4
