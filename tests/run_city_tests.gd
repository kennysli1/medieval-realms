extends SceneTree

const Simulation = preload("res://src/city/city_simulation.gd")
const Save = preload("res://src/city/city_save.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	test_economy_and_pause()
	test_building_and_refunds()
	test_road_interruption()
	test_save_continuity()
	test_corrupt_save()
	print("City checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func fresh() -> RefCounted:
	var sim = Simulation.new()
	sim.start_new()
	return sim

func advance(sim: RefCounted, seconds: float) -> void:
	for i in range(int(seconds * 10)):
		sim.update(0.1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func test_economy_and_pause() -> void:
	var sim = fresh()
	for b in sim.buildings:
		check(sim.connected(b), "Initial building connected: " + b.kind)
	var initial: Dictionary = sim.inventory.duplicate()
	advance(sim, 2.0)
	check(sim.deliveries == 0, "Walking to jobs cannot create stock")
	advance(sim, 120.0)
	check(sim.deliveries > 10, "Workers complete real deliveries")
	check(sim.inventory.planks > initial.planks, "Sawmill turns wood into planks")
	check(sim.inventory.food > 0, "Farm supplies food")
	var previous: Dictionary = sim.export_state()
	sim.speed = 0.0
	advance(sim, 10.0)
	check(sim.export_state() == previous, "Pause freezes economy, travel and production")
	var fast = fresh()
	fast.speed = 4.0
	advance(fast, 10.0)
	check(is_equal_approx(fast.time, 40.0), "Four-times speed advances game time")
	check(not sim.set_road(Vector2i(13, 10), true), "Road cannot cross keep")
	check(sim.place_building("house", Vector2i(13, 10)) == -1, "Overlapping construction rejected")
	check(sim.place_building("house", Vector2i(31, 31)) == -1, "Outside map rejected")
	check(sim.place_building("house", Vector2i(17, 14)) == -1, "Warehouse entrance stays clear")

func building_only() -> RefCounted:
	var sim = fresh()
	for id in [5, 6, 7]:
		sim.demolish(id)
	return sim

func wood_accounted(sim: RefCounted) -> float:
	var total := float(sim.inventory.wood)
	for b in sim.buildings:
		total += b.reserved.get("wood", 0) + b.delivered.get("wood", 0)
	for c in sim.citizens:
		total += c.cargo.get("wood", 0)
	return total

func test_building_and_refunds() -> void:
	var sim = building_only()
	var stock: float = sim.inventory.wood
	var id: int = sim.place_building("house", Vector2i(8, 17))
	check(id > 0, "Place new house")
	check(sim.inventory.wood == stock - 12, "Placement reserves materials")
	check(sim.by_id(id).complete == false, "Placement is not instant construction")
	sim.demolish(id)
	check(sim.inventory.wood == stock, "Cancellation refunds reserved materials")
	id = sim.place_building("house", Vector2i(8, 17))
	check(sim.connect_building(id), "Automatic road connector reaches warehouse")
	var saw_cargo := false
	for i in range(400):
		sim.update(0.1)
		for c in sim.citizens:
			if c.workplace == id and not c.cargo.is_empty():
				saw_cargo = true
		if saw_cargo:
			break
	check(saw_cargo, "Builder physically picks up reserved materials")
	check(is_equal_approx(wood_accounted(sim), stock), "Materials conserved in transit")
	sim.demolish(id)
	advance(sim, 80.0)
	check(is_equal_approx(sim.inventory.wood, stock), "In-transit cancellation returns goods exactly once")
	id = sim.place_building("house", Vector2i(8, 17))
	sim.connect_building(id)
	advance(sim, 80.0)
	check(sim.by_id(id).complete, "Connected construction finishes through builder work")
	check(sim.population_capacity() == 36, "Completed housing adds capacity")
	check(is_equal_approx(sim.inventory.wood, stock - 12), "Completed construction consumes materials once")
	check(not sim.demolish(1) and not sim.demolish(2), "Core keep and warehouse are protected")

func test_road_interruption() -> void:
	var sim = fresh()
	advance(sim, 3.0)
	var b: Dictionary = sim.by_id(6)
	sim.set_road(b.entry, false)
	check(not sim.connected(b), "Removing entrance disconnects industry")
	check(sim.building_status(b) == "道路未接通", "Disconnected industry reports cause")
	var stock: float = sim.inventory.planks
	advance(sim, 90.0)
	check(sim.inventory.planks == stock, "Disconnected sawmill cannot deliver planks")
	sim.set_road(b.entry, true)
	advance(sim, 90.0)
	check(sim.inventory.planks > stock, "Restoring road resumes production")

func test_save_continuity() -> void:
	var original = fresh()
	var id: int = original.place_building("house", Vector2i(8, 17))
	original.connect_building(id)
	advance(original, 15.0)
	var json: Variant = JSON.parse_string(JSON.stringify(original.export_state()))
	var loaded = Simulation.new()
	check(loaded.import_state(json), "JSON round-trip restores game state")
	check(loaded.inventory == original.inventory, "Inventory preserved")
	check(loaded.citizens[0].pos.is_equal_approx(original.citizens[0].pos), "Citizen positions preserved")
	advance(original, 120.0)
	advance(loaded, 120.0)
	check(loaded.inventory == original.inventory, "Loaded production matches uninterrupted simulation")
	check(loaded.deliveries == original.deliveries, "Loaded deliveries match uninterrupted simulation")
	check(loaded.by_id(id).complete == original.by_id(id).complete, "Construction survives loading")
	var path := "user://test-city/check.json"
	check(Save.save_city(original, path), "Atomic save validates and writes")
	check(Save.save_city(loaded, path), "Second save creates backup")
	check(FileAccess.file_exists(path + ".bak"), "Backup exists")
	check(Save.load_city(path) != null, "Saved file loads")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func test_corrupt_save() -> void:
	var sim = fresh()
	var data: Dictionary = sim.export_state()
	data.schema_version = 999
	check(not Simulation.new().import_state(data), "Unknown schema rejected")
	data = sim.export_state()
	data.inventory.wood = -1
	check(not Simulation.new().import_state(data), "Negative inventory rejected")
	data = sim.export_state()
	data.citizens[0].pos = {"@v": [3]}
	check(not Simulation.new().import_state(data), "Malformed position rejected")
	data = sim.export_state()
	data.buildings[0].erase("entry")
	check(not Simulation.new().import_state(data), "Incomplete building rejected")
