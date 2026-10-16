extends SceneTree

const Clock = preload("res://src/core/simulation_clock.gd")
const Grid = preload("res://src/core/isometric_grid.gd")
var failures: int = 0

func _initialize() -> void:
	var clock = Clock.new()
	check(is_equal_approx(clock.advance(2.0), 2.0), "Normal speed")
	check(clock.set_speed(0.0), "Pause accepted")
	clock.advance(100.0)
	check(is_equal_approx(clock.elapsed_seconds, 2.0), "Pause preserves simulation")
	clock.set_speed(4.0)
	clock.advance(2.0)
	check(is_equal_approx(clock.elapsed_seconds, 10.0), "Acceleration")
	check(not clock.set_speed(3.0), "Unsupported speed rejected")
	clock.advance(-3.0)
	clock.advance(INF)
	check(is_equal_approx(clock.elapsed_seconds, 10.0), "Invalid deltas rejected")
	for x in range(-10, 11):
		for y in range(-10, 11):
			var cell := Vector2i(x, y)
			check(Grid.screen_to_grid(Grid.grid_to_screen(cell)) == cell, "Projection round-trip %s" % cell)
	print("Foundation checks: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
