class_name ResidentSprites
extends RefCounted
## Four consistent CC0 characters, baked from real rigs rather than independently drawn poses.

const PROFILES: Array[String] = ["farmer", "medieval_woman", "adventurer_man", "adventurer_woman"]
const NAMES: Array[String] = ["农夫", "女村民", "男旅人", "女旅人"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/baked/residents/farmer.png"),
	preload("res://assets/baked/residents/medieval_woman.png"),
	preload("res://assets/baked/residents/adventurer_man.png"),
	preload("res://assets/baked/residents/adventurer_woman.png")]
const ACTIONS: Array[String] = ["idle", "walk", "carry", "run", "wave", "work", "chop"]
const CELL := Vector2(96, 112)
const FRAMES := 8
static var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/residents/atlas.json"))

static func appearance(c: Dictionary) -> int:
	return posmod(int(c.get("appearance", int(c.id) - 1)), PROFILES.size())

static func region(action: String, direction: int, frame: int) -> Rect2:
	var row := ACTIONS.find(action) * 4 + posmod(direction, 4)
	return Rect2(Vector2(posmod(frame, FRAMES), row) * CELL, CELL)

static func pivot() -> Vector2:
	return Vector2(metadata.pivot[0], metadata.pivot[1])

static func hand_points(profile: int, action: String, direction: int, frame: int) -> Array[Vector2]:
	var index := (ACTIONS.find(action) * 4 + posmod(direction, 4)) * FRAMES + posmod(frame, FRAMES)
	var result: Array[Vector2] = []
	var data: Array = metadata.get(PROFILES[profile], {}).get("hands", [])
	if index < data.size():
		for point in data[index]:
			result.append(Vector2(point[0], point[1]))
	return result

static func icon(c: Dictionary) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = TEXTURES[appearance(c)]
	texture.region = region("idle", 0, 0)
	return texture
