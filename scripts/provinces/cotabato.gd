extends Node2D

func _ready() -> void:
	MusicManager.play_music("res://assets/audio/music/Cotabato.mp3")
	Global.current_location = "Cotabato"
