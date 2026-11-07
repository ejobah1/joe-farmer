extends Node2D
class_name Farm
## The player's farm. Holds soil, crops, debris, owned plots and animals.
## All changes happen on the host (see request_action) and are broadcast to clients.

signal message(peer_id: int, text: String)

const T := Tiles.SIZE
const SIZE := Vector2i(48, 36)           # tiles
const PLOT_SIZE := Vector2i(16, 12)      # 3 x 3 plots
const START_PLOT := Vector2i(1, 1)
const PLOT_BASE_PRICE := 25 * Economy.COPPER_PER_SILVER
const HOUSE_CELL := Vector2i(22, 12)     # top-left of the 3x3-tile house
const DOOR_CELL := Vector2i(23, 15)
const PATH_X := 23

var ground: TileMapLayer
var objects: Node2D                       # y-sorted: crops, debris, animals, players

var soil: Dictionary = {}                 # Vector2i -> {wet, crop, age, ready}
var debris: Dictionary = {}               # Vector2i -> "weeds" | "rock" | "stump"
var plots: Dictionary = {START_PLOT: true}
var animals: Dictionary = {}              # int id -> {species, age, collected}

var _next_animal_id := 1
var _sprites: Dictionary = {}             # Vector2i -> Node2D
var _animal_nodes: Dictionary = {}        # int id -> Animal


func _ready() -> void:
	add_to_group("persist")
	ground = TileMapLayer.new()
	ground.tile_set = Tiles.make_tileset()
	add_child(ground)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	var house := Tiles.atlas_sprite("res://art/house.png", 0, Vector2i(96, 96))
	house.position = Vector2(HOUSE_CELL.x * T + 48, (HOUSE_CELL.y + 3) * T)
	objects.add_child(house)
	_scatter_debris()
	for y in SIZE.y:
		for x in SIZE.x:
			_refresh(Vector2i(x, y))
	Clock.day_started.connect(_on_day_started)


func _scatter_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for y in SIZE.y:
		for x in SIZE.x:
			var c := Vector2i(x, y)
			if _is_reserved(c):
				continue
			var r := rng.randf()
			if r < 0.16:
				debris[c] = "weeds"
			elif r < 0.22:
				debris[c] = "rock"
			elif r < 0.26:
				debris[c] = "stump"


func _is_reserved(c: Vector2i) -> bool:
	var in_house := c.x >= HOUSE_CELL.x and c.x < HOUSE_CELL.x + 3 and c.y >= HOUSE_CELL.y and c.y < HOUSE_CELL.y + 3
	return in_house or is_path(c)


# ---------- queries ----------

func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / T), floori(local_pos.y / T))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE.x and c.y < SIZE.y


func is_path(c: Vector2i) -> bool:
	return c.x == PATH_X and c.y >= DOOR_CELL.y


func plot_of(c: Vector2i) -> Vector2i:
	return Vector2i(c.x / PLOT_SIZE.x, c.y / PLOT_SIZE.y)


func is_owned(c: Vector2i) -> bool:
	return plots.has(plot_of(c))


func next_plot_price() -> int:
	return PLOT_BASE_PRICE * plots.size()


func door_position() -> Vector2:
	return cell_center(DOOR_CELL)


func exit_to_town(local_pos: Vector2) -> bool:
	return local_pos.y >= SIZE.y * T - 4


func town_arrival() -> Vector2:
	return Vector2(PATH_X * T + T / 2.0, SIZE.y * T - 24)


# ---------- actions (host authoritative) ----------

## Any player calls this; it runs on the host.
func request_action(action: String, c: Vector2i, arg: String = "") -> void:
	if multiplayer.is_server():
		_perform(multiplayer.get_unique_id(), action, c, arg)
	else:
		_server_action.rpc_id(1, action, c, arg)


@rpc("any_peer", "call_remote", "reliable")
func _server_action(action: String, c: Vector2i, arg: String) -> void:
	_perform(multiplayer.get_remote_sender_id(), action, c, arg)


