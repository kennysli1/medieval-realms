extends Node2D
## Small 2D animation proof, independent from town saves and formal combat rules.

const Actor = preload("res://src/pixel_proof/actor.gd")
const YARD = preload("res://assets/generated/pixel-proof/yard.png")
@export_enum("resident","battle") var demo_mode := "resident"
var time := 0.0
var paused := false
var stage := ""
var actors: Array[Sprite2D] = []
var effects: Node2D
var effect_age := -1.0
var effect_pos := Vector2.ZERO
var last_impact := -1
var phase_label: Label
var pause_button: Button
var capture_path := ""
var frames_dir := ""
var frame_limit := 240
var frames := 0
var recording := false
var progress_bar: ProgressBar

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1280,800)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pixel-capture="):
			capture_path = arg.trim_prefix("--pixel-capture=")
		elif arg.begins_with("--pixel-frames="):
			frames_dir = arg.trim_prefix("--pixel-frames=")
		elif arg.begins_with("--pixel-count="):
			frame_limit = int(arg.trim_prefix("--pixel-count="))
	recording = not capture_path.is_empty() or not frames_dir.is_empty()
	if not frames_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(frames_dir)
	for i in range(1 if demo_mode == "resident" else 2):
		var actor := Actor.new()
		actor.character = "resident" if demo_mode == "resident" else "knight"
		add_child(actor)
		actors.append(actor)
	effects = Node2D.new()
	add_child(effects)
	effects.draw.connect(_draw_effects)
	_create_ui()
	_update_actors()

func _draw() -> void:
	draw_texture_rect(YARD,Rect2(0,0,1280,800),false)
	for actor in actors:
		draw_set_transform(actor.position,0,Vector2(1,.24))
		draw_circle(Vector2.ZERO,29,Color(.23,.20,.12,.22))
		draw_set_transform(Vector2.ZERO)

func _process(delta: float) -> void:
	if not paused:
		var step := 1.0/20 if recording else minf(delta,.1)
		time += step
		if effect_age >= 0:
			effect_age += step
			if effect_age > .40:
				effect_age = -1
	_update_actors()
	phase_label.text = stage
	progress_bar.value = fmod(time,12.0 if demo_mode == "resident" else 10.0)
	queue_redraw()
	effects.queue_redraw()
	if recording:
		frames += 1
		if not frames_dir.is_empty() or frames >= frame_limit:
			_capture.call_deferred(frames)
		if frames >= frame_limit:
			set_process(false)

func _update_actors() -> void:
	if demo_mode == "resident":
		_update_resident()
	else:
		_update_battle()

func _update_resident() -> void:
	var t := fmod(time,12.0)
	var actor := actors[0]
	if t < 3.2:
		stage = "01  前往木料堆 · 走路"
		actor.position = Vector2(lerpf(955,310,t/3.2),538)
		actor.pose("walk",int(time*10)%4,true)
	elif t < 6.4:
		stage = "02  运送原木 · 搬运"
		actor.position = Vector2(lerpf(310,955,(t-3.2)/3.2),538)
		actor.pose("carry",int(time*10)%4)
	elif t < 11.2:
		stage = "03  蓄力 → 劈下 → 收势 · 劳动"
		actor.position = Vector2(955,538)
		var cycle := fmod(t-6.4,.96)
		var frame := 0 if cycle < .18 else (1 if cycle < .44 else (2 if cycle < .56 else 3))
		actor.pose("work",frame)
		var impact := int((t-6.4)/.96)
		if cycle >= .44 and last_impact != impact:
			last_impact = impact
			effect_age = 0
			effect_pos = Vector2(1030,526)
	else:
		stage = "04  收工停留 · 循环重播"
		actor.position = Vector2(955,538)
		actor.pose("idle",1)
		last_impact = -1

func _update_battle() -> void:
	var t := fmod(time,10.0)
	var left := 530.0
	var right := 690.0
	var a_action := "idle"
	var b_action := "idle"
	var a_frame := 0
	var b_frame := 0
	var flash_a := 0.0
	var flash_b := 0.0
	if t < 2:
		stage = "01  接近 · 双方走入交战位置"
		left = lerpf(300,530,t/2)
		right = lerpf(980,690,t/2)
		a_action = "walk"
		b_action = "walk"
		a_frame = int(time*7)%4
		b_frame = int(time*7+.5)%4
		last_impact = -1
	elif t < 4:
		stage = "02  蓝方挥剑 · 红方格挡与后仰"
		var hit := _duel_phase(t-2)
		a_action = "attack"
		a_frame = hit.frame
		b_action = "hurt"
		b_frame = hit.reaction
		right += hit.recoil
		flash_b = hit.flash
		_trigger_hit(0,t-2,Vector2(661,475))
	elif t < 6:
		stage = "03  红方反击 · 蓝方格挡与后仰"
		var hit := _duel_phase(t-4)
		b_action = "attack"
		b_frame = hit.frame
		a_action = "hurt"
		a_frame = hit.reaction
		left -= hit.recoil
		flash_a = hit.flash
		_trigger_hit(1,t-4,Vector2(559,475))
	elif t < 8:
		stage = "04  双方交锋 · 刀光与命中反馈"
		var hit := _duel_phase(t-6)
		a_action = "attack"
		b_action = "attack"
		a_frame = hit.frame
		b_frame = hit.frame
		_trigger_hit(2,t-6,Vector2(611,475))
	else:
		stage = "05  拉开距离 · 重整后循环"
		left = lerpf(530,300,(t-8)/2)
		right = lerpf(690,980,(t-8)/2)
		a_action = "walk"
		b_action = "walk"
		a_frame = int(time*7)%4
		b_frame = int(time*7+.5)%4
	actors[0].position = Vector2(left,575)
	actors[1].position = Vector2(right,575)
	actors[0].pose(a_action,a_frame,t >= 8,false,flash_a)
	actors[1].pose(b_action,b_frame,t < 8,true,flash_b)

