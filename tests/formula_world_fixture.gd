extends "res://scripts/world/world_main.gd"
## Only this explicit test scene enables proposal definitions. No real saves.
func _prototype_context()->Dictionary:
	var context:=super._prototype_context()
	context.formula_prototypes=true
	return context
