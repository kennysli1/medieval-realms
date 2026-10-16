class_name CityView
extends Node2D
## Generated raster atlases are sampled directly; no offline image manipulation.

const Grid = preload("res://src/core/isometric_grid.gd")
const Catalog = preload("res://src/city/building_catalog.gd")
const Art = preload("res://src/presentation/town_art.gd")
const Ground = preload("res://src/presentation/town_ground.gd")
const Residents = preload("res://src/presentation/resident_sprites.gd")
const BUILDINGS: Texture2D = preload("res://assets/generated/buildings.png")
const NATURE: Texture2D = preload("res://assets/generated/nature.png")
var sim: RefCounted
var selected_building: int = -1
var selected_citizen: int = -1
var tool: String = "select"
var hover_cell := Vector2i(-100, -100)
var decor: Array[Dictionary] = []
var show_grid: bool = false
var terrain: Node2D
var decor_cache: Array[Dictionary] = []
var cache_key: String = ""
var visual_positions: Dictionary = {}
var walk_cycles: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	terrain = Ground.new()
	terrain.show_behind_parent = true
	add_child(terrain)
	var random := RandomNumberGenerator.new()
	random.seed = 517
	for x in range(2, 30):
		for y in range(2, 30):
			if random.randf() < (0.38 if x < 7 or y < 9 or x > 25 or y > 24 else 0.025):
				decor.append({"cell": Vector2i(x, y), "type": random.randi_range(0, 3), "scale": random.randf_range(0.72, 1.1)})

func project(position_in_grid: Vector2) -> Vector2:
	return Vector2((position_in_grid.x - position_in_grid.y) * 64.0, (position_in_grid.x + position_in_grid.y) * 32.0)

func tile_polygon(cell: Vector2i, scale_factor: float = 1.0) -> PackedVector2Array:
	var p := Grid.grid_to_screen(cell)
	return PackedVector2Array([p + Vector2(0, -32) * scale_factor, p + Vector2(64, 0) * scale_factor,
		p + Vector2(0, 32) * scale_factor, p + Vector2(-64, 0) * scale_factor])

func building_foot(b: Dictionary) -> Vector2:
	return project(Vector2(b.cell) + Vector2.ONE * (float(b.size) - 1.0) * 0.5) + Vector2(0, b.size * 24.0)

func building_rect(b: Dictionary) -> Rect2:
	var width: float = 260.0 if b.size == 2 else 330.0
	var height: float = width
	if b.get("kind", "") == "house":
		var source := Art.house_region(Art.house_variant(b))
		width = 260.0 if Art.house_variant(b) != 2 else 275.0
		height = width * source.size.y / source.size.x
	return Rect2(building_foot(b) - Vector2(width * 0.5, height), Vector2(width, height))

func _draw() -> void:
	if sim == null:
		return
	_update_cache()
	var objects: Array[Dictionary] = decor_cache.duplicate()
	for b in sim.buildings:
		objects.append({"depth": building_foot(b).y - 25.0, "type": "building", "data": b})
	for c in sim.citizens:
		objects.append({"depth": citizen_position(c).y, "type": "citizen", "data": c})
	if has_village_square():
		objects.append({"depth": project(Vector2(16, 15)).y - 2, "type": "well", "data": {}})
	objects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for object in objects:
		match object.type:
			"nature": _draw_nature(object.data)
			"building": _draw_building(object.data)
			"citizen": _draw_citizen(object.data)
			"well": _draw_well()
	if tool in Catalog.ORDER:
		var definition := Catalog.definition(tool)
		var valid: bool = sim.placement_error(tool, hover_cell).is_empty()
		var tint := Color(0.68, 0.86, 0.60, 0.55) if valid else Color(0.89, 0.37, 0.25, 0.55)
		for dx in range(definition.size):
			for dy in range(definition.size):
				draw_colored_polygon(tile_polygon(hover_cell + Vector2i(dx, dy)), tint)
		var preview := {"cell": hover_cell, "size": definition.size, "kind": tool, "id": sim.next_id}
		_draw_building_art(preview, Color(1, 1, 1, 0.55))
		draw_colored_polygon(tile_polygon(hover_cell + Vector2i(definition.size - 1, definition.size), 0.8), Color(0.9, 0.77, 0.38, 0.8))
	elif tool in ["road", "demolish"] and hover_cell.x >= 0:
		draw_colored_polygon(tile_polygon(hover_cell), Color(0.85, 0.72, 0.42, 0.6) if tool == "road" else Color(0.90, 0.32, 0.24, 0.5))

