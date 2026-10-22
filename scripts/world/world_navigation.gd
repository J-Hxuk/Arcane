extends "res://scripts/destination_movement.gd"
## Shares the bounded cached radius-aware planner with laboratory/legacy movement.
const CELL := 32.0
var actor_radius := 13.0
var rebuild_count: int:
	get: return planner.rebuild_count
var grid: AStarGrid2D:
	get: return planner.grid

func _navigation_bounds(game) -> Rect2:
	return game.layout.ARENA if game.arena_locked() else game.layout.BOUNDS

func _navigation_cell_size() -> float: return CELL
func _navigation_radius() -> float: return actor_radius

func clear_line(game, from: Vector2, to: Vector2) -> bool:
	planner.radius = actor_radius
	return planner.clear_line(game, from, to)
