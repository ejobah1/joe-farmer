extends Node
## Static game data: crops and animals, loaded from res://data/*.json.
## Item ids: a crop's harvest uses the crop id ("tomato"), its seed is "seed_<id>".
## Animal products and meat use the ids in animals.json ("egg", "beef"...).

const OFF_SEASON_MULT := 1.5  # goods sell for more out of season

var crops: Dictionary = {}
var animals: Dictionary = {}
var _item_prices: Dictionary = {}  # non-crop item id -> base sell price (copper)


func _ready() -> void:
	crops = _load("res://data/crops.json")
	animals = _load("res://data/animals.json")
	for a: Dictionary in animals.values():
		_item_prices[a.product] = int(a.product_price)
		if a.meat != "":
			_item_prices[a.meat] = int(a.meat_price)


func _load(path: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file %s" % path)
		return out
	var rows: Array = JSON.parse_string(f.get_as_text())
	for row: Dictionary in rows:
		out[row.id] = row
	return out


func crop(id: String) -> Dictionary:
	return crops.get(id, {})


func crop_in_season(id: String, season: int) -> bool:
	var c := crop(id)
	return not c.is_empty() and season in Array(c.seasons).map(func(s): return int(s))


func seeds_for_season(season: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in crops:
		if crop_in_season(id, season):
			out.append(id)
	return out


func is_sellable(item: String) -> bool:
	return crops.has(item) or _item_prices.has(item)


## Fixed price per product; crops are worth more when sold out of their season.
func sell_price(item: String, season: int) -> int:
	if crops.has(item):
		var price := int(crops[item].sell_price)
		if not crop_in_season(item, season):
			price = int(price * OFF_SEASON_MULT)
		return price
	return int(_item_prices.get(item, 0))


func item_name(item: String) -> String:
	if item.begins_with("seed_"):
		return "%s Seeds" % crop(item.substr(5)).get("name", item)
	if crops.has(item):
		return crops[item].name
	return item.capitalize()