func _update_cache() -> void:
	var key := "%s:%d:%d:%d:%d:%s" % [sim.get_instance_id(), sim.next_id, sim.road_revision, sim.appearance_revision, sim.buildings.size(), show_grid]
	if key == cache_key:
		return
	cache_key = key
	decor_cache.clear()
	for item in decor:
		if _decor_visible(item.cell):
			decor_cache.append({"depth": Grid.grid_to_screen(item.cell).y, "type": "nature", "data": item})
	terrain.refresh(sim, self)

func update_visuals(delta: float) -> void:
	for c in sim.citizens:
		var target := project(c.pos)
		if not c.route.is_empty():
			var heading := project(c.direction).normalized()
			target += Vector2(-heading.y, heading.x) * (3.0 + float(int(c.id) % 3) * 0.8)
		elif c.state in ["working", "constructing"]:
			var b: Dictionary = sim.by_id(c.workplace)
			if not b.is_empty():
				target = Vector2(building_door(b).x + (-12 if int(c.id) % 2 == 0 else 14), maxf(building_door(b).y + 9, building_foot(b).y - 5))
		else:
			target += Vector2(sin(c.id * 2.7), cos(c.id * 1.9)) * 4.0
		if not visual_positions.has(c.id) or Vector2(visual_positions[c.id]).distance_to(target) > 240.0:
			visual_positions[c.id] = target
		elif sim.speed > 0.0:
			var previous: Vector2 = visual_positions[c.id]
			visual_positions[c.id] = previous.lerp(target, 1.0 - exp(-delta * 16.0))
			if not c.route.is_empty():
				walk_cycles[c.id] = walk_cycles.get(c.id, c.id * 0.37) + previous.distance_to(visual_positions[c.id]) / 54.0

func citizen_position(c: Dictionary) -> Vector2:
	return visual_positions.get(c.id, project(c.pos))

func building_door(b: Dictionary) -> Vector2:
	var rect := building_rect(b)
	var uv: Vector2 = {"keep": Vector2(0.42, 0.87), "house": Vector2(0.34, 0.88), "warehouse": Vector2(0.31, 0.78), "woodcutter": Vector2(0.41, 0.80), "sawmill": Vector2(0.49, 0.84), "farm": Vector2(0.25, 0.90)}[b.kind]
	return rect.position + rect.size * uv

func has_village_square() -> bool:
	return sim.layout_version >= 2 and not sim.roads.has(Vector2i(16, 15)) and sim.building_at(Vector2i(16, 15)).is_empty() and sim.roads.has(Vector2i(15, 15)) and sim.roads.has(Vector2i(17, 15))

func _draw_well() -> void:
	var region := Art.well_region()
	var size := Vector2(83, 83 * region.size.y / region.size.x)
	var foot := project(Vector2(16, 15)) + Vector2(0, 6)
	draw_texture_rect_region(Art.HOUSES, Rect2(foot - Vector2(size.x * 0.5, size.y), size), region)

func _draw_building_art(b: Dictionary, color: Color) -> void:
	draw_texture_rect_region(Art.HOUSES if b.kind == "house" else BUILDINGS, building_rect(b), Art.building_source(b.kind, Art.house_variant(b)), color)

func _decor_visible(cell: Vector2i) -> bool:
	if sim.roads.has(cell):
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if not sim.building_at(cell + Vector2i(dx, dy)).is_empty():
				return false
	return true

