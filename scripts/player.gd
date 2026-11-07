extends CharacterBody2D
class_name Player
## A farmer. Movement is driven by whoever owns this node (its peer id);
## world changes are sent to the host through Main.

signal tool_used(player: Player)
signal interacted(player: Player)

const SPEED := 96.0
const TOOLS := ["hoe", "water", "seeds", "scythe", "axe", "pickaxe"]
const TOOL_NAMES := ["Hoe", "Watering Can", "Seeds", "Scythe", "Axe", "Pickaxe"]

var peer_id := 1
var area := "farm"
var tool_index := 0
var seed_index := 0
var animal_index := 0
var facing := Vector2i(0, 1)
var asleep := false
var locked_until := -1        # clock minute when a late sleeper may move again

var _sprite: Sprite2D
var camera: Camera2D


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	_sprite = Tiles.atlas_sprite("res://art/player.png", 0, Vector2i(32, 48))
	add_child(_sprite)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-9, -1), Vector2(9, -1), Vector2(7, 3), Vector2(-7, 3)])
	shadow.color = Color(0.1, 0.1, 0.2, 0.3)
	shadow.show_behind_parent = true
	add_child(shadow)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	if is_local():
		camera = Camera2D.new()
		camera.zoom = Vector2(6, 6)
		add_child(camera)
		camera.make_current()


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func tool_name() -> String:
	return TOOLS[tool_index]


func selected_seed() -> String:
	var seeds := DB.seeds_for_season(Clock.season)
	if seeds.is_empty():
		return ""
	return seeds[seed_index % seeds.size()]


func selected_animal() -> String:
	return DB.animals.keys()[animal_index % DB.animals.size()]


func can_move() -> bool:
	if asleep:
		return false
	if locked_until >= 0 and Clock.minutes < locked_until:
		return false
	return true


func _physics_process(_delta: float) -> void:
	if not is_local():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down") if can_move() else Vector2.ZERO
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			facing = Vector2i(signi(int(signf(dir.x))), 0)
		else:
			facing = Vector2i(0, int(signf(dir.y)))
		_update_frame()
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_sync_pos.rpc(position, facing, area)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _sync_pos(pos: Vector2, f: Vector2i, a: String) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	position = pos
	facing = f
	area = a
	_update_frame()


func _update_frame() -> void:
	var frame := 0
	if facing.y < 0:
		frame = 1
	elif facing.x != 0:
		frame = 2
	_sprite.region_rect = Rect2(frame * 32, 0, 32, 48)
	_sprite.flip_h = facing.x < 0


func _unhandled_input(event: InputEvent) -> void:
	if not is_local():
		return
	if event.is_action_pressed("zoom_in") and camera:
		camera.zoom = Vector2.ONE * minf(camera.zoom.x + 1, 6)
	elif event.is_action_pressed("zoom_out") and camera:
		camera.zoom = Vector2.ONE * maxf(camera.zoom.x - 1, 4)
	if not can_move():
		return
	if event.is_action_pressed("tool_next"):
		tool_index = (tool_index + 1) % TOOLS.size()
	elif event.is_action_pressed("seed_next"):
		seed_index += 1
	elif event.is_action_pressed("animal_next"):
		animal_index = (animal_index + 1) % DB.animals.size()
	elif event.is_action_pressed("use_tool"):
		tool_used.emit(self)
	elif event.is_action_pressed("interact"):
		interacted.emit(self)
	for i in TOOLS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			tool_index = i
