extends Node2D

func _ready():
	MusicManager.play_music("res://assets/audio/music/SouthCotabato.mp3")
	Global.current_location = "South Cotabato"