func _draw_nature(item: Dictionary) -> void:
	var width: float = (170.0 if item.type != 2 else 115.0) * item.scale
	var position_on_map := Grid.grid_to_screen(item.cell)
	var rect := Rect2(position_on_map - Vector2(width * 0.5, width * 0.82), Vector2(width, width))
	# The generated nature sheet has unequal row heights; sample measured regions.
	var regions: Array[Rect2] = [Rect2(0, 0, 735, 646), Rect2(735, 0, 639, 646), Rect2(0, 650, 735, 495), Rect2(735, 646, 639, 499)]
	draw_texture_rect_region(NATURE, rect, regions[item.type])

func _draw_building(b: Dictionary) -> void:
	if b.id == selected_building:
		for cell in sim.occupied_cells(b):
			draw_colored_polygon(tile_polygon(cell, 0.98), Color(0.95, 0.80, 0.38, 0.65))
	var rect := building_rect(b)
	var color := Color.WHITE if b.complete else Color(0.80, 0.83, 0.76, 0.48)
	_draw_building_art(b, color)
	var foot := building_foot(b)
	if not b.complete:
		for offset_x in [-70.0, 0.0, 70.0]:
			draw_line(foot + Vector2(offset_x, -10), foot + Vector2(offset_x, -95), Color(0.45, 0.30, 0.17), 4.0)
		draw_line(foot + Vector2(-77, -70), foot + Vector2(77, -70), Color(0.55, 0.37, 0.20), 4.0)
		draw_style_box(_bar_style(Color(0.12, 0.19, 0.16)), Rect2(foot + Vector2(-45, -6), Vector2(90, 8)))
		draw_rect(Rect2(foot + Vector2(-43, -4), Vector2(86 * b.progress, 4)), Color(0.87, 0.69, 0.34))
	elif b.kind in ["house", "woodcutter", "sawmill"]:
		var chimney := rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.23)
		for i in range(4):
			var t: float = fmod(sim.time * 0.24 + i * 0.25 + b.id * 0.11, 1.0)
			var puff := chimney + Vector2(sin(t * 5 + b.id) * 10 + t * 12, -t * 52)
			draw_circle(puff, 3.0 + t * 7.0, Color(0.91, 0.88, 0.73, (1.0 - t) * 0.17))
	if not sim.connected(b):
		draw_circle(foot + Vector2(0, -24), 11, Color(0.45, 0.20, 0.14))
		draw_line(foot + Vector2(0, -30), foot + Vector2(0, -23), Color(1, 0.82, 0.55), 2.5)
		draw_circle(foot + Vector2(0, -19), 1.5, Color(1, 0.82, 0.55))
	if b.kind == "keep" and b.level > 1:
		draw_arc(foot + Vector2(0, -24), 24, 0, TAU, 32, Color(0.95, 0.78, 0.37), 2.0)

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

func _draw_citizen(c: Dictionary) -> void:
	var p := citizen_position(c)
	var moving: bool = not c.route.is_empty()
	var working: bool = not moving and c.state in ["working", "constructing"]
	var direction: Vector2 = c.direction
	var b: Dictionary = sim.by_id(c.workplace)
	if working and not b.is_empty():
		direction = Vector2(b.cell) + Vector2.ONE * float(b.size) * 0.5 - Vector2(c.pos)
	var row: int = 0 if direction.x >= absf(direction.y) else (3 if -direction.x >= absf(direction.y) else (1 if direction.y > 0 else 2))
	var action := "idle"
	if moving:
		action = "carry" if not c.cargo.is_empty() else ("run" if c.state == "fetch_materials" else "walk")
	elif working:
		action = "chop" if b.get("kind", "") == "woodcutter" else "work"
	elif c.state == "resting":
		action = {"wave": "wave", "chat": "wave", "look": "work"}.get(c.get("activity", "rest"), "idle")
	var frame: int = int(walk_cycles.get(c.id, 0.0) * Residents.FRAMES) % Residents.FRAMES if moving else int(c.phase * 6.0) % Residents.FRAMES
	var profile: int = Residents.appearance(c)
	var scale_factor := 0.67
	var region := Residents.region(action, row, frame)
	var pivot := Residents.pivot()
	var hands := Residents.hand_points(profile, action, row, frame)
	var cargo_point := p + Vector2(7, -20)
	if hands.size() == 2:
		cargo_point = p + ((hands[0] + hands[1]) * 0.5 - pivot) * scale_factor
	draw_set_transform(p, 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, 8, Color(0.12, 0.17, 0.11, 0.20))
	draw_set_transform(Vector2.ZERO)
	if c.id == selected_citizen:
		draw_arc(p, 15, 0, TAU, 24, Color(0.96, 0.82, 0.47), 2.0)
	if not c.cargo.is_empty() and row >= 2:
		_draw_cargo(c, cargo_point)
	draw_texture_rect_region(Residents.TEXTURES[profile], Rect2(p - pivot * scale_factor, Residents.CELL * scale_factor), region)
	if not c.cargo.is_empty() and row < 2:
		_draw_cargo(c, cargo_point)
	if working and hands.size() == 2:
		_draw_work_tool(b.get("kind", ""), p + (hands[0] - pivot) * scale_factor, p + (hands[1] - pivot) * scale_factor)

