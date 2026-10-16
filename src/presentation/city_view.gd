class_name CityView
extends Node2D
## Generated raster atlases are sampled directly; no offline image manipulation.

const Grid = preload("res://src/core/isometric_grid.gd")
const Catalog = preload("res://src/city/building_catalog.gd")
const BUILDINGS: Texture2D = preload("res://assets/generated/buildings.png")
const CITIZENS: Texture2D = preload("res://assets/generated/citizens.png")
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
	return Rect2(building_foot(b) - Vector2(width * 0.5, width), Vector2(width, width))

func _draw() -> void:
	if sim == null:
		return
	_update_cache()
	var objects: Array[Dictionary] = decor_cache.duplicate()
	for b in sim.buildings:
		objects.append({"depth": building_foot(b).y - 25.0, "type": "building", "data": b})
	for c in sim.citizens:
		objects.append({"depth": project(c.pos).y, "type": "citizen", "data": c})
	objects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for object in objects:
		match object.type:
			"nature": _draw_nature(object.data)
			"building": _draw_building(object.data)
			"citizen": _draw_citizen(object.data)
	if tool in Catalog.ORDER:
		var definition := Catalog.definition(tool)
		var valid: bool = sim.placement_error(tool, hover_cell).is_empty()
		var tint := Color(0.68, 0.86, 0.60, 0.55) if valid else Color(0.89, 0.37, 0.25, 0.55)
		for dx in range(definition.size):
			for dy in range(definition.size):
				draw_colored_polygon(tile_polygon(hover_cell + Vector2i(dx, dy)), tint)
		var preview := {"cell": hover_cell, "size": definition.size}
		_draw_atlas(BUILDINGS, definition.atlas, Vector2i(3, 2), building_rect(preview), Color(1, 1, 1, 0.55))
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
			var noise_value: float = sin(x * 13.21 + y * 7.72) * 0.004
			var edge := x < 2 or y < 2 or x > 29 or y > 29
			var base := Color(0.32 + noise_value, 0.43 + noise_value, 0.25 + noise_value) if not edge else Color(0.25, 0.36, 0.24)
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
		var p := Grid.grid_to_screen(cell)
		canvas.draw_circle(p, 17, Color(0.47, 0.43, 0.29))
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if sim.roads.has(cell + direction):
				canvas.draw_line(p, p + Grid.grid_to_screen(direction) * 0.51, Color(0.47, 0.43, 0.29), 34.0, true)
	for cell in sim.roads:
		var p := Grid.grid_to_screen(cell)
		canvas.draw_circle(p, 13, Color(0.66, 0.59, 0.43))
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if sim.roads.has(cell + direction):
				canvas.draw_line(p, p + Grid.grid_to_screen(direction) * 0.51, Color(0.66, 0.59, 0.43), 26.0, true)
		for i in range(3):
			var offset := Vector2(sin(cell.x * 12.0 + i * 6.7) * 10, cos(cell.y * 3.1 + i) * 6)
			canvas.draw_line(p + offset, p + offset + Vector2(3, 1), Color(0.43, 0.40, 0.30, 0.25), 1.0)

func _update_cache() -> void:
	var key := "%s:%d:%d:%d:%s" % [sim.get_instance_id(), sim.next_id, sim.road_revision, sim.buildings.size(), show_grid]
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
		if not visual_positions.has(c.id) or Vector2(visual_positions[c.id]).distance_to(c.pos) > 3.0:
			visual_positions[c.id] = c.pos
		elif sim.speed > 0.0:
			visual_positions[c.id] = Vector2(visual_positions[c.id]).lerp(c.pos, 1.0 - exp(-delta * 18.0))

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
	var atlas_id: int = Catalog.definition(b.kind).atlas
	var color := Color.WHITE if b.complete else Color(0.80, 0.83, 0.76, 0.48)
	_draw_atlas(BUILDINGS, atlas_id, Vector2i(3, 2), rect, color)
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
	var p := project(visual_positions.get(c.id, c.pos))
	var moving: bool = not c.route.is_empty()
	var bob: float = sin(c.phase * 7.0) * 1.0 if moving or c.state == "working" else 0.0
	if c.id == selected_citizen:
		draw_arc(p, 16, 0, TAU, 24, Color(1, 0.86, 0.49), 2.0)
	var direction: Vector2 = c.direction
	var row: int = 0 if direction.x >= absf(direction.y) else (3 if -direction.x >= absf(direction.y) else (1 if direction.y > 0 else 2))
	var frame: int = int(c.phase * 6) % 4 if moving or c.state in ["working", "constructing"] else 0
	_draw_atlas(CITIZENS, row * 4 + frame, Vector2i(4, 4), Rect2(p + Vector2(-23, -43 + bob), Vector2(46, 46)))
	if not c.cargo.is_empty():
		var resource: String = c.cargo.keys()[0]
		var color: Color = {"wood": Color(0.44, 0.26, 0.10), "planks": Color(0.83, 0.64, 0.35), "food": Color(0.90, 0.75, 0.28)}[resource]
		draw_rect(Rect2(p + Vector2(3, -22 + bob), Vector2(13, 8)), color)
		draw_line(p + Vector2(5, -20 + bob), p + Vector2(14, -20 + bob), color.lightened(0.2), 1.0)
	if c.state == "working" or c.state == "constructing":
		var angle: float = sin(c.phase * 6) * 0.9
		var end := p + Vector2(18 + sin(angle) * 9, -22 - cos(angle) * 12)
		draw_line(p + Vector2(10, -20), end, Color(0.54, 0.37, 0.20), 2.0)
		draw_line(end, end + Vector2(5, 2), Color(0.72, 0.73, 0.61), 3.0)

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
			var atlas: int = Catalog.definition(b.kind).atlas
			var pixel := Vector2i(Vector2(atlas % 3, atlas / 3) * Vector2(512, 512) + uv * 512)
			if BUILDINGS.get_image().get_pixelv(pixel).a > 0.25:
				return b.id
	return sim.building_at(Grid.screen_to_grid(local_point)).get("id", -1)
