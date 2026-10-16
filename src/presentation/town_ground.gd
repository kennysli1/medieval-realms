extends Polygon2D
## One textured ground surface; topology and materials come from the saved road graph.

const SHADER = preload("res://src/presentation/town_ground.gdshader")
const GRASS = preload("res://assets/third_party/polyhaven/aerial_grass_rock.jpg")
const DIRT = preload("res://assets/third_party/polyhaven/brown_mud_dry.jpg")
const STONE = preload("res://assets/third_party/polyhaven/cobblestone_floor_08.jpg")
var road_image: Image
var road_texture: ImageTexture

func _ready() -> void:
	show_behind_parent = true
	polygon = PackedVector2Array([Vector2(0, -32), Vector2(2048, 992), Vector2(0, 2016), Vector2(-2048, 992)])
	uv = PackedVector2Array([Vector2.ZERO, Vector2(1024, 0), Vector2(1024, 1024), Vector2(0, 1024)])
	texture = GRASS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("grass_texture", GRASS)
	shader_material.set_shader_parameter("dirt_texture", DIRT)
	shader_material.set_shader_parameter("stone_texture", STONE)
	material = shader_material
	road_image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	road_texture = ImageTexture.create_from_image(road_image)
	material.set_shader_parameter("road_map", road_texture)

func refresh(sim: RefCounted, view: Node2D) -> void:
	road_image.fill(Color(0, 0, 0, 1))
	for cell in sim.roads:
		road_image.set_pixelv(cell, Color(1, 1 if sim.road_surface(cell) == "stone" else 0, 0, 1))
	road_texture.update(road_image)
	var gates := PackedVector4Array()
	for b in sim.buildings:
		if sim.roads.has(b.entry) and gates.size() < 32:
			var point: Vector2 = view.building_door(b)
			var end := Vector2((point.x / 64.0 + point.y / 32.0) * 0.5, (point.y / 32.0 - point.x / 64.0) * 0.5)
			gates.append(Vector4(b.entry.x, b.entry.y, end.x, end.y))
	material.set_shader_parameter("gate_count", gates.size())
	# Godot expects the declared array length even when only the first entries are used.
	gates.resize(32)
	material.set_shader_parameter("gates", gates)
	material.set_shader_parameter("has_square", view.has_village_square())
	material.set_shader_parameter("show_grid", view.show_grid)
