extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MusicManager.stop_music()
	Global.current_location = "SouthCotabato-Sarangani"
	Global.check_final_badge()
