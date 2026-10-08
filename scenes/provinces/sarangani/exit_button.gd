extends Button

func _on_pressed() -> void:
	Global.spawn_position = Global.return_spawn_pos
	LoadingScreen.change_scene(Global.return_scene)
