extends Control
@onready var options: Panel = $Options
@onready var achievements: Panel = $Achievements
@onready var start_game = $StartGame
@onready var options2 = $Options2
@onready var exit_btn = $Exit
@onready var logout_btn = $Logout
@onready var achievements_btn = $Achievements2

@onready var master_slider = $Options/VBoxContainer/MasterSlider
@onready var music_slider = $Options/VBoxContainer/MusicSlider
@onready var sfx_slider = $Options/VBoxContainer/SFXSlider

func _ready() -> void:
	show_main()
	setup_volume_sliders()

func setup_volume_sliders() -> void:
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

	master_slider.value_changed.connect(_on_master_slider_value_changed)
	music_slider.value_changed.connect(_on_music_slider_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)

func _on_master_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MUSIC"), linear_to_db(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

func show_main() -> void:
	start_game.show()
	options2.show()
	exit_btn.show()
	logout_btn.show()
	achievements_btn.show()
	options.hide()
	achievements.hide()

func show_options() -> void:
	start_game.hide()
	options2.hide()
	exit_btn.hide()
	logout_btn.hide()
	achievements_btn.hide()
	options.show()
	achievements.hide()

func show_achievements() -> void:
	start_game.hide()
	options2.hide()
	exit_btn.hide()
	logout_btn.hide()
	achievements_btn.hide()
	options.hide()
	achievements.show()

func _on_start_pressed() -> void:
	MusicManager.play_button_sfx()
	get_tree().change_scene_to_file("res://scenes/ui/introduction.tscn")

func _on_settings_pressed() -> void:
	MusicManager.play_button_sfx()
	show_options()

func _on_back_options_pressed() -> void:
	MusicManager.play_button_sfx()
	show_main()

func _on_achievements_pressed() -> void:
	MusicManager.play_button_sfx()
	show_achievements()

func _on_back_achie_pressed() -> void:
	MusicManager.play_button_sfx()
	show_main()

func _on_logout_pressed() -> void:
	MusicManager.play_button_sfx()
	Supabase.auth._session = {}
	get_tree().change_scene_to_file("res://scenes/ui/login.tscn")

func _on_exit_pressed() -> void:
	MusicManager.play_button_sfx()
	get_tree().quit()

func _on_fullscreen_pressed() -> void:
	MusicManager.play_button_sfx()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options.visible or achievements.visible:
			show_main()
			get_viewport().set_input_as_handled()
