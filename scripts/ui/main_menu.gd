extends Control
@onready var options: Panel = $Options
@onready var achievements: Panel = $Achievements
@onready var start_game = $StartGame
@onready var load_game = $LoadGame
@onready var options2 = $Options2
@onready var exit_btn = $Exit
@onready var logout_btn = $Logout
@onready var achievements_btn = $Achievements2
@onready var master_slider = $Options/VBoxContainer/MasterSlider
@onready var music_slider = $Options/VBoxContainer/MusicSlider
@onready var sfx_slider = $Options/VBoxContainer/SFXSlider
@onready var bg_music: AudioStreamPlayer = $AudioStreamPlayer

# ---- POPUP SETTINGS (dito mo babaguhin ang itsura) ----
const POPUP_FONT_PATH = "res://assets/fonts/GrapeSoda.ttf"
const POPUP_FONT_SIZE = 10          # palakihin o paliitin dito
const POPUP_BUTTON_FONT_SIZE = 10
const POPUP_BG_ALPHA = 0.5          # 0.0 = buong transparent, 1.0 = solid
const POPUP_MESSAGE = "No saved game found.\nPlease play Start Journey first."

var _popup: Control
var _loading := false

func _ready() -> void:
	bg_music.bus = "MUSIC"
	if not load_game.pressed.is_connected(_on_load_game_pressed):
		load_game.pressed.connect(_on_load_game_pressed)
	_setup_popup()
	show_main()
	setup_volume_sliders()

# ---------------- POPUP (gawa sa code) ----------------

func _make_pill(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb

# Kinokopya ang style ng Start Journey button para pareho ang itsura
func _style_like(btn: Button, source: Button, font: Font) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		if source.has_theme_stylebox_override(state):
			btn.add_theme_stylebox_override(state, source.get_theme_stylebox(state).duplicate())
	if not source.has_theme_stylebox_override("normal"):
		# Fallback: puting pill na button
		btn.add_theme_stylebox_override("normal", _make_pill(Color.WHITE))
		btn.add_theme_stylebox_override("hover", _make_pill(Color(0.92, 0.92, 0.92)))
		btn.add_theme_stylebox_override("pressed", _make_pill(Color(0.8, 0.8, 0.8)))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", POPUP_BUTTON_FONT_SIZE)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color", Color.BLACK)

func _setup_popup() -> void:
	var font: Font = null
	if ResourceLoader.exists(POPUP_FONT_PATH):
		font = load(POPUP_FONT_PATH)

	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.z_index = 100
	_popup.visible = false
	add_child(_popup)

	# Bahagyang dim sa likod para hindi mapindot ang ibang button
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(center)

	# Transparent na panel
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, POPUP_BG_ALPHA)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var label = Label.new()
	label.text = POPUP_MESSAGE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(label)

	var ok = Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(70, 18)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_like(ok, start_game, font)
	ok.pressed.connect(_on_popup_ok_pressed)
	box.add_child(ok)

func _on_popup_ok_pressed() -> void:
	MusicManager.play_button_sfx()
	_popup.hide()

# ---------------- VOLUME ----------------

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

# ---------------- MENU ----------------

# May save ba na pwedeng ituloy?
func _has_save() -> bool:
	return Global.has_saved_game() and ResourceLoader.exists(Global.saved_scene)

# Start Journey (walang save) o Start New Journey (may save). Laging kita ang Load Game.
func _refresh_menu_buttons() -> void:
	if _has_save():
		start_game.text = "Start New Journey"
	else:
		start_game.text = "Start Journey"
	load_game.show()

func show_main() -> void:
	start_game.show()
	load_game.show()
	options2.show()
	exit_btn.show()
	logout_btn.show()
	achievements_btn.show()
	options.hide()
	achievements.hide()
	_refresh_menu_buttons()

func show_options() -> void:
	start_game.hide()
	load_game.hide()
	options2.hide()
	exit_btn.hide()
	logout_btn.hide()
	achievements_btn.hide()
	options.show()
	achievements.hide()

func show_achievements() -> void:
	start_game.hide()
	load_game.hide()
	options2.hide()
	exit_btn.hide()
	logout_btn.hide()
	achievements_btn.hide()
	options.hide()
	achievements.show()

# Start Journey / Start New Journey: LAGING malinis ang simula
func _on_start_pressed() -> void:
	MusicManager.play_button_sfx()
	if _loading:
		return
	Global.reset_progress()   # buburahin ang lahat ng nasa memory (stats, items, journal, atbp.)
	LoadingScreen.change_scene("res://scenes/ui/introduction.tscn")

# Load Game: kukunin muna ang huling Save Game sa Supabase, tapos lilipat
func _on_load_game_pressed() -> void:
	MusicManager.play_button_sfx()
	if _loading:
		return
	if not _has_save():
		_popup.show()
		return

	_loading = true
	load_game.disabled = true

	# Ino-overwrite nito ang anumang hindi na-save na progress sa memory
	var ok = await Global.download_cloud_save()
	if not ok:
		push_warning("Load Game: hindi nakuha ang cloud save, gagamitin ang nasa memory")

	if _has_save():
		Global.spawn_position = Global.saved_position
		LoadingScreen.change_scene(Global.saved_scene)
	else:
		_popup.show()

	load_game.disabled = false
	_loading = false

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
	LoadingScreen.change_scene("res://scenes/ui/login.tscn")

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
		if _popup.visible:
			_popup.hide()
			get_viewport().set_input_as_handled()
		elif options.visible or achievements.visible:
			show_main()
			get_viewport().set_input_as_handled()
