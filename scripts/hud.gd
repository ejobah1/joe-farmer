extends CanvasLayer
class_name Hud
## Placeholder HUD: date, time, coins, tool, seeds, bag and messages.

var _top: Label
var _bottom: Label
var _msg: Label
var _msg_time := 0.0


func _ready() -> void:
	_top = _label(Vector2(24, 16), 28)
	_bottom = _label(Vector2(24, 960), 24)
	_msg = _label(Vector2(24, 900), 26)


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color("#2e1e24"))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func show_message(text: String) -> void:
	_msg.text = text
	_msg_time = 4.0


func refresh(player: Player) -> void:
	if player == null:
		return
	var frozen := "  (midnight: time is frozen, go to bed!)" if Clock.is_frozen() else ""
	_top.text = "%s   %s   %s%s" % [Clock.date_string(), Clock.time_string(), Economy.format(Economy.copper), frozen]
	var seed := player.selected_seed()
	var bag := Inv.bag(player.peer_id)
	var items: PackedStringArray = []
	for item: String in bag:
		items.append("%s x%d" % [DB.item_name(item), bag[item]])
	_bottom.text = "[1-6/Q] %s   [Tab] Seed: %s (x%d)   [R] Animal: %s   [E] interact   [B] buy plot   [F5/F9] save/load\nBag: %s" % [
		Player.TOOL_NAMES[player.tool_index], DB.item_name(seed), Inv.count(player.peer_id, "seed_" + seed), DB.animals[player.selected_animal()].name,
		", ".join(items) if not items.is_empty() else "empty"]


func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg.text = ""