func _draw_work_tool(kind: String, left: Vector2, right: Vector2) -> void:
	if kind == "woodcutter":
		var axis := (right - left).normalized()
		if axis.length_squared() < 0.1:
			axis = Vector2(0, -1)
		var tip := right + axis * 11
		var normal := Vector2(-axis.y, axis.x)
		draw_line(left - axis * 4, tip, Color(0.46, 0.29, 0.13), 2)
		draw_colored_polygon(PackedVector2Array([tip - axis * 3, tip + axis * 2 + normal * 5, tip + axis * 3 - normal * 4]), Color(0.65, 0.68, 0.62))
	elif kind == "farm":
		var end := right + Vector2(8, 15)
		draw_line(left, end, Color(0.47, 0.32, 0.17), 2)
		draw_line(end - Vector2(3, 0), end + Vector2(3, 1), Color(0.59, 0.63, 0.57), 3)
	else:
		draw_line(left, right, Color(0.68, 0.69, 0.59), 3)
		draw_circle(left, 1.5, Color(0.41, 0.27, 0.13))
		draw_circle(right, 1.5, Color(0.41, 0.27, 0.13))

func _draw_cargo(c: Dictionary, anchor: Vector2) -> void:
	var resource: String = c.cargo.keys()[0]
	if resource == "wood":
		for i in range(3):
			var point := anchor + Vector2(0, i * 2.5)
			draw_line(point - Vector2(7, 2), point + Vector2(6, 0), Color(0.38, 0.25, 0.12), 4.5)
			draw_circle(point + Vector2(6, 0), 2.2, Color(0.71, 0.53, 0.29))
	elif resource == "planks":
		for i in range(3):
			var point := anchor + Vector2(0, i * 2.5)
			draw_line(point - Vector2(8, 2), point + Vector2(8, 0), Color(0.77, 0.58, 0.31), 2.0)
	else:
		draw_colored_polygon(PackedVector2Array([anchor + Vector2(-8, -2), anchor + Vector2(8, -2), anchor + Vector2(5, 8), anchor + Vector2(-5, 8)]), Color(0.59, 0.40, 0.21))
		for i in range(5):
			draw_circle(anchor + Vector2(i * 2.6 - 5, -3), 2.0, Color(0.86, 0.72, 0.36))

func _draw_atlas(texture: Texture2D, index: int, grid: Vector2i, destination: Rect2, modulate_color: Color = Color.WHITE) -> void:
	var cell := Vector2(texture.get_size()) / Vector2(grid)
	var source := Rect2(Vector2(index % grid.x, index / grid.x) * cell, cell)
	draw_texture_rect_region(texture, destination, source, modulate_color)

func pick_building(local_point: Vector2) -> int:
	var candidates: Array[Dictionary] = sim.buildings.duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return building_foot(a).y > building_foot(b).y)
	for b in candidates:
		var rect := building_rect(b)
		if rect.has_point(local_point):
			var uv := (local_point - rect.position) / rect.size
			if Art.is_opaque(b.kind, Art.house_variant(b), uv):
				return b.id
	return sim.building_at(Grid.screen_to_grid(local_point)).get("id", -1)
