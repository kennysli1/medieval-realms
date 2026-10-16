class_name CityView
extends Node2D
## Generated raster atlases are sampled directly; no offline image manipulation.

const Grid = preload("res://src/core/isometric_grid.gd")
const Catalog = preload("res://src/city/building_catalog.gd")
const Art = preload("res://src/presentation/town_art.gd")
const BUILDINGS: Texture2D = preload("res://assets/generated/buildings.png")
const CITIZENS: Texture2D = preload("res://assets/generated/citizens-walk-v2.png")
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
	terrain = Node2D.new()
	terrain.show_behind_parent = true
	add_child(terrain)
	terrain.draw.connect(func() -> void: _draw_terrain(terrain))
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
		draw_colored_polygon(tile_polygon(hover_cell + Vector2i(0, definition.size), 0.8), Color(0.9, 0.77, 0.38, 0.8))
	elif tool in ["road", "demolish"] and hover_cell.x >= 0:
		draw_colored_polygon(tile_polygon(hover_cell), Color(0.85, 0.72, 0.42, 0.6) if tool == "road" else Color(0.90, 0.32, 0.24, 0.5))

func _draw_terrain(canvas: Node2D) -> void:
	if sim == null:
		return
	for sum_cell in range(64):
		for x in range(32):
			var y := sum_cell - x
			if y < 0 or y >= 32:
				continue
			var cell := Vector2i(x, y)
			var noise_value: float = sin(x * 0.32) * cos(y * 0.37) * 0.018 + sin(x * 9.1 + y * 7.7) * 0.002
			var edge := x < 2 or y < 2 or x > 29 or y > 29
			var base := Color(0.35 + noise_value, 0.45 + noise_value, 0.28 + noise_value) if not edge else Color(0.25, 0.36, 0.24)
			canvas.draw_colored_polygon(tile_polygon(cell), base)
			# Tiny vegetation marks add texture without making a visible tile grid.
			if (x * 17 + y * 13) % 3 == 0:
				var point := Grid.grid_to_screen(cell) + Vector2(sin(x * 3.7) * 30, cos(y * 2.4) * 14)
				canvas.draw_line(point, point + Vector2(2, -4), Color(0.49, 0.56, 0.32, 0.5), 1.0)
			if show_grid:
				var polygon := tile_polygon(cell)
				polygon.append(polygon[0])
				canvas.draw_polyline(polygon, Color(0.75, 0.79, 0.58, 0.14), 1.0)
	for cell in sim.roads:
		var point := road_point(cell)
		var width := road_width(cell)
		canvas.draw_circle(point, width * 0.5 + 2, Color(0.39, 0.37, 0.26, 0.6))
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if sim.roads.has(cell + direction):
				var end := (point + road_point(cell + direction)) * 0.5
				canvas.draw_line(point, end, Color(0.39, 0.37, 0.26, 0.6), width + 4, true)
	for cell in sim.roads:
		var point := road_point(cell)
		var width := road_width(cell)
		canvas.draw_circle(point, width * 0.5, Color(0.62, 0.56, 0.41))
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if sim.roads.has(cell + direction):
				canvas.draw_line(point, (point + road_point(cell + direction)) * 0.5, Color(0.62, 0.56, 0.41), width, true)
		for i in range(3):
			var offset := Vector2(sin(cell.x * 12.0 + i * 6.7) * 8, cos(cell.y * 3.1 + i) * 4)
			canvas.draw_line(point + offset, point + offset + Vector2(3, 1), Color(0.42, 0.39, 0.29, 0.28), 1.0)
	if has_village_square():
		for x in range(15, 18):
			for y in range(14, 17):
				var cell := Vector2i(x, y)
				canvas.draw_colored_polygon(tile_polygon(cell), Color(0.43, 0.43, 0.36))
				for i in range(3):
					for j in range(3):
						var center := project(Vector2(cell) + Vector2(float(i - 1) / 3, float(j - 1) / 3))
						var shade := sin(x * 17 + y * 31 + i * 4 + j) * 0.035
						canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-19, 0), center + Vector2(0, -9), center + Vector2(19, 0), center + Vector2(0, 9)]), Color(0.61 + shade, 0.59 + shade, 0.49 + shade))
	# Short paths meet the visible doorway, bridging art pivots and logical entrances.
	for building in sim.buildings:
		if sim.roads.has(building.entry):
			var entry := road_point(building.entry)
			var door := building_door(building)
			canvas.draw_line(entry, door, Color(0.43, 0.40, 0.29), 14, true)
			canvas.draw_line(entry, door, Color(0.63, 0.58, 0.44), 10, true)

