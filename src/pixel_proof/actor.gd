extends Sprite2D

const SHEETS = {
	"resident":preload("res://assets/generated/pixel-proof/resident.png"),
	"resident-spaced":preload("res://assets/generated/pixel-proof/resident-spaced.png"),
	"knight":preload("res://assets/generated/pixel-proof/knight.png")}
static var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/pixel-proof/frames.json"))
const SHADER = preload("res://src/pixel_proof/actor.gdshader")
var character := "resident"
var last_frame := ""

func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	region_filter_clip_enabled = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material

func pose(action: String, frame: int, facing_left: bool = false, red_team: bool = false, flash: float = 0.0) -> void:
	var sheet := character
	var row := 0
	if character == "resident":
		if action != "walk" and action != "idle":
			sheet = "resident-spaced"
			row = 1 if action == "carry" else 2
	else:
		row = {"walk":0,"idle":0,"attack":1,"hurt":2}.get(action,0)
	var columns: int = layout[sheet].columns
	var column := posmod(frame,columns)
	var key := "%s:%d:%d" % [sheet,row,column]
	if key != last_frame:
		var data: Dictionary = layout[sheet].frames[row*columns+column]
		texture = SHEETS[sheet]
		region_rect = Rect2(data.region[0],data.region[1],data.region[2],data.region[3])
		offset = -Vector2(data.pivot[0],data.pivot[1])
		last_frame = key
	var factor: float = 154.0/layout[sheet].reference_height
	scale = Vector2(-factor if facing_left else factor,factor)
	material.set_shader_parameter("red_team",red_team)
	material.set_shader_parameter("flash",flash)