func _perform(peer: int, action: String, c: Vector2i, arg: String) -> void:
	if action == "buy_plot":
		_buy_plot(peer, c)
		return
	if action == "buy_animal":
		_buy_animal(peer, arg)
		return
	if not in_bounds(c):
		return
	if not is_owned(c):
		_tell(peer, "You don't own this land yet. Press B to buy this plot for %s." % Economy.format(next_plot_price()))
		return
	match action:
		"hoe":
			if debris.has(c) or soil.has(c) or is_path(c) or _is_reserved(c):
				return
			soil[c] = {"wet": false, "crop": "", "age": 0, "ready": false}
		"water":
			if not soil.has(c):
				return
			soil[c].wet = true
		"plant":
			if not soil.has(c) or soil[c].crop != "":
				return
			if not DB.crop_in_season(arg, Clock.season):
				_tell(peer, "%s won't grow in %s." % [DB.item_name(arg), Clock.SEASONS[Clock.season]])
				return
			if not Inv.remove(peer, "seed_" + arg):
				_tell(peer, "You're out of %s." % DB.item_name("seed_" + arg))
				return
			soil[c].crop = arg
			soil[c].age = 0
			soil[c].ready = false
		"scythe":
			if debris.get(c, "") == "weeds":
				debris.erase(c)
				Inv.add(peer, "fiber")
			elif soil.has(c) and soil[c].crop == "withered":
				soil[c].crop = ""
			elif soil.has(c) and soil[c].ready:
				_harvest(peer, c)
			else:
				return
		"harvest":
			if not (soil.has(c) and soil[c].ready):
				return
			_harvest(peer, c)
		"axe":
			if debris.get(c, "") != "stump":
				return
			debris.erase(c)
			Inv.add(peer, "wood", 3)
		"pickaxe":
			if debris.get(c, "") == "rock":
				debris.erase(c)
				Inv.add(peer, "stone", 2)
			elif soil.has(c) and soil[c].crop == "":
				soil.erase(c)
			else:
				return
		_:
			return
	_broadcast_cell(c)


func _harvest(peer: int, c: Vector2i) -> void:
	var id: String = soil[c].crop
	var info := DB.crop(id)
	Inv.add(peer, id)
	var regrow := int(info.regrow_days)
	if regrow > 0:
		soil[c].age = int(info.grow_days) - regrow
		soil[c].ready = false
	else:
		soil[c].crop = ""
		soil[c].age = 0
		soil[c].ready = false


func _buy_plot(peer: int, c: Vector2i) -> void:
	var p := plot_of(c)
	if not in_bounds(c) or plots.has(p):
		return
	var price := next_plot_price()
	if not Economy.try_spend(price):
		_tell(peer, "This plot costs %s." % Economy.format(price))
		return
	plots[p] = true
	_tell(peer, "You bought a new plot!")
	_broadcast_full()


func _buy_animal(peer: int, species: String) -> void:
	var info: Dictionary = DB.animals.get(species, {})
	if info.is_empty():
		return
	if _count_species(species) >= int(info.capacity):
		_tell(peer, "No room for more %s." % info.name)
		return
	if not Economy.try_spend(int(info.price)):
		_tell(peer, "A %s costs %s." % [info.name, Economy.format(int(info.price))])
		return
	_add_animal(species, int(info.mature_days))
	_tell(peer, "A %s is waiting on your farm." % info.name)
	_broadcast_full()


## Collect today's product from a mature animal.
func collect_from_animal(peer: int, id: int) -> void:
	if not multiplayer.is_server():
		_server_collect.rpc_id(1, id)
		return
	var a: Dictionary = animals.get(id, {})
	if a.is_empty():
		return
	var info: Dictionary = DB.animals[a.species]
	if int(a.age) < int(info.mature_days):
		_tell(peer, "This %s is still growing." % info.name)
		return
	if a.collected:
		_tell(peer, "Nothing more today.")
		return
	a.collected = true
	Inv.add(peer, info.product)
	_broadcast_full()


@rpc("any_peer", "call_remote", "reliable")
func _server_collect(id: int) -> void:
	collect_from_animal(multiplayer.get_remote_sender_id(), id)


