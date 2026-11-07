extends Node
## Registers every input action in code so the project needs no hand-edited input map.

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"use_tool": [KEY_SPACE, KEY_J],
	"interact": [KEY_E, KEY_K],
	"tool_next": [KEY_Q],
	"seed_next": [KEY_TAB],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"buy_plot": [KEY_B],
	"animal_next": [KEY_R],
	"save_game": [KEY_F5],
	"load_game": [KEY_F9],
}


func _ready() -> void:
	for action: String in KEYS:
		_ensure(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for i in range(1, 7):
		var action := "slot_%d" % i
		_ensure(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_0 + i
		InputMap.action_add_event(action, ev)
	_mouse("use_tool", MOUSE_BUTTON_LEFT)
	_mouse("interact", MOUSE_BUTTON_RIGHT)
	_mouse("zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_mouse("zoom_out", MOUSE_BUTTON_WHEEL_DOWN)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _mouse(action: String, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
