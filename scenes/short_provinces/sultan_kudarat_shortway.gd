extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MusicManager.stop_music()
	Global.current_location = "Sarangani-SultanKudarat"
	Global.check_final_badge()
