extends Control

@onready var volume_slider = $Background/Panel/VBoxContainer/VolumeSlider
@onready var fullscreen_btn = $Background/Panel/VBoxContainer/FullscreenButton

func _ready():
	visible = false
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.01
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	_update_fullscreen_text()

func toggle():
	visible = !visible

func _update_fullscreen_text():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen_btn.text = "Switch to Windowed"
	else:
		fullscreen_btn.text = "Switch to Fullscreen"

func _on_fullscreen_button_pressed():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_text()

func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_save_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		Global.spawn_position = player.global_position
	print("Game Saved!")

func _on_main_menu_button_pressed():
	get_tree().paused = false
	MusicManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
