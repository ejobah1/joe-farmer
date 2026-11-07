extends Node
## Save/load (host only). Every node in the "persist" group provides
## save_key(), save_data() -> Dictionary and load_data(Dictionary).

const PATH := "user://joefarmer_save.json"


func save() -> bool:
	if not multiplayer.is_server():
		return false
	var data := {
		"version": 1,
		"clock": Clock.save_data(),
		"copper": Economy.copper,
		"bags": _stringify_keys(Inv.bags),
		"nodes": {},
	}
	for n in get_tree().get_nodes_in_group("persist"):
		data.nodes[n.save_key()] = n.save_data()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, " "))
	return true


func load_game() -> bool:
	if not multiplayer.is_server() or not FileAccess.file_exists(PATH):
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	Clock.load_data(data.clock)
	Economy.set_copper.rpc(int(data.copper))
	Inv.bags.clear()
	for k: String in data.bags:
		var b := {}
		for item: String in data.bags[k]:
			b[item] = int(data.bags[k][item])
		Inv.bags[int(k)] = b
		Inv._sync(int(k))
	for n in get_tree().get_nodes_in_group("persist"):
		if data.nodes.has(n.save_key()):
			n.load_data(data.nodes[n.save_key()])
	return true


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out
