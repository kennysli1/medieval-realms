extends SceneTree
## Exercise the actual scene controls and viewport input, including screen/grid mapping.

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._set_speed(0.0)
	check(scene.sim.citizens.size() == 20, "Scene starts a populated town")
	scene.tool_buttons.road.pressed.emit()
	check(scene.tool == "road", "Road button binding")
	scene.tool_buttons.house.pressed.emit()
	check(scene.tool == "house", "Building button binding")
	var position: Vector2 = scene.world.to_global(scene.world.project(Vector2(18, 21)))
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = position
	click.global_position = position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	check(scene.sim.buildings.size() == 8, "Viewport click places building on grid")
	check(scene.tool == "select", "Successful placement exits build mode")
	if scene.sim.buildings.size() == 8:
		check(scene.sim.buildings[-1].cell == Vector2i(18, 21), "Mouse projection selects intended cell")
		check(scene.connect_button.visible, "Disconnected building offers road connection")
		scene.connect_button.pressed.emit()
		check(scene.sim.connected(scene.sim.buildings[-1]), "Inspector connects construction road")
		var previous_variant: int = scene.sim.buildings[-1].get("variant", int(scene.sim.buildings[-1].id) % 3)
		scene.style_button.pressed.emit()
		check(scene.sim.buildings[-1].variant != previous_variant, "Inspector changes chosen house appearance")
	scene.speed_buttons[4].pressed.emit()
	check(scene.sim.speed == 4.0, "Speed button updates shared simulation")
	scene.speed_buttons[0].pressed.emit()
	check(scene.sim.speed == 0.0, "Pause button updates shared simulation")
	scene.world.selected_citizen = 1
	scene.world.selected_building = -1
	scene._refresh_ui()
	check(scene.inspect_name.text == "艾伦", "Citizen inspector shows selected resident")
	for kind in scene.tool_buttons:
		var button: Button = scene.tool_buttons[kind]
		var contents: VBoxContainer = button.get_child(0)
		check(contents.size.x > 0 and contents.size.y > 0, "Toolbar content has layout: " + kind)
		for child in contents.get_children():
			if child is TextureRect:
				check(child.size.y >= 40 and child.texture != null, "Asset thumbnail has texture and size: " + kind)
	# Sample bounds must stay inside each PNG and retain a stable ground pivot.
	var art = load("res://src/presentation/town_art.gd")
	var valid_frames := true
	for working in [false, true]:
		var texture: Texture2D = art.WORK if working else art.WALK
		for row in range(3 if working else 4):
			for column in range(4 if working else 6):
				var frame: Dictionary = art.animation_frame(working, row, column)
				var rect: Rect2 = art.frame_region(frame)
				valid_frames = valid_frames and Rect2(Vector2.ZERO, texture.get_size()).encloses(rect)
				valid_frames = valid_frames and frame.pivot[0] >= 0 and frame.pivot[0] <= rect.size.x and frame.pivot[1] <= rect.size.y
	check(valid_frames, "All walk/work frames and feet pivots fit their source atlases")
	scene._set_speed(1.0)
	for i in range(30):
		scene.sim.update(0.1)
		scene.world.update_visuals(0.1)
	check(not scene.world.walk_cycles.is_empty(), "Movement drives walking cycles")
	scene._set_speed(0.0)
	var paused_positions: Dictionary = scene.world.visual_positions.duplicate()
	var paused_cycles: Dictionary = scene.world.walk_cycles.duplicate()
	for i in range(10):
		scene.world.update_visuals(0.1)
	check(scene.world.visual_positions == paused_positions and scene.world.walk_cycles == paused_cycles, "Pause freezes visual positions and footsteps")
	print("City UI checks: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
