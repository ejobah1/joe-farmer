class_name SmokeTest
## Headless check of the core loop. Run:
##   godot --headless --path . -- --smoke-test

var _fails := 0


func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func sleep_all() -> void:
	Clock.player_in_bed(Net.my_id())


func run(main: Node) -> void:
	var farm: Farm = main.farm
	var me := Net.my_id()
	print("Joe Farmer smoke test")

	# clear land and plant
	var c := Vector2i(18, 14)
	var tools := {"weeds": "scythe", "rock": "pickaxe", "stump": "axe"}
	if farm.debris.has(c):
		farm._perform(me, tools[farm.debris[c]], c, "")
	check(not farm.debris.has(c), "debris cleared with the right tool")
	farm._perform(me, "hoe", c, "")
	check(farm.soil.has(c), "soil tilled")
	farm._perform(me, "plant", c, "turnip")
	check(farm.soil[c].crop == "turnip" and Inv.count(me, "seed_turnip") == 9, "turnip planted, seed used")
	farm._perform(me, "plant", c, "tomato")
	check(farm.soil[c].crop == "turnip", "can't plant twice / out of season")

	# grow: only watered days count
	sleep_all()
	check(Clock.day == 2 and farm.soil[c].age == 0, "unwatered crop does not grow")
	for i in 4:
		farm._perform(me, "water", c, "")
		sleep_all()
	check(farm.soil[c].ready, "turnip ready after 4 watered days (day %d)" % Clock.day)
	farm._perform(me, "harvest", c, "")
	check(Inv.count(me, "turnip") == 1 and farm.soil[c].crop == "", "harvested turnip")

	# sell at the stall
	var before := Economy.copper
	main._do_request(me, "sell_all", "")
	check(Economy.copper == before + 40 and Inv.count(me, "turnip") == 0, "sold turnip for 40c (%s)" % Economy.format(Economy.copper))
	main._do_request(me, "buy_seed", "potato")
	check(Inv.count(me, "seed_potato") == 5 and Economy.copper == before + 40 - 50, "bought potato seed for 50c")
	check(Economy.format(1234567) == "123g 45s 67c", "coin formatting")

	# plots
	Economy.add(100000)
	farm._perform(me, "buy_plot", Vector2i(5, 5), "")
	check(farm.plots.size() == 2 and farm.is_owned(Vector2i(5, 5)), "bought a second plot")

	# animals: buy, collect, breed, butcher
	farm._perform(me, "buy_animal", Vector2i.ZERO, "chicken")
	farm._perform(me, "buy_animal", Vector2i.ZERO, "chicken")
	check(farm._count_species("chicken") == 2, "bought two chickens")
	var first: int = farm.animals.keys()[0]
	farm.collect_from_animal(me, first)
	check(Inv.count(me, "egg") == 1, "collected an egg")
	for i in 20:
		sleep_all()
	var n := farm._count_species("chicken")
	check(n > 2 and n <= 8, "chickens bred up to the pen limit (%d)" % n)
	before = Economy.copper
	farm.butcher(me, "chicken", false)
	check(farm._count_species("chicken") == n - 1 and Economy.copper == before + 600, "sold a chicken wholesale")
	farm.butcher(me, "chicken", true)
	check(Inv.count(me, "poultry") == 2, "processed a chicken into meat")

	# off-season pricing
	check(DB.sell_price("pumpkin", 0) == 480 and DB.sell_price("pumpkin", 2) == 320, "pumpkin sells for more out of season")

	# midnight rule
	Clock.minutes = Clock.MIDNIGHT
	Clock._process(5.0)
	check(Clock.minutes == Clock.MIDNIGHT, "clock freezes at midnight")
	sleep_all()
	check(main.local_player().locked_until == Clock.LATE_WAKE, "late sleeper wakes at 7:00")

	# season change withers crops
	var c2 := Vector2i(20, 14)
	if farm.debris.has(c2):
		farm._perform(me, tools[farm.debris[c2]], c2, "")
	farm._perform(me, "hoe", c2, "")
	farm._perform(me, "plant", c2, "potato")
	Clock.day = Clock.DAYS_PER_SEASON
	var season_before := Clock.season
	sleep_all()
	check(Clock.season == season_before + 1 and farm.soil[c2].crop == "withered", "season changed and crop withered")

	# save + load
	check(SaveGame.save(), "saved")
	farm.soil.erase(c2)
	Economy.add(-1)
	check(SaveGame.load_game() and farm.soil.has(c2) and farm.soil[c2].crop == "withered", "loaded save restores the farm")

	print("RESULT: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	main.get_tree().quit(1 if _fails else 0)
