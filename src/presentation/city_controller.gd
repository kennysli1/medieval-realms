extends Node2D

const Simulation = preload("res://src/city/city_simulation.gd")
const Save = preload("res://src/city/city_save.gd")
const View = preload("res://src/presentation/city_view.gd")
const Catalog = preload("res://src/city/building_catalog.gd")
const Grid = preload("res://src/core/isometric_grid.gd")
const BG := Color("182d28")
const GOLD := Color("d8b877")
const TEXT := Color("efe7ce")
const MUTED := Color("a4b6a2")

var sim = Simulation.new()
var world: Node2D
var ui: Control
var top: PanelContainer
var dock: PanelContainer
var inspector: PanelContainer
var chapter: PanelContainer
var resource_labels: Dictionary = {}
var stats_label: Label
var objectives: Label
var inspect_name: Label
var inspect_info: Label
var inspect_image: TextureRect
var inspect_status: Label
var connect_button: Button
var remove_button: Button
var upgrade_button: Button
var toast: Label
var time_label: Label
var save_label: Label
var tool_buttons: Dictionary = {}
var speed_buttons: Dictionary = {}
var tool: String = "select"
var zoom: float = 0.68
var pan := Vector2(0, 0)
var display_timer: float = 0.0
var capture_path: String = ""
var capture_frame: int = 0
var capture_started_ms: int = 0
var start_demo: bool = false
var help_dialog: AcceptDialog
var new_dialog: ConfirmationDialog

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("20382e"))
	sim.start_new()
	world = View.new()
	world.sim = sim
	add_child(world)
	_create_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		if argument == "--demo":
			start_demo = true
	if start_demo:
		for i in range(800):
			sim.update(0.1)
		world.selected_building = 6
	_refresh_ui()
	capture_started_ms = Time.get_ticks_msec()

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG, 0.97)
	style.border_color = Color(0.53, 0.57, 0.40, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, min_size: Vector2 = Vector2(0, 34)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.pressed.connect(callback)
	return button

func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 15
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("31483b") if style_name == "hover" else (Color("5b6346") if style_name == "pressed" else Color("243a31"))
		style.border_color = GOLD if style_name in ["pressed", "focus"] else Color("49604b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 10
		style.content_margin_right = 10
		theme.set_stylebox(style_name, "Button", style)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	ui.theme = theme
	top = _panel()
	ui.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	top.add_child(row)
	var title_column := VBoxContainer.new()
	title_column.custom_minimum_size.x = 205
	row.add_child(title_column)
	title_column.add_child(_label("橡 木 谷", 24))
	title_column.add_child(_label("O A K E N V A L E  /  中世纪领地", 10, GOLD))
	for key in ["wood", "planks", "food"]:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 95
		row.add_child(column)
		column.add_child(_label(Catalog.resource_name(key), 12, MUTED))
		var value := _label("0", 24, TEXT)
		column.add_child(value)
		resource_labels[key] = value
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	time_label = _label("", 13, MUTED)
	row.add_child(time_label)
	for value in [0, 1, 2, 4]:
		var button := _button("Ⅱ" if value == 0 else "%d×" % value, _set_speed.bind(float(value)), Vector2(42, 40))
		button.toggle_mode = true
		row.add_child(button)
		speed_buttons[value] = button
	row.add_child(_button("?", _show_help, Vector2(34, 40)))
	_create_chapter()
	_create_inspector()
	_create_dock()
	toast = _label("", 14, TEXT)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast)
	help_dialog = AcceptDialog.new()
	help_dialog.title = "橡木谷 · 操作说明"
	help_dialog.dialog_text = "左键：选择建筑 / 居民，或放置建筑\n道路模式可按住左键连续铺路\n右键 / Esc：返回选择模式\n中键拖拽 / WASD / 方向键：移动镜头\n滚轮：缩放；Home：镜头归位；G：网格\n空格：暂停 / 继续；1～6：道路与建筑；X：拆除\nCtrl+S：保存；Ctrl+L：读取\n\n黄色菱形是建筑入口，必须接入主仓库道路。\n可选择建筑后点“接通入口道路”自动修建连接。\n\n原型链条：伐木 → 原木入仓 → 锯木 → 木板入仓。\n食物由农田供给，每 45 秒居民消耗一餐。\n积攒 40 木板后可升级领主府。\n世界地图与军队出征将在后续版本加入。"
	ui.add_child(help_dialog)
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = "重新开始"
	new_dialog.dialog_text = "重新建立橡木谷？当前未保存的进度将丢失。已有手动存档会保留。"
	new_dialog.confirmed.connect(_new_city)
	ui.add_child(new_dialog)

func _create_chapter() -> void:
	chapter = _panel()
	ui.add_child(chapter)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	chapter.add_child(column)
	column.add_child(_label("第一章  /  A NEW HOME", 11, GOLD))
	column.add_child(_label("让城镇活起来", 21))
	var subtitle := _label("从一条路，到一座城。", 13, MUTED)
	column.add_child(subtitle)
	objectives = _label("", 14)
	objectives.add_theme_constant_override("line_spacing", 10)
	column.add_child(objectives)
	var separator := HSeparator.new()
	column.add_child(separator)
	stats_label = _label("", 13, MUTED)
	stats_label.add_theme_constant_override("line_spacing", 6)
	column.add_child(stats_label)

func _create_inspector() -> void:
	inspector = _panel()
	ui.add_child(inspector)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	inspector.add_child(column)
	column.add_child(_label("领 地 手 记  /  INSPECT", 11, GOLD))
	inspect_name = _label("城镇概览", 22)
	column.add_child(inspect_name)
	inspect_image = TextureRect.new()
	inspect_image.custom_minimum_size = Vector2(0, 155)
	inspect_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspect_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(inspect_image)
	inspect_status = _label("", 15, GOLD)
	column.add_child(inspect_status)
	inspect_info = _label("", 14, MUTED)
	inspect_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_info.custom_minimum_size.x = 230
	inspect_info.add_theme_constant_override("line_spacing", 6)
	column.add_child(inspect_info)
	connect_button = _button("接通入口道路", _connect_selected)
	column.add_child(connect_button)
	upgrade_button = _button("升级领主府 · 40 木板", _upgrade_selected)
	column.add_child(upgrade_button)
	remove_button = _button("拆除 / 取消建造", _remove_selected)
	column.add_child(remove_button)

func _create_dock() -> void:
	dock = _panel()
	ui.add_child(dock)
	var column := VBoxContainer.new()
	dock.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var heading := VBoxContainer.new()
	heading.custom_minimum_size.x = 60
	row.add_child(heading)
	heading.add_child(_label("营建", 20))
	heading.add_child(_label("BUILD", 10, GOLD))
	heading.add_child(_button("选择", _set_tool.bind("select"), Vector2(56, 32)))
	var items: Array[String] = ["road", "house", "warehouse", "woodcutter", "sawmill", "farm", "demolish"]
	for i in range(items.size()):
		var kind: String = items[i]
		var button := _button("", _set_tool.bind(kind), Vector2(115, 90))
		button.toggle_mode = true
		row.add_child(button)
		tool_buttons[kind] = button
		var contents := VBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_top = 4
		contents.offset_bottom = -4
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(contents)
		if Catalog.DEFINITIONS.has(kind):
			var image := TextureRect.new()
			image.texture = _atlas_texture(Catalog.definition(kind).atlas)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.custom_minimum_size = Vector2(0, 43)
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			contents.add_child(image)
		else:
			var symbol := _label("╱╲" if kind == "road" else "×", 28, GOLD)
			symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			contents.add_child(symbol)
		var name_label := _label(("%d  " % (i + 1) if i < 6 else "X  ") + ({"road": "铺设道路", "demolish": "拆除"}.get(kind, Catalog.definition(kind).get("name", kind))), 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contents.add_child(name_label)
		var cost := _label(Catalog.cost_text(Catalog.definition(kind).get("cost", {})) if Catalog.DEFINITIONS.has(kind) else ("免费规划" if kind == "road" else "选择地块"), 10, MUTED)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contents.add_child(cost)
		for child in contents.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 124
	row.add_child(actions)
	actions.add_child(_button("保存城镇", _save))
	actions.add_child(_button("读取存档", _load))
	var restart := _button("重新开始", func() -> void: new_dialog.popup_centered())
	actions.add_child(restart)
	save_label = _label("左键操作 · 右键取消 · 中键移动 · 滚轮缩放 · 空格暂停", 11, MUTED)
	column.add_child(save_label)

func _atlas_texture(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = View.BUILDINGS
	texture.region = Rect2(Vector2(index % 3, index / 3) * 512.0, Vector2(512, 512))
	return texture

func _layout() -> void:
	var size := get_viewport_rect().size
	top.position = Vector2(24, 20)
	top.size = Vector2(size.x - 48, 82)
	chapter.position = Vector2(24, 128)
	chapter.size = Vector2(224, 0)
	inspector.position = Vector2(size.x - 300, 128)
	inspector.size = Vector2(276, 0)
	dock.position = Vector2(24, size.y - 164)
	dock.size = Vector2(size.x - 48, 140)
	toast.position = Vector2(260, 112)
	toast.size = Vector2(maxf(200, size.x - 580), 42)
	_apply_camera()

func _apply_camera() -> void:
	var size := get_viewport_rect().size
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(size.x * 0.49, size.y * 0.47) + pan - world.project(Vector2(15, 12)) * zoom

func _process(delta: float) -> void:
	sim.update(delta)
	world.update_visuals(delta)
	var direction := Vector2.ZERO
	if not help_dialog.visible and not new_dialog.visible:
		direction.x = float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		direction.y = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	if direction != Vector2.ZERO:
		pan += direction * delta * 550.0
		_apply_camera()
	world.hover_cell = Grid.screen_to_grid(world.get_local_mouse_position())
	world.tool = tool
	world.queue_redraw()
	display_timer += delta
	if display_timer >= 0.2:
		display_timer = 0.0
		_refresh_ui()
	if not capture_path.is_empty():
		capture_frame += 1
		if capture_frame == 90:
			_capture()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(capture_path)
	print("City screenshot saved: ", capture_path)
	print("Rendered 90 frames in %.2f seconds" % ((Time.get_ticks_msec() - capture_started_ms) / 1000.0))
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_set_tool("select")
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_click_map(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var mouse_before := world.get_local_mouse_position()
			zoom = clampf(zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.45, 1.6)
			_apply_camera()
			pan += get_global_mouse_position() - world.to_global(mouse_before)
			_apply_camera()
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			pan += event.relative
			_apply_camera()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and tool == "road":
			sim.set_road(Grid.screen_to_grid(world.to_local(event.position)), true)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_S:
			_save()
		elif event.ctrl_pressed and event.keycode == KEY_L:
			_load()
		elif event.keycode == KEY_SPACE:
			_set_speed(1.0 if sim.speed == 0 else 0.0)
		elif event.keycode == KEY_ESCAPE:
			_set_tool("select")
		elif event.keycode == KEY_HOME:
			pan = Vector2.ZERO
			zoom = 0.68
			_apply_camera()
		elif event.keycode == KEY_G:
			world.show_grid = not world.show_grid
		elif event.keycode == KEY_X:
			_set_tool("demolish")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			_set_tool(["road", "house", "warehouse", "woodcutter", "sawmill", "farm"][event.keycode - KEY_1])

func _click_map(screen_position: Vector2) -> void:
	var local_point: Vector2 = world.to_local(screen_position)
	var cell := Grid.screen_to_grid(local_point)
	if tool == "road":
		sim.set_road(cell, true)
	elif tool == "demolish":
		var b := sim.building_at(cell)
		if not b.is_empty():
			sim.demolish(b.id)
		else:
			sim.set_road(cell, false)
	elif tool in Catalog.ORDER:
		var id: int = sim.place_building(tool, cell)
		if id != -1:
			world.selected_building = id
			world.selected_citizen = -1
			_set_tool("select")
	else:
		world.selected_citizen = -1
		world.selected_building = -1
		for c in sim.citizens:
			if world.project(c.pos).distance_to(local_point + Vector2(0, 18)) < 18:
				world.selected_citizen = c.id
				break
		if world.selected_citizen == -1:
			world.selected_building = world.pick_building(local_point)
	_refresh_ui()

func _set_tool(value: String) -> void:
	tool = value
	for key in tool_buttons:
		tool_buttons[key].set_pressed_no_signal(key == value)
	if Catalog.DEFINITIONS.has(value):
		sim.message = "放置%s · %s · 黄色菱形为入口" % [Catalog.definition(value).name, Catalog.cost_text(Catalog.definition(value).cost)]
	elif value == "road":
		sim.message = "按住左键连续铺路；产业入口需连接主仓库。"
	elif value == "demolish":
		sim.message = "点击建筑占地拆除，或点击道路移除。未消耗的建材会退回。"

func _set_speed(value: float) -> void:
	sim.speed = value
	_refresh_ui()

func _show_help() -> void:
	help_dialog.popup_centered(Vector2i(640, 550))

func _connect_selected() -> void:
	sim.connect_building(world.selected_building)
	_refresh_ui()

func _remove_selected() -> void:
	if sim.demolish(world.selected_building):
		world.selected_building = -1
	_refresh_ui()

func _upgrade_selected() -> void:
	sim.upgrade_keep()
	_refresh_ui()

func _save() -> void:
	if Save.save_city(sim):
		sim.message = "城镇已保存 · 下次可继续当前生产与建设"
	else:
		sim.message = Save.last_error
	_refresh_ui()

func _load() -> void:
	var loaded: RefCounted = Save.load_city()
	if loaded == null:
		sim.message = Save.last_error
	else:
		sim = loaded
		world.sim = sim
		world.visual_positions.clear()
		world.selected_building = -1
		world.selected_citizen = -1
	_refresh_ui()

func _new_city() -> void:
	sim.start_new()
	world.visual_positions.clear()
	world.selected_building = -1
	world.selected_citizen = -1
	_set_tool("select")
	_refresh_ui()

func _refresh_ui() -> void:
	for key in resource_labels:
		resource_labels[key].text = str(int(sim.inventory[key]))
	for value in speed_buttons:
		speed_buttons[value].set_pressed_no_signal(float(value) == sim.speed)
	var hours: int = 8 + int(sim.time / 45.0)
	time_label.text = "第 %d 天 · %02d:%02d\n%s" % [hours / 24 + 1, hours % 24, int(fmod(sim.time, 45.0) / 45 * 60), "已暂停" if sim.speed == 0 else "城镇运转中"]
	var working := 0
	for c in sim.citizens:
		if c.workplace != -1:
			working += 1
	stats_label.text = "居民  %d / %d 人住房\n就业  %d 人  ·  交付 %d 批\n口粮  %s" % [sim.citizens.size(), sim.population_capacity(), working, sim.deliveries, "充足" if sim.inventory.food >= 20 else "告急 · 请扩建农田"]
	var completed: int = sim.buildings.filter(func(b: Dictionary) -> bool: return b.complete).size()
	objectives.text = "%s 铺路连接生产建筑\n%s 完成 5 批货物交付\n%s 新建一座建筑\n%s 积攒木板升级领主府" % ["✓" if sim.connected(sim.by_id(5)) else "○", "✓" if sim.deliveries >= 5 else "○", "✓" if completed > 7 else "○", "✓" if sim.by_id(1).level >= 2 else "○"]
	toast.text = sim.message
	var b: Dictionary = sim.by_id(world.selected_building)
	connect_button.visible = not b.is_empty() and not sim.connected(b)
	remove_button.visible = not b.is_empty() and b.kind not in ["keep"] and b.id != sim.warehouse().id
	upgrade_button.visible = not b.is_empty() and b.kind == "keep" and b.level < 2
	if not b.is_empty():
		inspect_name.text = Catalog.definition(b.kind).name
		inspect_image.texture = _atlas_texture(Catalog.definition(b.kind).atlas)
		inspect_status.text = sim.building_status(b)
		inspect_info.text = Catalog.definition(b.kind).description + "\n\n占地 %d×%d · 入口 (%d, %d)\n等级 %d" % [b.size, b.size, b.entry.x, b.entry.y, b.level]
	elif world.selected_citizen != -1:
		for c in sim.citizens:
			if c.id == world.selected_citizen:
				inspect_name.text = c.name
				var texture := AtlasTexture.new()
				texture.atlas = View.CITIZENS
				texture.region = Rect2(Vector2.ZERO, View.CITIZENS.get_size() / 4.0)
				inspect_image.texture = texture
				inspect_status.text = sim.citizen_status(c)
				var workplace: Dictionary = sim.by_id(c.workplace)
				inspect_info.text = "职业：%s\n携带：%s\n目的地：(%d, %d)\n\n居民实际工作与运输，交付后资源才计入仓库。" % [Catalog.definition(workplace.kind).name if not workplace.is_empty() else "居民 / 建筑工", "空手" if c.cargo.is_empty() else Catalog.cost_text(c.cargo), c.target.x, c.target.y]
	else:
		inspect_name.text = "城镇概览"
		inspect_image.texture = _atlas_texture(0)
		inspect_status.text = "你的领地 · 橡木谷"
		inspect_info.text = "选择建筑查看生产状态，选择居民观察工作与搬运。\n\n下方营建栏可扩建街区。建筑放置后，记得连接黄色入口。\n\n需要帮助时，点击右上角 ?。"
