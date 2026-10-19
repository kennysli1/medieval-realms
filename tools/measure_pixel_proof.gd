extends SceneTree
## Read-only connected-component measurement; generated PNGs are never rewritten.

func _initialize() -> void:
	var output: Dictionary = {}
	for filename in ["resident","resident-spaced","knight"]:
		var image := Image.load_from_file("res://assets/generated/pixel-proof/%s.png" % filename)
		image.convert(Image.FORMAT_RGBA8)
		var w := image.get_width()
		var h := image.get_height()/3 if filename == "resident" else image.get_height()
		var rgba := image.get_data()
		var seen := PackedByteArray()
		seen.resize(w*h)
		var regions: Array[Rect2i] = []
		for first in range(w*h):
			if seen[first] != 0 or rgba[first*4+3] < 160:
				continue
			var stack := PackedInt32Array([first])
			seen[first] = 1
			var lo := Vector2i(w,h)
			var hi := Vector2i.ZERO
			var area := 0
			while not stack.is_empty():
				var at := stack[-1]
				stack.resize(stack.size()-1)
				var p := Vector2i(at%w,at/w)
				lo = lo.min(p)
				hi = hi.max(p)
				area += 1
				for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = p+delta
					if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h:
						continue
					var index := next.y*w+next.x
					if seen[index] == 0 and rgba[index*4+3] >= 160:
						seen[index] = 1
						stack.append(index)
			if area > 6000:
				regions.append(Rect2i(lo-Vector2i.ONE*2,hi-lo+Vector2i.ONE*5))
		var row_height := image.get_height()/3
		regions.sort_custom(func(a: Rect2i,b: Rect2i) -> bool:
			var ar := int(a.get_center().y/row_height)
			var br := int(b.get_center().y/row_height)
			return a.position.x < b.position.x if ar == br else ar < br)
		var expected := 6 if filename == "resident" else 12
		if regions.size() != expected:
			push_error("Expected %d separate cels in %s, got %d" % [expected,filename,regions.size()])
			quit(1)
			return
		var frames: Array = []
		for rect in regions:
			var sum_x := 0.0
			var count := 0
			var boot_y := 0
			for y in range(rect.end.y-25,rect.end.y):
				for x in range(rect.position.x,rect.end.x):
					var c := image.get_pixel(x,y)
					if c.a > .7 and c.r > c.g*1.10 and c.g > c.b*1.12 and c.r < .65:
						sum_x += x
						boot_y = maxi(boot_y,y)
						count += 1
			var pivot := Vector2(sum_x/maxi(1,count),boot_y)-Vector2(rect.position)
			frames.append({"region":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"pivot":[pivot.x,pivot.y]})
		output[filename] = {"columns":6 if filename == "resident" else 4,"frames":frames,"reference_height":frames[0].region[3]}
	var file := FileAccess.open("res://assets/generated/pixel-proof/frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	print("Measured 30 complete cels by connected alpha regions, with boot pivots. Source images unchanged.")
	quit()
