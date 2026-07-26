extends Control
@onready var fullscreen_btn = $Background/Panel/VBoxContainer/FullscreenButton
@onready var volume_settings_btn = $Background/Panel/VBoxContainer/VolumeSettingsButton
@onready var save_btn = $Background/Panel/VBoxContainer/SaveButton
@onready var main_menu_btn = $Background/Panel/VBoxContainer/MainMenuButton

@onready var volume_popup = $Background/VolumePopup
@onready var main_panel = $Background/Panel
@onready var master_slider = $Background/VolumePopup/VBoxContainer/MasterSlider
@onready var music_slider = $Background/VolumePopup/VBoxContainer/MusicSlider
@onready var sfx_slider = $Background/VolumePopup/VBoxContainer/SFXSlider
@onready var back_button = $Background/VolumePopup/VBoxContainer/BackButton

func _ready():
	visible = false
	volume_popup.visible = false

	master_slider.min_value = 0
	master_slider.max_value = 1
	master_slider.step = 0.01
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))

	music_slider.min_value = 0
	music_slider.max_value = 1
	music_slider.step = 0.01
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))

	sfx_slider.min_value = 0
	sfx_slider.max_value = 1
	sfx_slider.step = 0.01
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))

	fullscreen_btn.pressed.connect(_on_fullscreen_button_pressed)
	save_btn.pressed.connect(_on_save_button_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_button_pressed)
	volume_settings_btn.pressed.connect(_on_volume_settings_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	master_slider.value_changed.connect(_on_master_slider_value_changed)
	music_slider.value_changed.connect(_on_music_slider_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)

	_update_fullscreen_text()

func toggle():
	visible = !visible
	if not visible:
		volume_popup.visible = false
		main_panel.visible = true

func _on_volume_settings_pressed():
	MusicManager.play_button_sfx()
	main_panel.visible = false
	volume_popup.visible = true

func _on_back_button_pressed():
	MusicManager.play_button_sfx()
	volume_popup.visible = false
	main_panel.visible = true

func _update_fullscreen_text():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen_btn.text = "Switch to Windowed"
	else:
		fullscreen_btn.text = "Switch to Fullscreen"

func _on_fullscreen_button_pressed():
	MusicManager.play_button_sfx()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_text()

func _on_master_slider_value_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_slider_value_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MUSIC"), linear_to_db(value))

func _on_sfx_slider_value_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

func _on_save_button_pressed():
	MusicManager.play_button_sfx()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		Global.spawn_position = player.global_position
	print("Game Saved!")

func _on_main_menu_button_pressed():
	MusicManager.play_button_sfx()
	get_tree().paused = false
	MusicManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