func road_point(cell: Vector2i) -> Vector2:
	return Grid.grid_to_screen(cell) + Vector2(sin(cell.x * 0.8 + cell.y) * 1.6, cos(cell.y * 1.1 + cell.x) * 0.8)

func road_width(cell: Vector2i) -> float:
	return 28.0 if (cell.y == 15 and cell.x >= 10 and cell.x <= 22) or (cell.x == 16 and cell.y >= 14 and cell.y <= 19) else 18.0

func _update_cache() -> void:
	var key := "%s:%d:%d:%d:%d:%s" % [sim.get_instance_id(), sim.next_id, sim.road_revision, sim.appearance_revision, sim.buildings.size(), show_grid]
	if key == cache_key:
		return
	cache_key = key
	decor_cache.clear()
	for item in decor:
		if _decor_visible(item.cell):
			decor_cache.append({"depth": Grid.grid_to_screen(item.cell).y, "type": "nature", "data": item})
	terrain.queue_redraw()

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
	var uv: Vector2 = {"keep": Vector2(0.42, 0.87), "house": Vector2(0.34, 0.88), "warehouse": Vector2(0.31, 0.78), "woodcutter": Vector2(0.41, 0.80), "sawmill": Vector2(0.49, 0.84), "farm": Vector2(0.60, 0.76)}[b.kind]
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
	var row: int = 0 if direction.x >= absf(direction.y) else (3 if -direction.x >= absf(direction.y) else (1 if direction.y > 0 else 2))
	var frame_index: int = int(walk_cycles.get(c.id, 0.0) * 6.0) % 6 if moving else 1
	var frame: Dictionary
	var texture: Texture2D = Art.WALK
	var scale_factor := 0.185
	if working:
		var b: Dictionary = sim.by_id(c.workplace)
		var profession: int = {"woodcutter": 0, "sawmill": 1, "farm": 2}.get(b.get("kind", ""), 1)
		frame_index = int(c.phase * 3.5) % 4
		frame = Art.animation_frame(true, profession, frame_index)
		texture = Art.WORK
		scale_factor = 0.145
	else:
		frame = Art.animation_frame(false, row, frame_index)
	var region := Art.frame_region(frame)
	var pivot := Vector2(frame.pivot[0], frame.pivot[1])
	# Feet remain anchored even when poses have different transparent margins.
	draw_set_transform(p, 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, 8, Color(0.12, 0.17, 0.11, 0.20))
	draw_set_transform(Vector2.ZERO)
	if c.id == selected_citizen:
		draw_arc(p, 15, 0, TAU, 24, Color(0.96, 0.82, 0.47), 2.0)
	if not c.cargo.is_empty() and row >= 2:
		_draw_cargo(c, p, row)
	var tint := Color(1.0, 0.98, 0.93) if int(c.id) % 3 == 0 else (Color(0.91, 0.97, 1.0) if int(c.id) % 3 == 1 else Color.WHITE)
	draw_texture_rect_region(texture, Rect2(p - pivot * scale_factor, region.size * scale_factor), region, tint)
	if not c.cargo.is_empty() and row < 2:
		_draw_cargo(c, p, row)
	if working and frame_index == 2:
		for i in range(3):
			var life: float = fmod(c.phase * 3.5, 1.0)
			var speck := p + Vector2(12 + i * 3 + life * 7, -6 - sin(life * PI) * 6 + i)
			draw_circle(speck, 0.8, Color(0.80, 0.68, 0.40, (1 - life) * 0.6))

func _draw_cargo(c: Dictionary, p: Vector2, row: int) -> void:
	var offset := Vector2(8 if row in [0, 2] else -9, -19)
	var resource: String = c.cargo.keys()[0]
	if resource == "wood":
		for i in range(3):
			var point := p + offset + Vector2(0, i * 2.5)
			draw_line(point - Vector2(7, 2), point + Vector2(6, 0), Color(0.38, 0.25, 0.12), 4.5)
			draw_circle(point + Vector2(6, 0), 2.2, Color(0.71, 0.53, 0.29))
	elif resource == "planks":
		for i in range(3):
			var point := p + offset + Vector2(0, i * 2.5)
			draw_line(point - Vector2(8, 2), point + Vector2(8, 0), Color(0.77, 0.58, 0.31), 2.0)
	else:
		var center := p + offset
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, -2), center + Vector2(8, -2), center + Vector2(5, 8), center + Vector2(-5, 8)]), Color(0.59, 0.40, 0.21))
		for i in range(5):
			draw_circle(center + Vector2(i * 2.6 - 5, -3), 2.0, Color(0.86, 0.72, 0.36))

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
