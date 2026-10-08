extends Node2D

var near_water = false

func _ready():
	MusicManager.play_music("res://BackgroundNBGMusic/Sarangani.mp3")

func _input(event):
	if near_water and event.is_action_pressed("fish_key"):
		get_tree().change_scene_to_file("res://scenes/fishing.tscn")

func _on_fishingzone_body_entered(body: Node2D):
	if "Ayu" in body.name:
		near_water = true

func _on_fishingzone_body_exited(body: Node2D):
	if "Ayu" in body.name:
		near_water = false
