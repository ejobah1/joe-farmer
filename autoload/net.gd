extends Node
## Co-op networking (2-4 players). The host is authoritative: clients send
## requests, the host changes the world and broadcasts the result.
## Single player runs on Godot's default offline peer, where this machine is the host.

signal player_joined(peer_id: int)
signal player_left(peer_id: int)

const PORT := 24565
const MAX_PLAYERS := 4


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	return OK


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	return OK


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


## Every connected player, host included (only meaningful on the host).
func player_ids() -> Array[int]:
	var ids: Array[int] = [my_id()]
	for p in multiplayer.get_peers():
		ids.append(p)
	return ids


func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_connected):
		multiplayer.peer_connected.connect(_on_connected)
		multiplayer.peer_disconnected.connect(_on_disconnected)


func _on_connected(id: int) -> void:
	player_joined.emit(id)


func _on_disconnected(id: int) -> void:
	player_left.emit(id)
