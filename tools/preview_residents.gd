extends SceneTree
## Render the actual runtime atlases for visual review; no external image compositing.

class Board extends Node2D:
	const Residents = preload("res://src/presentation/resident_sprites.gd")
	var font := SystemFont.new()
	func _ready() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1120, 670), Color("20392e"))
		draw_string(font, Vector2(28, 38), "橡木谷 · 居民骨骼动作 / 游戏内实际素材", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ebdfbd"))
		var labels := ["待机", "行走", "搬运姿态", "跑动", "挥手", "操作", "劈砍"]
		for action in range(7):
			draw_string(font, Vector2(160 + action * 135, 78), labels[action], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d2b46d"))
		for profile in range(4):
			var y := 96 + profile * 133
			draw_string(font, Vector2(28, y + 62), Residents.NAMES[profile], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ebdfbd"))
			for action in range(7):
				var rect := Rect2(145 + action * 135, y, 118, 124)
				draw_style_box(_card(), rect)
				draw_texture_rect_region(Residents.TEXTURES[profile], Rect2(rect.position + Vector2(11, 0), Vector2(96, 112)), Residents.region(Residents.ACTIONS[action], 0, 3))
		draw_string(font, Vector2(28, 650), "4 种模型 × 7 组动作 × 4 方向 × 8 帧 · Quaternius CC0 · Godot 原生烘焙", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("a6b5a2"))
	func _card() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("314c3b")
		style.set_corner_radius_all(8)
		return style

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1120, 670)
	root.content_scale_size = Vector2i(1120, 670)
	root.add_child(Board.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/screenshots/resident-actions.png"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("Resident preview saved: ", path)
	quit()
