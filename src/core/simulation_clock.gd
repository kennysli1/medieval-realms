class_name SimulationClock
extends RefCounted
## Shared game time. The caller decides the fixed simulation step.

const ALLOWED_SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]
var elapsed_seconds: float = 0.0
var speed: float = 1.0

func set_speed(value: float) -> bool:
	if not ALLOWED_SPEEDS.has(value):
		return false
	speed = value
	return true

func advance(real_seconds: float) -> float:
	if not is_finite(real_seconds) or real_seconds <= 0.0:
		return 0.0
	var game_seconds := real_seconds * speed
	elapsed_seconds += game_seconds
	return game_seconds
