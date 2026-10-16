extends Node2D

func _ready():
	MusicManager.play_music("res://BackgroundNBGMusic/SultanKudarat.mp3")
	Global.current_location = "Sultan Kudarat"