## Sell (wholesale) or process (fee, returns meat) the first mature animal of a species.
func butcher(peer: int, species: String, process: bool) -> void:
	if not multiplayer.is_server():
		_server_butcher.rpc_id(1, species, process)
		return
	var info: Dictionary = DB.animals.get(species, {})
	for id: int in animals:
		var a: Dictionary = animals[id]
		if a.species == species and int(a.age) >= int(info.mature_days):
			if process:
				if info.meat == "" or not Economy.try_spend(int(info.process_fee)):
					_tell(peer, "Processing costs %s." % Economy.format(int(info.process_fee)))
					return
				Inv.add(peer, info.meat, 2)
			else:
				Economy.add(int(info.wholesale))
			animals.erase(id)
			_tell(peer, "Done.")
			_broadcast_full()
			return
	_tell(peer, "You have no mature %s." % info.get("name", species))


@rpc("any_peer", "call_remote", "reliable")
func _server_butcher(species: String, process: bool) -> void:
	butcher(multiplayer.get_remote_sender_id(), species, process)


func _count_species(species: String) -> int:
	var n := 0
	for a: Dictionary in animals.values():
		if a.species == species:
			n += 1
	return n


func _add_animal(species: String, age: int) -> void:
	animals[_next_animal_id] = {"species": species, "age": age, "collected": false}
	_next_animal_id += 1


func _tell(peer: int, text: String) -> void:
	if peer == multiplayer.get_unique_id():
		message.emit(peer, text)
	else:
		_receive_message.rpc_id(peer, text)


@rpc("authority", "call_remote", "reliable")
func _receive_message(text: String) -> void:
	message.emit(multiplayer.get_unique_id(), text)


# ---------- daily update (host) ----------

func _on_day_started(_day: int, season: int, _year: int) -> void:
	if not multiplayer.is_server():
		return
	for c: Vector2i in soil:
		var s: Dictionary = soil[c]
		if s.crop != "" and s.crop != "withered":
			if not DB.crop_in_season(s.crop, season):
				s.crop = "withered"
				s.ready = false
			elif s.wet and not s.ready:
				s.age += 1
				s.ready = s.age >= int(DB.crop(s.crop).grow_days)
		s.wet = false
	_animals_new_day()
	_broadcast_full()


## Animals grow up, reset their daily product, and breed until the pen is full.
func _animals_new_day() -> void:
	var rng := RandomNumberGenerator.new()
	var adults := {}
	for a: Dictionary in animals.values():
		a.age += 1
		a.collected = false
		if int(a.age) >= int(DB.animals[a.species].mature_days):
			adults[a.species] = adults.get(a.species, 0) + 1
	for species: String in adults:
		var info: Dictionary = DB.animals[species]
		if adults[species] >= 2 and _count_species(species) < int(info.capacity) and rng.randf() < float(info.breed_chance):
			_add_animal(species, 0)


# ---------- sync + visuals ----------

func _broadcast_cell(c: Vector2i) -> void:
	_sync_cell.rpc(c, soil.get(c, {}), debris.get(c, ""))


@rpc("authority", "call_local", "reliable")
func _sync_cell(c: Vector2i, s: Dictionary, d: String) -> void:
	if s.is_empty():
		soil.erase(c)
	else:
		soil[c] = s
	if d == "":
		debris.erase(c)
	else:
		debris[c] = d
	_refresh(c)


func _broadcast_full() -> void:
	_sync_full.rpc(save_data())


## The host sends this to a player who just joined.
func send_full_state(peer: int) -> void:
	_sync_full.rpc_id(peer, save_data())


@rpc("authority", "call_local", "reliable")
func _sync_full(data: Dictionary) -> void:
	load_data(data)