func _duel_phase(t: float) -> Dictionary:
	var frame := 0 if t < .36 else (1 if t < .72 else (2 if t < .96 else 3))
	var reaction := 0 if t < .72 else (1 if t < .94 else (2 if t < 1.25 else 3))
	var recoil := sin(clampf((t-.72)/.60,0,1)*PI)*16
	var flash := 1.0-clampf((t-.72)/.18,0,1) if t >= .72 else 0.0
	return {"frame":frame,"reaction":reaction,"recoil":recoil,"flash":flash}

func _trigger_hit(index: int, elapsed: float, pos: Vector2) -> void:
	if elapsed >= .72 and last_impact != index:
		last_impact = index
		effect_age = 0
		effect_pos = pos

func _draw_effects() -> void:
	if effect_age < 0:
		return
	var age := effect_age/.40
	var color := Color("e4be68") if demo_mode == "resident" else Color("fff0b5")
	color.a = 1-age
	for i in range(8):
		var angle := i*TAU/8-.4
		var p := effect_pos+Vector2(cos(angle),sin(angle))*(5+age*31)
		if demo_mode == "resident":
			effects.draw_rect(Rect2(p,Vector2(4,3)),color)
		else:
			effects.draw_line(p,p+Vector2(cos(angle),sin(angle))*8*(1-age),color,3)
	if demo_mode == "battle" and age < .5:
		effects.draw_arc(effect_pos-Vector2(25,0),29,-1.0,1.3,8,Color(1,.94,.72,(1-age*2)*.8),4)

func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	theme.default_font = font
	theme.default_font_size = 16
	root.theme = theme
	var top := _panel(root,Rect2(24,20,1232,88))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	top.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title := Label.new()
	title.text = "橡木谷  /  居民搬运与劳动" if demo_mode == "resident" else "橡木谷  /  盾剑交锋"
	title.add_theme_font_size_override("font_size",25)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "二维像素角色 · 动作可行性样片 · 独立于正式游戏存档"
	subtitle.add_theme_color_override("font_color",Color("d2c39e"))
	column.add_child(subtitle)
	for entry in [["居民","resident"],["战斗","battle"]]:
		var mode: String = entry[1]
		var button := _button(entry[0],func() -> void: get_tree().change_scene_to_file("res://scenes/pixel-proof/%s.tscn" % mode))
		button.disabled = mode == demo_mode
		row.add_child(button)
	pause_button = _button("暂停",_pause)
	row.add_child(pause_button)
	row.add_child(_button("重播",_restart))
	var bottom := _panel(root,Rect2(24,687,1232,92))
	var stack := VBoxContainer.new()
	bottom.add_child(stack)
	phase_label = Label.new()
	phase_label.add_theme_color_override("font_color",Color("f4d290"))
	phase_label.add_theme_font_size_override("font_size",20)
	stack.add_child(phase_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 5
	progress_bar.max_value = 12 if demo_mode == "resident" else 10
	progress_bar.show_percentage = false
	stack.add_child(progress_bar)
	var hint := Label.new()
	hint.text = "空格 暂停 / 继续    R 重播    1 居民    2 战斗      |      仅演示动作，不结算资源与战损"
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("d2c39e"))
	stack.add_child(hint)

func _panel(parent: Control, rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.17,.20,.14,.96)
	style.border_color = Color("bfa572")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	return panel

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(78,42)
	button.pressed.connect(callback)
	return button

func _pause() -> void:
	paused = not paused
	pause_button.text = "继续" if paused else "暂停"

func _restart() -> void:
	time = 0
	paused = false
	last_impact = -1
	effect_age = -1
	pause_button.text = "暂停"
	_update_actors()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _pause()
			KEY_R: _restart()
			KEY_1: get_tree().change_scene_to_file("res://scenes/pixel-proof/resident.tscn")
			KEY_2: get_tree().change_scene_to_file("res://scenes/pixel-proof/battle.tscn")

func _capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	var path := capture_path if frames_dir.is_empty() else frames_dir.path_join("%04d.png" % index)
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Cannot capture pixel proof: "+path)
		get_tree().quit(1)
	if frames >= frame_limit:
		print("Pixel proof captured: ",demo_mode," frames=",frames)
		get_tree().quit()
