extends Node
## Game clock. Players are awake 5:00 to 24:00. At midnight the clock freezes:
## players can keep working, but anyone who goes to bed at or after midnight
## wakes at 7:00 instead of 5:00. A new day starts once every player is in bed.

signal minute_changed(minutes: int)
signal day_started(day: int, season: int, year: int)
signal season_changed(season: int)
signal players_woke(late_peers: Array)

const DAY_START := 5 * 60
const LATE_WAKE := 7 * 60
const MIDNIGHT := 24 * 60
const DAYS_PER_SEASON := 28
const SEASONS := ["Spring", "Summer", "Fall", "Winter"]

@export var seconds_per_game_minute := 0.7  # one 19-hour day is about 13 real minutes

var minutes := DAY_START
var day := 1
var season := 0
var year := 1
var paused := false

var _acc := 0.0
var _in_bed: Dictionary = {}  # peer id -> went to bed late (bool)


func _process(delta: float) -> void:
	if paused or not multiplayer.is_server() or minutes >= MIDNIGHT:
		return
	_acc += delta
	while _acc >= seconds_per_game_minute and minutes < MIDNIGHT:
		_acc -= seconds_per_game_minute
		_set_time.rpc(minutes + 1, day, season, year)


func is_frozen() -> bool:
	return minutes >= MIDNIGHT


func time_string() -> String:
	var h := (minutes / 60) % 24
	var m := minutes % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


func date_string() -> String:
	return "%s %d, Year %d" % [SEASONS[season], day, year]


## Host only. Call when a player gets into bed.
func player_in_bed(peer_id: int) -> void:
	_in_bed[peer_id] = minutes >= MIDNIGHT
	if _in_bed.size() >= Net.player_ids().size():
		_end_day()


func player_left_bed(peer_id: int) -> void:
	_in_bed.erase(peer_id)


func _end_day() -> void:
	var late: Array = []
	for id: int in _in_bed:
		if _in_bed[id]:
			late.append(id)
	_in_bed.clear()
	var d := day + 1
	var s := season
	var y := year
	if d > DAYS_PER_SEASON:
		d = 1
		s += 1
		if s >= SEASONS.size():
			s = 0
			y += 1
	_acc = 0.0
	_new_day.rpc(d, s, y, late)


@rpc("authority", "call_local", "reliable")
func _set_time(m: int, d: int, s: int, y: int) -> void:
	minutes = m
	day = d
	season = s
	year = y
	minute_changed.emit(minutes)


@rpc("authority", "call_local", "reliable")
func _new_day(d: int, s: int, y: int, late: Array) -> void:
	var changed_season := s != season
	day = d
	season = s
	year = y
	minutes = DAY_START
	if changed_season:
		season_changed.emit(season)
	day_started.emit(day, season, year)
	players_woke.emit(late)
	minute_changed.emit(minutes)


func save_data() -> Dictionary:
	return {"minutes": minutes, "day": day, "season": season, "year": year}


func load_data(d: Dictionary) -> void:
	minutes = int(d.minutes)
	day = int(d.day)
	season = int(d.season)
	year = int(d.year)
	minute_changed.emit(minutes)
