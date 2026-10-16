extends SceneTree
## Reproducible sprite baking from Quaternius CC0 rigs, using the project's Godot renderer.
## Run with a graphical driver: godot --path . --script res://tools/bake_residents.gd

const PROFILES: Array[String] = ["farmer", "medieval_woman", "adventurer_man", "adventurer_woman"]
const ACTIONS: Array[String] = ["idle", "walk", "carry", "run", "wave", "work", "chop"]
const ANIMATIONS: Array[String] = ["Idle_Neutral", "Walk", "Walk", "Run", "Wave", "Interact", "Sword_Slash"]
const CELL := Vector2i(96, 112)
const FRAMES := 8
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var metadata: Dictionary = {"profiles": PROFILES, "actions": ACTIONS, "frames": FRAMES, "directions": 4, "cell": [96, 112], "source": "Quaternius Ultimate Modular Men / Women (CC0)"}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.95, 0.85)
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	stage.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 1.2
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	stage.add_child(camera)
	camera.position = Vector3(0, 3.9, 5.196)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.current = true
	await process_frame
	metadata.pivot = [camera.unproject_position(Vector3.ZERO).x, camera.unproject_position(Vector3.ZERO).y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/baked/residents"))
	for profile in PROFILES:
		await _bake(profile)
	var file := FileAccess.open("res://assets/baked/residents/atlas.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("Resident baking complete: ", PROFILES.size(), " models, ", ACTIONS.size(), " actions, four directions, eight frames.")
	quit()

func _bake(profile: String) -> void:
	var model: Node3D = load("res://assets/third_party/quaternius/%s.gltf" % profile).instantiate()
	stage.add_child(model)
	# The source medieval woman includes a sword; residents use task-specific tools instead.
	var sword := model.find_child("Sword", true, false)
	if sword is GeometryInstance3D:
		sword.visible = false
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = _skeleton(model)
	if player == null or skeleton == null:
		push_error("Missing animation rig: " + profile)
		quit(1)
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	print(profile, " clips: ", player.get_animation_list())
	var carry_arms: Dictionary = {}
	player.play("Interact")
	player.seek(player.get_animation("Interact").length * 0.35, true)
	player.advance(0)
	for name in ["UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R", "Wrist.L", "Wrist.R"]:
		var index := skeleton.find_bone(name)
		if index >= 0:
			carry_arms[index] = skeleton.get_bone_pose_rotation(index)
	var atlas := Image.create(CELL.x * FRAMES, CELL.y * 4 * ACTIONS.size(), false, Image.FORMAT_RGBA8)
	var hands: Array = []
	atlas.fill(Color.TRANSPARENT)
	for action_index in range(ACTIONS.size()):
		var clip: String = ANIMATIONS[action_index]
		if not player.has_animation(clip):
			push_error("Missing source clip: " + clip)
			quit(1)
			return
		for direction in range(4):
			model.rotation.y = [PI / 4, -PI / 4, PI * 3 / 4, -PI * 3 / 4][direction]
			for frame in range(FRAMES):
				player.play(clip)
				player.seek(player.get_animation(clip).length * float(frame) / FRAMES, true)
				player.advance(0)
				if ACTIONS[action_index] == "carry":
					for index in carry_arms:
						skeleton.set_bone_pose_rotation(index, carry_arms[index])
				var root_bone := skeleton.find_bone("Root")
				if root_bone >= 0:
					var position := skeleton.get_bone_pose_position(root_bone)
					skeleton.set_bone_pose_position(root_bone, Vector3(0, position.y, 0))
				await process_frame
				await RenderingServer.frame_post_draw
				var hand_points: Array = []
				for bone_name in ["Wrist.L", "Wrist.R"]:
					var bone := skeleton.find_bone(bone_name)
					var point := camera.unproject_position(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
					hand_points.append([snappedf(point.x, 0.01), snappedf(point.y, 0.01)])
				hands.append(hand_points)
				var image := viewport.get_texture().get_image()
				atlas.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(frame * CELL.x, (action_index * 4 + direction) * CELL.y))
	var path := "res://assets/baked/residents/%s.png" % profile
	if atlas.save_png(path) != OK:
		push_error("Cannot save baked atlas: " + path)
		quit(1)
	print("Baked ", path)
	metadata[profile] = {"hands": hands}
	model.queue_free()
	await process_frame

func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _skeleton(child)
		if found != null:
			return found
	return null
