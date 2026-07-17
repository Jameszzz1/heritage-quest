extends Node2D

@onready var tutorial = $Tutorial

func _ready():
	MusicManager.play_music("res://assets/audio/music/SouthCotabato.mp3")
	
	if tutorial == null:
		return  # No tutorial node, skip safely
	
	if not Gamestate.tutorial_shown:
		tutorial.show_step(0)
	else:
		tutorial.panel.visible = false
