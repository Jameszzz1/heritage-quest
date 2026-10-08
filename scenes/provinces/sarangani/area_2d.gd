extends Area2D

@export_file("*.tscn") var target_scene: String = ""

@export var spawn_pos: Vector2
@export var show_on_minimap: bool = false


func _ready():
	if show_on_minimap:
		add_to_group("minimap_location")


func _on_body_entered(body):
	if body.name == "James":
		# Remember where to return
		Global.return_scene = get_tree().current_scene.scene_file_path
		Global.return_spawn_pos = body.global_position

		# Set where James will spawn in the target scene
		Global.spawn_position = spawn_pos

		LoadingScreen.change_scene(target_scene)
