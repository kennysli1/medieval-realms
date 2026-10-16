class_name TownArt
extends RefCounted
## Atlas regions and measured foot pivots. Sampling preserves source PNG alpha.

const BUILDINGS: Texture2D = preload("res://assets/generated/buildings.png")
const HOUSES: Texture2D = preload("res://assets/generated/village-houses-v2.png")
const WALK: Texture2D = preload("res://assets/generated/citizens-walk-v2.png")
const WORK: Texture2D = preload("res://assets/generated/citizens-work-v2.png")
const Catalog = preload("res://src/city/building_catalog.gd")
const HOUSE_NAMES: Array[String] = ["红瓦庭院", "蓝顶联排", "茅草农舍"]
static var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/sprite-layout-v2.json"))
static var images: Dictionary = {}

static func house_region(variant: int) -> Rect2:
	var r: Array = layout["village-houses-v2.png"].regions[posmod(variant, 3)]
	return Rect2(r[0], r[1], r[2], r[3])

static func house_variant(b: Dictionary) -> int:
	return posmod(int(b.get("variant", int(b.id) % 3)), 3)

static func well_region() -> Rect2:
	var r: Array = layout["village-houses-v2.png"].regions[3]
	return Rect2(r[0], r[1], r[2], r[3])

static func building_source(kind: String, variant: int = 0) -> Rect2:
	if kind == "house":
		return house_region(variant)
	var index: int = Catalog.definition(kind).atlas
	return Rect2(Vector2(index % 3, index / 3) * 512, Vector2(512, 512))

static func building_texture(kind: String, variant: int = 0) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = HOUSES if kind == "house" else BUILDINGS
	result.region = building_source(kind, variant)
	return result

static func animation_frame(working: bool, row: int, column: int) -> Dictionary:
	var name := "citizens-work-v2.png" if working else "citizens-walk-v2.png"
	var columns: int = 4 if working else 6
	return layout[name].frames[row * columns + posmod(column, columns)]

static func frame_region(frame: Dictionary) -> Rect2:
	var r: Array = frame.region
	return Rect2(r[0], r[1], r[2], r[3])

static func walk_icon() -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = WALK
	result.region = frame_region(animation_frame(false, 0, 1))
	return result

static func is_opaque(kind: String, variant: int, uv: Vector2) -> bool:
	var image_key := "houses" if kind == "house" else "buildings"
	if not images.has(image_key):
		images[image_key] = (HOUSES if kind == "house" else BUILDINGS).get_image()
	var region := building_source(kind, variant)
	var point := Vector2i(region.position + uv * (region.size - Vector2.ONE))
	return images[image_key].get_pixelv(point).a > 0.25
