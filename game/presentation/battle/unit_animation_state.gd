class_name UnitAnimationState
extends RefCounted

const IDLE: StringName = &"idle"
const MOVE: StringName = &"move"
const PUSHED: StringName = &"pushed"
const ATTACK: StringName = &"attack"
const HIT: StringName = &"hit"
const COLLISION: StringName = &"collision"
const DEATH: StringName = &"death"
const CRYSTALLIZE: StringName = &"crystallize"

var state: StringName = IDLE
var facing := Vector2i(0, 1)
var offset := Vector2.ZERO
var scale := Vector2.ONE
var rotation := 0.0
var tint := Color.WHITE
var opacity := 1.0
var progress := 0.0
var last_completed_state: StringName = IDLE


func begin(next_state: StringName, direction := Vector2i.ZERO) -> void:
	state = next_state
	progress = 0.0
	_reset_visual()
	if direction != Vector2i.ZERO:
		facing = direction


func complete(keep_visual := false) -> void:
	last_completed_state = state
	if state != DEATH:
		state = IDLE
	progress = 1.0
	if not keep_visual:
		_reset_visual()


func reset() -> void:
	state = IDLE
	last_completed_state = IDLE
	progress = 0.0
	_reset_visual()


func snapshot() -> Dictionary:
	return {
		"state": state,
		"facing": facing,
		"offset": offset,
		"scale": scale,
		"rotation": rotation,
		"tint": tint,
		"opacity": opacity,
		"progress": progress,
		"last_completed_state": last_completed_state,
	}


func _reset_visual() -> void:
	offset = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0
	tint = Color.WHITE
	opacity = 1.0
