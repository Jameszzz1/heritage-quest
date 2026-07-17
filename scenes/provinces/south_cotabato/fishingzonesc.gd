extends Area2D

var player_nearby = false

func _ready() -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = true
		print("Malapit ka na sa lawa! Pindutin ang E para mangisda.")

func _on_body_exited(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = false
		print("Umalis ka sa fishing zone.")

func _input(event: InputEvent) -> void:
	if player_nearby and event.is_action_pressed("interact"):
		get_tree().change_scene_to_file("res://scenes/fishing.tscn")
