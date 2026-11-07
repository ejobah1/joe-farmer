extends Node2D
class_name Animal
## A farm animal that wanders inside its pen. Its data lives in Farm.animals;
## this node is only the visual (wandering is local to each player's screen).

var animal_id := 0
var home := Rect2()
var _sprite: Sprite2D
var _target := Vector2.ZERO
var _wait := 0.0
var _speed := 20.0
var _still := false


func setup(info: Dictionary, mature: bool, collected: bool) -> void:
	if _sprite == null:
		_sprite = Tiles.atlas_sprite("res://art/animals.png", int(info.frame), Vector2i(32, 32))
		add_child(_sprite)
	_sprite.modulate = Color(info.color)
	_sprite.scale = Vector2.ONE if mature else Vector2(0.6, 0.6)
	_still = info.id == "bees"
	# a small marker shows a product is ready to collect
	var marker := get_node_or_null("Ready")
	if mature and not collected and marker == null:
		marker = Label.new()
		marker.name = "Ready"
		marker.text = "!"
		marker.position = Vector2(-3, -48)
		marker.add_theme_font_size_override("font_size", 14)
		add_child(marker)
	elif (collected or not mature) and marker != null:
		marker.queue_free()


func _process(delta: float) -> void:
	if _still:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _target == Vector2.ZERO or position.distance_to(_target) < 2.0:
		_target = Vector2(randf_range(home.position.x, home.end.x), randf_range(home.position.y, home.end.y))
		_wait = randf_range(1.0, 4.0)
		return
	var step := (_target - position).normalized() * _speed * delta
	position += step
	if _sprite and absf(step.x) > 0.01:
		_sprite.flip_h = step.x > 0
