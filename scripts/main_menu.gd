extends Control

@onready var options: Panel = $Options
@onready var achievements: Panel = $Achievements
@onready var start_game = $StartGame
@onready var options2 = $Options2
@onready var exit_btn = $Exit
@onready var logout_btn = $Logout
@onready var achievements_btn = $Achievements2

func _ready() -> void:
	show_main()

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
	get_tree().change_scene_to_file("res://scenes/ui/introduction.tscn")

func _on_settings_pressed() -> void:
	show_options()

func _on_back_options_pressed() -> void:
	show_main()

func _on_achievements_pressed() -> void:
	show_achievements()

func _on_back_achie_pressed() -> void:
	show_main()

func _on_logout_pressed() -> void:
	Supabase.auth._session = {}
	get_tree().change_scene_to_file("res://scenes/ui/login.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_fullscreen_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options.visible or achievements.visible:
			show_main()
			get_viewport().set_input_as_handled()
