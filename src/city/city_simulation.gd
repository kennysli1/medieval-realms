class_name CitySimulation
extends RefCounted
## All economy and citizen state lives here; rendering never changes inventory.

const Catalog = preload("res://src/city/building_catalog.gd")
const MAP_SIZE: int = 32
const STEP: float = 0.1
const SCHEMA: int = 1
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var buildings: Array[Dictionary] = []
var citizens: Array[Dictionary] = []
var roads: Dictionary = {}
var inventory: Dictionary = {"wood": 110, "planks": 24, "food": 90}
var time: float = 0.0
var speed: float = 1.0
var seed_value: int = 1453
var rng := RandomNumberGenerator.new()
var next_id: int = 1
var deliveries: int = 0
var message: String = "欢迎来到橡木谷。先观察居民，再试着扩建街区。"
var road_revision: int = 0
var accumulator: float = 0.0
var meal_timer: float = 0.0
var astar := AStarGrid2D.new()
var navigation_dirty: bool = true
var layout_version: int = 2
var appearance_revision: int = 0

func start_new() -> void:
	buildings.clear()
	citizens.clear()
	roads.clear()
	inventory = {"wood": 110, "planks": 24, "food": 90}
	time = 0.0
	next_id = 1
	deliveries = 0
	meal_timer = 0.0
	accumulator = 0.0
	speed = 1.0
	layout_version = 2
	rng.seed = seed_value
	# An inhabited square, short streets and narrow service lanes, not a giant cross.
	for x in range(7, 22):
		roads[Vector2i(x, 15)] = true
	for y in range(14, 20):
		roads[Vector2i(16, y)] = true
	for x in range(11, 17):
		roads[Vector2i(x, 18)] = true
	for y in range(11, 16):
		roads[Vector2i(19, y)] = true
	roads[Vector2i(18, 11)] = true
	for x in range(16, 22):
		roads[Vector2i(x, 19)] = true
	for x in range(15, 18):
		for y in range(14, 17):
			roads[Vector2i(x, y)] = true
	roads.erase(Vector2i(16, 15)) # The well is a decorative landmark; traffic goes around it.
	for cell in [Vector2i(13, 13), Vector2i(13, 14), Vector2i(14, 14), Vector2i(13, 16), Vector2i(13, 17), Vector2i(17, 14), Vector2i(7, 14), Vector2i(21, 14), Vector2i(21, 19)]:
		roads[cell] = true
	_add_building("keep", Vector2i(13, 10), true)
	_add_building("warehouse", Vector2i(17, 12), true)
	_add_building("house", Vector2i(11, 16), true)
	_add_building("house", Vector2i(18, 9), true)
	_add_building("woodcutter", Vector2i(7, 12), true)
	_add_building("sawmill", Vector2i(21, 12), true)
	_add_building("farm", Vector2i(21, 17), true)
	# Remove road cells covered by the initial buildings.
	for b in buildings:
		for cell in occupied_cells(b):
			roads.erase(cell)
	var names: Array[String] = ["艾伦", "玛莎", "威尔", "罗莎", "奥托", "艾达", "休", "安娜", "彼得", "莉娜", "汉斯", "梅芙", "卢卡", "诺拉", "芬恩", "艾拉", "托马", "露丝", "埃米", "保罗"]
	for i in range(20):
		var home_id: int = 3 if i < 10 else 4
		citizens.append({"id": i + 1, "name": names[i], "home": home_id, "workplace": -1,
			"pos": Vector2(14 + i % 3, 18), "direction": Vector2(1, 0), "state": "idle",
			"route": [], "target": Vector2i(16, 15), "resume": "idle", "timer": float(i) * 0.3,
			"cargo": {}, "cargo_role": "", "phase": float(i) * 0.5})
	navigation_dirty = true
	road_revision += 1
	message = "欢迎来到橡木谷。工人正在上岗，资源交付后会增加库存。"

