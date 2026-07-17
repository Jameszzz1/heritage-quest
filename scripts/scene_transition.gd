extends Area2D

@export var target_scene: String = ""
@export var spawn_pos: Vector2 

func _on_body_entered(body):
	if body.name == "James":
		Global.spawn_position = spawn_pos
		get_tree().call_deferred("change_scene_to_file", target_scene)
