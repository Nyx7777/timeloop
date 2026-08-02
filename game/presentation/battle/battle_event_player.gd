class_name BattleEventPlayer
extends Node

signal event_started(event: BattleEvent)
signal event_finished(event: BattleEvent)

var playback_speed := 1.0


func play(events: Array[BattleEvent], board: Control) -> void:
	for event in events:
		event_started.emit(event)
		await board.play_event(event, playback_speed)
		event_finished.emit(event)
