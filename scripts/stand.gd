extends Node
class_name Stand
## The farm's stand at the town square (consignment selling).
## Players drop goods in at any time. Each night the stand sells part of every
## slot: a full stack takes about 2-3 days to sell. The farm is paid its share
## of the day's sales when the new day starts. Shared by all co-op players.

signal sold(summary: String)

const STACK_SIZE := 99
const START_SLOTS := 6
const SELL_DAYS_MIN := 2.0          # a full stack sells out in 2-3 days on average
const SELL_DAYS_MAX := 3.0
const FARMER_SHARE := 0.9           # the market keeps 10% (unconfirmed with Eliot)

var slots: Array = []               # [{item, count}]
var capacity := START_SLOTS
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("persist")
	Clock.day_started.connect(_on_day_started)


## Host only. Moves every sellable item from a player's bag into the stand.
## Returns how many items were stocked.
func stock_all(peer: int) -> int:
	var moved := 0
	for item: String in Inv.bag(peer).duplicate():
		if DB.is_sellable(item):
			moved += stock(peer, item, Inv.count(peer, item))
	return moved


func stock(peer: int, item: String, n: int) -> int:
	var left := n
	for s: Dictionary in slots:  # top up existing stacks first
		if s.item == item and s.count < STACK_SIZE:
			var add := mini(left, STACK_SIZE - int(s.count))
			s.count += add
			left -= add
	while left > 0 and slots.size() < capacity:
		var add := mini(left, STACK_SIZE)
		slots.append({"item": item, "count": add})
		left -= add
	var moved := n - left
	if moved > 0:
		Inv.remove(peer, item, moved)
	return moved


## Expected items sold per night from one slot.
func daily_rate() -> float:
	return STACK_SIZE / ((SELL_DAYS_MIN + SELL_DAYS_MAX) / 2.0)


func _on_day_started(_d: int, season: int, _y: int) -> void:
	if not multiplayer.is_server():
		return
	var total := 0
	var lines: PackedStringArray = []
	for s: Dictionary in slots:
		var want := int(round(STACK_SIZE / rng.randf_range(SELL_DAYS_MIN, SELL_DAYS_MAX) * rng.randf_range(0.85, 1.15)))
		var n := mini(int(s.count), maxi(want, 1))
		s.count -= n
		total += DB.sell_price(s.item, season) * n
		lines.append("%d %s" % [n, DB.item_name(s.item)])
	slots = slots.filter(func(s): return int(s.count) > 0)
	var paid := int(floor(total * FARMER_SHARE))
	if paid > 0:
		Economy.add(paid)
		sold.emit("Your stand sold %s. You earned %s." % [", ".join(lines), Economy.format(paid)])


func save_key() -> String:
	return "stand"


func save_data() -> Dictionary:
	return {"slots": slots, "capacity": capacity}


func load_data(d: Dictionary) -> void:
	slots = []
	for s: Dictionary in d.slots:
		slots.append({"item": str(s.item), "count": int(s.count)})
	capacity = int(d.capacity)