func occupied_cells(b: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(b.size):
		for y in range(b.size):
			result.append(b.cell + Vector2i(x, y))
	return result

func building_at(cell: Vector2i) -> Dictionary:
	for b in buildings:
		if cell.x >= b.cell.x and cell.y >= b.cell.y and cell.x < b.cell.x + b.size and cell.y < b.cell.y + b.size:
			return b
	return {}

func by_id(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}

func warehouse() -> Dictionary:
	for b in buildings:
		if b.kind == "warehouse" and b.complete:
			return b
	return {}

func _add_building(kind: String, cell: Vector2i, complete: bool) -> Dictionary:
	var definition := Catalog.definition(kind)
	var size: int = definition.size
	var b := {"id": next_id, "kind": kind, "cell": cell, "size": size,
		"entry": cell + Vector2i(0, size), "complete": complete, "progress": 0.0,
		"reserved": {} if complete else definition.cost.duplicate(), "delivered": {}, "claimed": -1, "level": 1}
	next_id += 1
	buildings.append(b)
	return b

func placement_error(kind: String, cell: Vector2i) -> String:
	var definition := Catalog.definition(kind)
	if definition.is_empty() or kind == "keep":
		return "请选择可建造的建筑"
	var size: int = definition.size
	if cell.x < 2 or cell.y < 2 or cell.x + size >= MAP_SIZE - 2 or cell.y + size >= MAP_SIZE - 2:
		return "请建在领地内，并为入口留出空间"
	for x in range(size):
		for y in range(size):
			var tile := cell + Vector2i(x, y)
			if roads.has(tile) or not building_at(tile).is_empty():
				return "占地与道路或建筑重叠"
	for existing in buildings:
		var entry: Vector2i = existing.entry
		if entry.x >= cell.x and entry.y >= cell.y and entry.x < cell.x + size and entry.y < cell.y + size:
			return "请留出相邻建筑的入口"
	if not building_at(cell + Vector2i(0, size)).is_empty():
		return "建筑入口被遮挡"
	for resource in definition.cost:
		if inventory[resource] < definition.cost[resource]:
			return "库存不足：" + Catalog.cost_text(definition.cost)
	return ""

func place_building(kind: String, cell: Vector2i) -> int:
	var error := placement_error(kind, cell)
	if not error.is_empty():
		message = error
		return -1
	var b := _add_building(kind, cell, false)
	for resource in b.reserved:
		inventory[resource] -= b.reserved[resource]
	message = "%s已规划。材料已预留，请将入口接入道路。" % Catalog.definition(kind).name
	return b.id

func set_road(cell: Vector2i, present: bool) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= MAP_SIZE - 1 or cell.y >= MAP_SIZE - 1:
		return false
	if not building_at(cell).is_empty():
		message = "道路不能穿过建筑"
		return false
	if roads.has(cell) == present:
		return false
	if present:
		roads[cell] = true
	else:
		roads.erase(cell)
	navigation_dirty = true
	road_revision += 1
	for citizen in citizens:
		if not citizen.route.is_empty():
			citizen.route = []
			citizen.resume = citizen.state
			citizen.state = "blocked"
			citizen.timer = 0.0
	return true

func demolish(id: int) -> bool:
	var b := by_id(id)
	if b.is_empty():
		return false
	if b.kind == "keep" or (b.kind == "warehouse" and b.id == warehouse().get("id", -1)):
		message = "领主府与主仓库是当前城镇核心，不能拆除"
		return false
	for resource in b.reserved:
		inventory[resource] += b.reserved[resource]
	for resource in b.delivered:
		inventory[resource] += b.delivered[resource]
	buildings.erase(b)
	for c in citizens:
		if c.workplace == id:
			c.workplace = -1
			c.route = []
			if not c.cargo.is_empty():
				c.cargo_role = "return"
				_travel(c, warehouse().entry, "returning")
			else:
				c.state = "idle"
		if c.home == id:
			c.home = -1
	message = "建筑已拆除；未消耗的建材已退还，途中材料由居民运回。"
	return true

func cycle_house_style(id: int) -> bool:
	var b := by_id(id)
	if b.is_empty() or b.kind != "house":
		return false
	b.variant = (int(b.get("variant", int(b.id) % 3)) + 1) % 3
	appearance_revision += 1
	message = "住宅外观已更新，容量和生产规则不变。"
	return true

func upgrade_keep() -> bool:
	var keep := by_id(1)
	if keep.level >= 2:
		message = "领主府已达到原型的最高等级"
		return false
	if inventory.planks < 40:
		message = "领主府升级需要 40 木板"
		return false
	inventory.planks -= 40
	keep.level = 2
	message = "领主府升至 2 级！橡木谷已成为繁荣的城镇。"
	return true

func connect_building(id: int) -> bool:
	var b := by_id(id)
	if b.is_empty():
		return false
	var origin: Vector2i = b.entry
	var frontier: Array[Vector2i] = [origin]
	var previous: Dictionary = {origin: origin}
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if roads.has(current) and not path_between(current, warehouse().entry).is_empty():
			while current != origin:
				set_road(current, true)
				current = previous[current]
			set_road(origin, true)
			message = "入口道路已接通主仓库"
			return true
		for direction in DIRECTIONS:
			var next := current + direction
			if next.x < 1 or next.y < 1 or next.x >= MAP_SIZE - 1 or next.y >= MAP_SIZE - 1 or previous.has(next):
				continue
			if not building_at(next).is_empty():
				continue
			previous[next] = current
			frontier.append(next)
	message = "无法找到道路，请为入口留出通道"
	return false

func _refresh_navigation() -> void:
	if not navigation_dirty:
		return
	astar.region = Rect2i(0, 0, MAP_SIZE, MAP_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	astar.fill_solid_region(astar.region, true)
	for cell in roads:
		astar.set_point_solid(cell, false)
	navigation_dirty = false

func path_between(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	_refresh_navigation()
	if not roads.has(finish):
		return []
	var origin := start
	if not roads.has(origin):
		var found := false
		for direction in DIRECTIONS:
			if roads.has(start + direction):
				origin = start + direction
				found = true
				break
		if not found:
			return []
	return astar.get_id_path(origin, finish, false)

func connected(b: Dictionary) -> bool:
	var storehouse := warehouse()
	if storehouse.is_empty():
		return false
	return not path_between(storehouse.entry, b.entry).is_empty()

func _travel(c: Dictionary, target: Vector2i, state: String) -> void:
	c.target = target
	c.resume = state
	var path := path_between(Vector2i(Vector2(c.pos).round()), target)
	c.route = path
	c.state = state if not path.is_empty() else "blocked"
	c.timer = 0.0

func update(real_delta: float) -> void:
	if not is_finite(real_delta) or real_delta <= 0.0:
		return
	accumulator += minf(real_delta, 0.25) * speed
	while accumulator >= STEP:
		accumulator -= STEP
		_tick(STEP)

func _tick(delta: float) -> void:
	time += delta
	meal_timer += delta
	if meal_timer >= 45.0:
		meal_timer -= 45.0
		inventory.food = maxi(0, inventory.food - citizens.size())
	for c in citizens:
		_step_citizen(c, delta)

func _assign(c: Dictionary) -> void:
	for b in buildings:
		if not b.complete and b.claimed == -1 and connected(b):
			b.claimed = c.id
			c.workplace = b.id
			c.cargo_role = "construction"
			_travel(c, warehouse().entry, "fetch_materials")
			return
	for b in buildings:
		if not b.complete or b.kind not in ["woodcutter", "sawmill", "farm"]:
			continue
		var assigned := 0
		for other in citizens:
			if other.workplace == b.id:
				assigned += 1
		if assigned < 2:
			c.workplace = b.id
			_begin_production(c, b)
			return
	# Residents use actual connected roads to walk; meals consume the shared food stock.
	var home := by_id(c.home)
	if not home.is_empty() and time > 30.0 and int(time / 40.0 + c.id) % 3 == 0 and connected(home):
		_travel(c, home.entry, "homeward")
		return
	var options := roads.keys()
	var choice: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	_travel(c, choice, "strolling")

func _begin_production(c: Dictionary, b: Dictionary) -> void:
	c.timer = 0.0
	if b.kind == "sawmill":
		_travel(c, warehouse().entry, "fetch_input")
	else:
		_travel(c, b.entry, "to_work")

func _step_citizen(c: Dictionary, delta: float) -> void:
	c.phase += delta
	if c.state == "blocked":
		c.timer += delta
		if c.timer >= 1.0:
			_travel(c, c.target, c.resume)
		return
	if not c.route.is_empty():
		var waypoint := Vector2(c.route[0])
		var offset: Vector2 = waypoint - c.pos
		if offset.length_squared() > 0.001:
			c.direction = offset.normalized()
		var walking_speed := 1.05 if c.cargo.is_empty() else 0.86
		c.pos = Vector2(c.pos).move_toward(waypoint, delta * walking_speed)
		if Vector2(c.pos).distance_to(waypoint) < 0.005:
			c.route.pop_front()
			if c.route.is_empty():
				_arrived(c)
		return
	c.timer += delta
	var b := by_id(c.workplace)
	match c.state:
		"idle":
			if c.timer > 1.0:
				c.timer = 0.0
				_assign(c)
		"resting":
			if c.timer > 4.0:
				c.state = "idle"
		"waiting_input":
			if c.timer > 2.0 and inventory.wood >= 2:
				_arrived_fetch_input(c, b)
		"working":
			if b.is_empty():
				c.workplace = -1
				c.state = "idle"
				return
			if not connected(b):
				c.timer -= delta
				return
			var duration: float = {"woodcutter": 7.0, "sawmill": 9.0, "farm": 12.0}[b.kind]
			if c.timer >= duration:
				c.cargo = {"wood": 4} if b.kind == "woodcutter" else ({"planks": 3} if b.kind == "sawmill" else {"food": 6})
				c.cargo_role = "output"
				_travel(c, warehouse().entry, "delivering")
		"constructing":
			if not b.is_empty() and connected(b):
				b.progress = minf(1.0, b.progress + delta / 12.0)
				if b.progress >= 1.0:
					b.complete = true
					b.delivered = {}
					c.workplace = -1
					c.state = "idle"
					message = "%s建造完成！" % Catalog.definition(b.kind).name

func _arrived_fetch_input(c: Dictionary, b: Dictionary) -> void:
	if b.is_empty():
		c.state = "idle"
		return
	if inventory.wood < 2:
		c.state = "waiting_input"
		c.timer = 0.0
		return
	inventory.wood -= 2
	c.cargo = {"wood": 2}
	c.cargo_role = "input"
	_travel(c, b.entry, "to_work")

func _arrived(c: Dictionary) -> void:
	var b := by_id(c.workplace)
	c.timer = 0.0
	match c.state:
		"fetch_materials":
			if b.is_empty():
				c.state = "idle"
				return
			c.cargo = b.reserved.duplicate()
			b.reserved = {}
			_travel(c, b.entry, "deliver_materials")
		"deliver_materials":
			if b.is_empty():
				_travel(c, warehouse().entry, "returning")
				return
			b.delivered = c.cargo.duplicate()
			c.cargo = {}
			c.state = "constructing"
		"fetch_input":
			_arrived_fetch_input(c, b)
		"to_work":
			c.cargo = {}
			c.cargo_role = ""
			c.state = "working"
		"delivering", "returning":
			for resource in c.cargo:
				inventory[resource] += c.cargo[resource]
			if not c.cargo.is_empty():
				deliveries += 1
			c.cargo = {}
			c.cargo_role = ""
			if b.is_empty() or not b.complete:
				c.workplace = -1
				c.state = "idle"
			else:
				_begin_production(c, b)
		"strolling", "homeward":
			c.state = "resting"

func building_status(b: Dictionary) -> String:
	if not connected(b):
		return "道路未接通"
	if not b.complete:
		return "施工 %d%%" % (b.progress * 100) if b.progress > 0.0 else ("运送建材" if b.claimed != -1 else "等待工人")
	if b.kind == "sawmill" and inventory.wood < 2:
		return "原木不足"
	if b.kind in ["woodcutter", "sawmill", "farm"]:
		var count := 0
		for c in citizens:
			if c.workplace == b.id:
				count += 1
		return "生产中 · %d/2 人" % count if count > 0 else "等待工人"
	return "正常使用"

func population_capacity() -> int:
	var capacity := 0
	for b in buildings:
		if b.kind == "house" and b.complete:
			capacity += 12
	return capacity

func citizen_status(c: Dictionary) -> String:
	return {"idle": "寻找工作", "resting": "休息", "strolling": "在街区散步", "homeward": "回家休息",
		"fetch_materials": "前往仓库取建材", "deliver_materials": "搬运建材", "constructing": "施工",
		"fetch_input": "前往仓库取原木", "waiting_input": "等待原木", "to_work": "前往岗位",
		"working": "工作中", "delivering": "运送产品入仓", "returning": "运回剩余材料", "blocked": "道路中断 · 等待恢复"}.get(c.state, c.state)

func export_state() -> Dictionary:
	return {"schema_version": SCHEMA, "layout_version": layout_version, "time": time, "seed": seed_value, "rng_state": str(rng.state),
		"next_id": next_id, "deliveries": deliveries, "meal_timer": meal_timer,
		"inventory": inventory.duplicate(true), "buildings": _encode(buildings), "citizens": _encode(citizens),
		"roads": _encode(roads.keys())}

func _encode(value: Variant) -> Variant:
	if value is Vector2i:
		return {"@i": [value.x, value.y]}
	if value is Vector2:
		return {"@v": [value.x, value.y]}
	if value is Dictionary:
		var output: Dictionary = {}
		for key in value:
			output[key] = _encode(value[key])
		return output
	if value is Array:
		var output: Array = []
		for item in value:
			output.append(_encode(item))
		return output
	return value

func _decode(value: Variant) -> Variant:
	# JSON decodes all numbers as floats. Restore exact integral stock/ID values.
	if value is float and value == floor(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Dictionary:
		if value.has("@i"):
			return Vector2i(int(value["@i"][0]), int(value["@i"][1]))
		if value.has("@v"):
			return Vector2(float(value["@v"][0]), float(value["@v"][1]))
		var output: Dictionary = {}
		for key in value:
			output[key] = _decode(value[key])
		return output
	if value is Array:
		var output: Array = []
		for item in value:
			output.append(_decode(item))
		return output
	return value

func import_state(data: Dictionary) -> bool:
	# Called on a temporary simulation by the save service; validate before activation.
	if int(data.get("schema_version", -1)) != SCHEMA:
		return false
	for key in ["inventory", "buildings", "citizens", "roads", "time", "seed", "rng_state", "next_id", "deliveries", "meal_timer"]:
		if not data.has(key):
			return false
	if not data.inventory is Dictionary or not data.buildings is Array or not data.citizens is Array or not data.roads is Array:
		return false
	for resource in ["wood", "planks", "food"]:
		if not data.inventory.has(resource) or not (data.inventory[resource] is float or data.inventory[resource] is int) or data.inventory[resource] < 0:
			return false
	if data.buildings.size() > 500 or data.citizens.size() > 500 or data.roads.size() > MAP_SIZE * MAP_SIZE:
		return false
	# Check encoded structures before decoding to avoid malformed vectors and missing fields.
	if not _valid_encoded(data.buildings) or not _valid_encoded(data.citizens) or not _valid_encoded(data.roads):
		return false
	var decoded_buildings: Array = _decode(data.buildings)
	var decoded_citizens: Array = _decode(data.citizens)
	var decoded_roads: Array = _decode(data.roads)
	var ids: Dictionary = {}
	for b in decoded_buildings:
		if not b is Dictionary:
			return false
		for key in ["id", "kind", "cell", "size", "entry", "complete", "progress", "reserved", "delivered", "claimed", "level"]:
			if not b.has(key):
				return false
		if not b.cell is Vector2i or not b.entry is Vector2i or not Catalog.DEFINITIONS.has(b.kind) or ids.has(int(b.id)):
			return false
		if int(b.size) != Catalog.definition(b.kind).size or b.cell.x < 0 or b.cell.y < 0 or b.cell.x + b.size >= MAP_SIZE or b.cell.y + b.size >= MAP_SIZE:
			return false
		if not _valid_cargo(b.reserved) or not _valid_cargo(b.delivered):
			return false
		ids[int(b.id)] = true
	for c in decoded_citizens:
		if not c is Dictionary:
			return false
		for key in ["id", "name", "home", "workplace", "pos", "direction", "state", "route", "target", "resume", "timer", "cargo", "cargo_role", "phase"]:
			if not c.has(key):
				return false
		if not c.pos is Vector2 or not c.direction is Vector2 or not c.target is Vector2i or not c.route is Array or not _valid_cargo(c.cargo):
			return false
		if c.pos.x < 0 or c.pos.y < 0 or c.pos.x >= MAP_SIZE or c.pos.y >= MAP_SIZE:
			return false
		for point in c.route:
			if not point is Vector2i:
				return false
	for cell in decoded_roads:
		if not cell is Vector2i or cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE or cell.y >= MAP_SIZE:
			return false
	buildings.assign(decoded_buildings)
	citizens.assign(decoded_citizens)
	roads.clear()
	for cell in decoded_roads:
		roads[cell] = true
	if warehouse().is_empty() or by_id(1).get("kind", "") != "keep":
		return false
	inventory = _decode(data.inventory)
	time = float(data.time)
	seed_value = int(data.seed)
	layout_version = int(data.get("layout_version", 1))
	rng.seed = seed_value
	rng.state = int(data.rng_state)
	next_id = int(data.next_id)
	deliveries = int(data.deliveries)
	meal_timer = float(data.meal_timer)
	speed = 1.0
	accumulator = 0.0
	navigation_dirty = true
	message = "存档已读取。城镇继续运转。"
	return true

func _valid_cargo(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if key not in ["wood", "planks", "food"] or not (value[key] is float or value[key] is int) or value[key] < 0:
			return false
	return true

func _valid_encoded(value: Variant) -> bool:
	if value is Dictionary:
		for marker in ["@i", "@v"]:
			if value.has(marker):
				var coordinates: Variant = value[marker]
				return coordinates is Array and coordinates.size() == 2 and (coordinates[0] is float or coordinates[0] is int) and (coordinates[1] is float or coordinates[1] is int)
		for key in value:
			if not _valid_encoded(value[key]):
				return false
	if value is Array:
		for item in value:
			if not _valid_encoded(item):
				return false
	return true
