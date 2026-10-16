extends Resource
## Stable ID is persisted; names and research concepts are display data only.

@export var element_id: StringName
@export var display_name: String
@export var domain: String
@export var derived_concepts: PackedStringArray
@export var resonance_required := 50.0
@export var resonance_stability := 60.0
@export var weak_observation: String
@export var partial_observation: String
@export var stable_observation: String
@export_multiline var book_clue: String
@export_multiline var mentor_clue: String
