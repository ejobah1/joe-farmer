extends Node
## Coins. Stored as a single integer of copper:
## 100 copper = 1 silver, 100 silver = 1 gold.
## In co-op the farm shares one wallet; the host owns it and broadcasts changes.

signal coins_changed(copper: int)

const COPPER_PER_SILVER := 100
const COPPER_PER_GOLD := 100 * COPPER_PER_SILVER
const STARTING_COPPER := 5 * COPPER_PER_SILVER

var copper := STARTING_COPPER


func add(amount: int) -> void:
	set_copper.rpc(copper + amount)


func try_spend(amount: int) -> bool:
	if amount > copper:
		return false
	set_copper.rpc(copper - amount)
	return true


@rpc("authority", "call_local", "reliable")
func set_copper(value: int) -> void:
	copper = value
	coins_changed.emit(copper)


static func format(amount: int) -> String:
	var g := amount / COPPER_PER_GOLD
	var s := (amount / COPPER_PER_SILVER) % 100
	var c := amount % 100
	var parts: PackedStringArray = []
	if g > 0:
		parts.append("%dg" % g)
	if s > 0:
		parts.append("%ds" % s)
	if c > 0 or parts.is_empty():
		parts.append("%dc" % c)
	return " ".join(parts)
