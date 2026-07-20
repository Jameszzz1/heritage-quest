extends Area2D
@export var target_scene: String = ""
@export var spawn_pos: Vector2
@export var return_scene: String = ""
@export var return_spawn_pos: Vector2

func _on_body_entered(body):
	if body.name == "James":
		Global.spawn_position = spawn_pos
		Global.return_scene = return_scene
		Global.return_spawn_pos = return_spawn_pos
		get_tree().call_deferred("change_scene_to_file", target_scene)
