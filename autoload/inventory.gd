extends Node
## Per-player bags (peer id -> {item id: count}). The host owns all bags and
## sends each player a copy of their own bag when it changes.

signal changed(peer_id: int)

const STARTING_ITEMS := {"seed_turnip": 10, "seed_potato": 4}

var bags: Dictionary = {}


func ensure(peer_id: int) -> void:
	if not bags.has(peer_id):
		bags[peer_id] = STARTING_ITEMS.duplicate()
		_sync(peer_id)


func bag(peer_id: int) -> Dictionary:
	return bags.get(peer_id, {})


func count(peer_id: int, item: String) -> int:
	return int(bag(peer_id).get(item, 0))


func add(peer_id: int, item: String, n: int = 1) -> void:
	ensure(peer_id)
	bags[peer_id][item] = count(peer_id, item) + n
	_sync(peer_id)


func remove(peer_id: int, item: String, n: int = 1) -> bool:
	if count(peer_id, item) < n:
		return false
	bags[peer_id][item] -= n
	if bags[peer_id][item] <= 0:
		bags[peer_id].erase(item)
	_sync(peer_id)
	return true


func _sync(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		changed.emit(peer_id)
	else:
		_receive.rpc_id(peer_id, bags[peer_id])


@rpc("authority", "call_remote", "reliable")
func _receive(contents: Dictionary) -> void:
	bags[multiplayer.get_unique_id()] = contents
	changed.emit(multiplayer.get_unique_id())
