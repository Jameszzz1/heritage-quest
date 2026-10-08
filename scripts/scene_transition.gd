extends Area2D

@export var target_scene: String = ""
@export var spawn_pos: Vector2

@export var return_scene: String = ""
@export var return_spawn_pos: Vector2

@export var show_on_minimap: bool = false


func _ready():
	if show_on_minimap:
		add_to_group("minimap_location")


func _on_body_entered(body):
	if body.name == "James":
		Global.spawn_position = spawn_pos
		Global.return_scene = return_scene
		Global.return_spawn_pos = return_spawn_pos

		LoadingScreen.change_scene(target_scene)
