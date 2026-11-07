extends Node2D
## Root of the game. Builds the areas (farm + town square), spawns players,
## and turns player input into host-side actions.
## Areas live side by side in one world so co-op players can be in different areas.
## Command line: --host, --join=<ip>, --smoke-test

const MARKET_OFFSET := Vector2(5000, 0)

var farm: Farm
var market: Market
var hud: Hud
var players: Dictionary = {}   # peer id -> Player


func _ready() -> void:
	farm = Farm.new()
	farm.name = "Farm"
	add_child(farm)
	market = Market.new()
	market.name = "Market"
	market.position = MARKET_OFFSET
	add_child(market)
	hud = Hud.new()
	add_child(hud)
	farm.message.connect(func(_p, t): hud.show_message(t))
	Clock.players_woke.connect(_on_players_woke)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Inv.ensure(Net.my_id())

	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for a in args:
		if a == "--host":
			Net.host()
		elif a.begins_with("--join="):
			Net.join(a.substr(7))
			return  # the host will spawn us
	_spawn_player(Net.my_id())
	if "--smoke-test" in args:
		SmokeTest.new().run(self)
	for a in args:
		if a.begins_with("--screenshot="):
			_screenshot(a.substr(13))


## Debug helper: sets up a sample farm, saves a screenshot and quits.
func _screenshot(path: String) -> void:
	var me := Net.my_id()
	for x in range(18, 23):
		for y in range(17, 20):
			var c := Vector2i(x, y)
			farm.debris.erase(c)
			farm._perform(me, "hoe", c, "")
			Inv.add(me, "seed_turnip")
			farm._perform(me, "plant", c, "turnip")
			farm.soil[c].age = (x - 18)
			farm.soil[c].ready = x >= 22
			farm.soil[c].wet = y == 18
			farm._refresh(c)
	Economy.add(5000)
	farm._perform(me, "buy_animal", Vector2i.ZERO, "chicken")
	farm._perform(me, "buy_animal", Vector2i.ZERO, "cow")
	local_player().position = farm.door_position() + Vector2(0, 40)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func local_player() -> Player:
	return players.get(Net.my_id())


func _process(_delta: float) -> void:
	hud.refresh(local_player())


func _physics_process(_delta: float) -> void:
	var p := local_player()
	if p == null:
		return
	if p.area == "farm" and farm.exit_to_town(p.position):
		_move_to_area(p, "market")
	elif p.area == "market" and market.exit_to_farm(p.position):
		_move_to_area(p, "farm")


# ---------- players ----------

@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var p := Player.new()
	p.peer_id = peer_id
	p.name = "Player%d" % peer_id
	p.position = farm.door_position() + Vector2(0, 24)
	farm.objects.add_child(p)
	players[peer_id] = p
	p.tool_used.connect(_on_tool_used)
	p.interacted.connect(_on_interacted)


func _on_player_joined(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	Inv.ensure(peer_id)
	_spawn_player.rpc(peer_id)
	for existing: int in players:
		if existing != peer_id:
			_spawn_player.rpc_id(peer_id, existing)
	farm.send_full_state(peer_id)
	Economy.set_copper.rpc_id(peer_id, Economy.copper)


func _on_player_left(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)
	Clock.player_left_bed(peer_id)


func _move_to_area(p: Player, area: String) -> void:
	p.area = area
	if area == "market":
		p.reparent(market.objects, false)
		p.position = market.arrival()
	else:
		p.reparent(farm.objects, false)
		p.position = farm.town_arrival() - Vector2(0, 16)


func _cell_in_front(p: Player) -> Vector2i:
	return farm.cell_at(p.position + Vector2(0, -6)) + p.facing


# ---------- input -> actions ----------

func _on_tool_used(p: Player) -> void:
	if p.area == "market":
		if market.stall_near(p.position) == "butcher":
			farm.butcher(p.peer_id, p.selected_animal(), true)
		return
	var c := _cell_in_front(p)
	match p.tool_name():
		"seeds":
			farm.request_action("plant", c, p.selected_seed())
		var t:
			farm.request_action(t, c)


func _on_interacted(p: Player) -> void:
	if p.area == "market":
		var stall := market.stall_near(p.position)
		match stall:
			"player_stall":
				_request("sell_all", "")
			"seeds":
				_request("buy_seed", p.selected_seed())
			"livestock":
				farm.request_action("buy_animal", Vector2i.ZERO, p.selected_animal())
			"butcher":
				farm.butcher(p.peer_id, p.selected_animal(), false)
			"blacksmith", "carpenter":
				hud.show_message("Tool upgrades and house building are coming soon.")
		return
	if p.position.distance_to(farm.door_position()) < 28:
		_go_to_bed(p)
		return
	var animal := farm.animal_near(p.position, 28.0)
	if animal >= 0:
		farm.collect_from_animal(p.peer_id, animal)
		return
	farm.request_action("harvest", _cell_in_front(p))


func _unhandled_input(event: InputEvent) -> void:
	var p := local_player()
	if p == null:
		return
	if event.is_action_pressed("buy_plot") and p.area == "farm":
		farm.request_action("buy_plot", farm.cell_at(p.position))
	elif event.is_action_pressed("save_game"):
		hud.show_message("Game saved." if SaveGame.save() else "Only the host can save.")
	elif event.is_action_pressed("load_game"):
		hud.show_message("Game loaded." if SaveGame.load_game() else "No save found.")


# ---------- market + bed (host side) ----------

func _request(action: String, arg: String) -> void:
	if multiplayer.is_server():
		_do_request(Net.my_id(), action, arg)
	else:
		_server_request.rpc_id(1, action, arg)


@rpc("any_peer", "call_remote", "reliable")
func _server_request(action: String, arg: String) -> void:
	_do_request(multiplayer.get_remote_sender_id(), action, arg)


func _do_request(peer: int, action: String, arg: String) -> void:
	match action:
		"sell_all":
			var total := 0
			var bag: Dictionary = Inv.bag(peer).duplicate()
			for item: String in bag:
				if DB.is_sellable(item):
					total += DB.sell_price(item, Clock.season) * int(bag[item])
					Inv.remove(peer, item, int(bag[item]))
			if total > 0:
				Economy.add(total)
			farm._tell(peer, "Sold your goods for %s." % Economy.format(total) if total > 0 else "Nothing to sell.")
		"buy_seed":
			var info := DB.crop(arg)
			if info.is_empty():
				return
			if Economy.try_spend(int(info.seed_price)):
				Inv.add(peer, "seed_" + arg)
				farm._tell(peer, "Bought %s." % DB.item_name("seed_" + arg))
			else:
				farm._tell(peer, "Not enough coins.")
		"bed":
			Clock.player_in_bed(peer)


func _go_to_bed(p: Player) -> void:
	p.asleep = true
	p.visible = false
	hud.show_message("Good night! The day ends once everyone is in bed.")
	_request("bed", "")


func _on_players_woke(late_peers: Array) -> void:
	for id: int in players:
		var p: Player = players[id]
		if p.area != "farm":
			_move_to_area(p, "farm")
		p.asleep = false
		p.visible = true
		p.position = farm.door_position() + Vector2(0, 24)
		p.locked_until = Clock.LATE_WAKE if id in late_peers else -1
	if Net.my_id() in late_peers:
		hud.show_message("You stayed up too late and slept in until 7:00 AM.")
