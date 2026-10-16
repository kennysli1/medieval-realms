class_name IsometricGrid
extends RefCounted
## Projection only; world simulation keeps integer grid coordinates.

const HALF_TILE := Vector2(64.0, 32.0)

static func grid_to_screen(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_TILE.x, (cell.x + cell.y) * HALF_TILE.y)

static func screen_to_grid(point: Vector2) -> Vector2i:
	var grid_x := (point.x / HALF_TILE.x + point.y / HALF_TILE.y) * 0.5
	var grid_y := (point.y / HALF_TILE.y - point.x / HALF_TILE.x) * 0.5
	return Vector2i(roundi(grid_x), roundi(grid_y))