func _refresh(c: Vector2i) -> void:
	var tile := Tiles.GRASS
	if is_path(c):
		tile = Tiles.PATH
	elif soil.has(c):
		tile = Tiles.WET if soil[c].wet else Tiles.TILLED
	elif not is_owned(c):
		tile = Tiles.LOCKED
	ground.set_cell(c, 0, Vector2i(tile, 0))
	if _sprites.has(c):
		_sprites[c].queue_free()
		_sprites.erase(c)
	var node: Node2D = null
	if debris.has(c):
		node = Tiles.atlas_sprite("res://art/debris.png", ["weeds", "rock", "stump"].find(debris[c]), Vector2i(T, T))
	elif soil.has(c) and soil[c].crop != "":
		node = _crop_node(soil[c])
	if node:
		node.position = Vector2(c.x * T + T / 2.0, (c.y + 1) * T - 1)
		objects.add_child(node)
		_sprites[c] = node


func _crop_node(s: Dictionary) -> Node2D:
	if s.crop == "withered":
		return Tiles.atlas_sprite("res://art/crops.png", 5, Vector2i(T, T))
	var grow := int(DB.crop(s.crop).grow_days)
	var frame := 0
	if s.ready:
		frame = 3
	elif int(s.age) >= grow / 2:
		frame = 2
	elif int(s.age) > 0:
		frame = 1
	var node := Tiles.atlas_sprite("res://art/crops.png", frame, Vector2i(T, T))
	if s.ready:
		var fruit := Tiles.atlas_sprite("res://art/crops.png", 4, Vector2i(T, T))
		fruit.modulate = Color(DB.crop(s.crop).color)
		node.add_child(fruit)
	return node


func _rebuild_animals() -> void:
	for id: int in _animal_nodes.keys():
		if not animals.has(id):
			_animal_nodes[id].queue_free()
			_animal_nodes.erase(id)
	for id: int in animals:
		var a: Dictionary = animals[id]
		var info: Dictionary = DB.animals[a.species]
		var node: Animal = _animal_nodes.get(id)
		if node == null:
			node = Animal.new()
			node.animal_id = id
			node.home = Rect2(Vector2(26, 16) * T, Vector2(5, 7) * T)  # placeholder pen until barns exist
			node.position = node.home.get_center() + Vector2(randf_range(-80, 80), randf_range(-40, 40))
			objects.add_child(node)
			_animal_nodes[id] = node
		node.setup(info, int(a.age) >= int(info.mature_days), a.collected)


func animal_near(local_pos: Vector2, radius: float) -> int:
	var best := -1
	var best_d := radius
	for id: int in _animal_nodes:
		var d := local_pos.distance_to(_animal_nodes[id].position)
		if d < best_d:
			best_d = d
			best = id
	return best


# ---------- persistence ----------

func save_key() -> String:
	return "farm"


func save_data() -> Dictionary:
	var s := {}
	for c: Vector2i in soil:
		s["%d,%d" % [c.x, c.y]] = soil[c]
	var d := {}
	for c: Vector2i in debris:
		d["%d,%d" % [c.x, c.y]] = debris[c]
	var p := []
	for c: Vector2i in plots:
		p.append([c.x, c.y])
	var a := {}
	for id: int in animals:
		a[str(id)] = animals[id]
	return {"soil": s, "debris": d, "plots": p, "animals": a, "next_animal_id": _next_animal_id}


func load_data(data: Dictionary) -> void:
	soil.clear()
	for k: String in data.soil:
		var s: Dictionary = data.soil[k]
		soil[_parse(k)] = {"wet": bool(s.wet), "crop": str(s.crop), "age": int(s.age), "ready": bool(s.ready)}
	debris.clear()
	for k: String in data.debris:
		debris[_parse(k)] = str(data.debris[k])
	plots.clear()
	for p: Array in data.plots:
		plots[Vector2i(int(p[0]), int(p[1]))] = true
	animals.clear()
	for k: String in data.animals:
		var a: Dictionary = data.animals[k]
		animals[int(k)] = {"species": str(a.species), "age": int(a.age), "collected": bool(a.collected)}
	_next_animal_id = int(data.next_animal_id)
	for y in SIZE.y:
		for x in SIZE.x:
			_refresh(Vector2i(x, y))
	_rebuild_animals()


func _parse(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
