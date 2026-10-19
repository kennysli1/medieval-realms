extends SceneTree

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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/pixel-proof/frames.json"))
	for sheet in data:
		var texture: Texture2D = load("res://assets/generated/pixel-proof/%s.png" % sheet)
		var image := texture.get_image()
		var valid := true
		for f in data[sheet].frames:
			var rect := Rect2i(f.region[0],f.region[1],f.region[2],f.region[3])
			valid = valid and Rect2i(0,0,image.get_width(),image.get_height()).encloses(rect)
			valid = valid and f.pivot[0] > 0 and f.pivot[0] < rect.size.x and f.pivot[1] > 0 and f.pivot[1] < rect.size.y
		check(valid,sheet+" complete alpha regions and boot anchors fit their source")
		var a: Array = data[sheet].frames[0].region
		var b: Array = data[sheet].frames[1].region
		check(image.get_region(Rect2i(a[0],a[1],a[2],a[3])).get_data() != image.get_region(Rect2i(b[0],b[1],b[2],b[3])).get_data(),sheet+" contains distinct animation frames")
	for mode in ["resident","battle"]:
		var scene: Node2D = load("res://scenes/pixel-proof/%s.tscn" % mode).instantiate()
		root.add_child(scene)
		await process_frame
		scene.set_process(false)
		check(scene.actors.size() == (1 if mode == "resident" else 2),mode+" creates the expected 2D characters")
		if mode == "resident":
			scene.time = 1
			scene._update_actors()
			check(scene.actors[0].scale.x < 0 and scene.actors[0].last_frame.begins_with("resident:0"),"Outbound resident faces left and uses walk cels")
			scene.time = 4
			scene._update_actors()
			check(scene.actors[0].scale.x > 0 and scene.actors[0].last_frame.begins_with("resident-spaced:1"),"Returning resident uses carrying cels")
			scene.time = 7.1
			scene._update_actors()
			check(scene.actors[0].last_frame.begins_with("resident-spaced:2") and scene.effect_age == 0,"Chop cels trigger the wood impact")
		else:
			scene.time = 2.75
			scene._update_actors()
			check(scene.actors[0].last_frame == "knight:1:2" and scene.actors[1].last_frame == "knight:2:1","Sword contact drives attacker and recoil cels together")
			check(scene.actors[1].material.get_shader_parameter("red_team") == true and scene.effect_age == 0,"Opponent palette and impact effects are driven")
			scene.time = 4.75
			scene._update_actors()
			check(scene.actors[1].last_frame == "knight:1:2" and scene.actors[0].last_frame == "knight:2:1","Opponent can counterattack")
		var positions: Array = scene.actors.map(func(a: Sprite2D) -> Vector2: return a.position)
		var before: float = scene.time
		var age: float = scene.effect_age
		scene._pause()
		scene._process(.05)
		check(scene.time == before and scene.effect_age == age and positions == scene.actors.map(func(a: Sprite2D) -> Vector2: return a.position),mode+" pause freezes choreography and effects")
		scene._restart()
		check(scene.time == 0 and scene.last_impact == -1 and not scene.paused,mode+" replay resets the animation")
		scene.queue_free()
		await process_frame
	print("Pixel proof checks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
