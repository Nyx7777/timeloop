class_name LevelDefinition
extends Resource

@export var level_id: StringName
@export var display_name: String
@export_multiline var briefing: String
@export_multiline var hint: String
@export var board_size := Vector2i(8, 8)
@export var lives := 1
@export var walls: Array[Vector2i] = []
@export var holes: Array[Vector2i] = []
@export var spawns: Array[Resource] = []
@export var rules: Dictionary = {}
