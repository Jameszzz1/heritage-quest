extends CanvasLayer

const UI_FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"

var gear_button: Button
var dim: ColorRect
var panel: Panel
var vbox: VBoxContainer

var audio_popup: Panel
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider

var fullscreen_btn: Button

# --- Auto bus assignment base sa path ng audio file ---
# Music muna ang chine-check, para hindi mapunta sa SFX ang BayanGong_Rhythm
const MUSIC_KEYWORDS := ["bayangong_rhythm", "minigame_backgroundmusic"]
const SFX_KEYWORDS := [
	"audio/sfx/",                    # Tnalak drums, Sarangani, Sultan, Ascent grunts
	"saraganisoundeffect",
	"sultantilesoundeffect",
	"ascent_jump_effort",
	"mini_game_audio/cotabato_descent",  # Descent: branch hit, damage, falling, thunder
]
const MUSIC_BUS := "MUSIC"
const SFX_BUS := "SFX"

var _scan_timer := 0.0

# --- Background music per minigame ---
# Key = bahagi ng pangalan ng scene file, Value = music file.
# (Tnalak wala dito dahil may sarili na siyang music sa AudioPlayer node.)
const BGM_BY_SCENE := {
	"saragani": "res://assets/audio/mini_game_audio/minigame_backgroundmusic_sarangani.mp3",
	"sultan": "res://assets/audio/mini_game_audio/minigame_backgroundmusic_sultankudarat.mp3",
	"ascent": "res://assets/audio/mini_game_audio/minigame_backgroundmusic_cotabato_ascent.mp3",
	"descent": "res://assets/audio/mini_game_audio/minigame_backgroundmusic_cotabato_descent.mp3",
}
const CLICK_SFX_PATH := "res://assets/audio/sfx/buttonuisfx.wav"
const BGM_VOLUME_DB := -6.0   # ibaba o itaas kung masyadong malakas/hina
const BGM_PLAY_ONCE := ["descent"]   # mga scene na isang beses lang tutugtog ang music (walang loop)

var bgm_player: AudioStreamPlayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS   # para gumana kahit naka-pause ang laro
	layer = 200
	_build_ui()
	_start_bgm()
	get_tree().node_added.connect(_on_node_added)
	_scan_audio(get_tree().root)

func _process(delta):
	# Backup scan: para sa mga player na nilagyan ng stream pagkatapos ma-add
	_scan_timer += delta
	if _scan_timer >= 0.5:
		_scan_timer = 0.0
		_scan_audio(get_tree().root)

func _build_ui():
	# --- Gear: icon lang, transparent (walang background/border) ---
	gear_button = Button.new()
	gear_button.text = "⚙"
	gear_button.flat = true
	gear_button.focus_mode = Control.FOCUS_NONE
	gear_button.custom_minimum_size = Vector2(20, 20)
	gear_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear_button.position = Vector2(-26, 2)
	gear_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_gear(gear_button)
	_apply_font(gear_button, 12)
	gear_button.pressed.connect(_play_click)
	gear_button.pressed.connect(_on_gear_pressed)
	add_child(gear_button)

	# --- Dim background habang naka-pause ---
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	add_child(dim)

	# --- Pause panel: transparent, buttons lang ang makikita ---
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(160, 130)
	panel.position = Vector2(-80, -65)
	panel.visible = false
	add_child(panel)

	vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 6
	vbox.offset_right = -10
	vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	_apply_font(title, 9)
	vbox.add_child(title)

	var resume_btn = _make_pill("Resume")
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	fullscreen_btn = _make_pill("")
	fullscreen_btn.pressed.connect(_on_fullscreen_pressed)
	vbox.add_child(fullscreen_btn)

	var audio_btn = _make_pill("Audio Settings")
	audio_btn.pressed.connect(_on_audio_pressed)
	vbox.add_child(audio_btn)

	var exit_btn = _make_pill("Exit Mini Game")
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

	_update_fullscreen_text()
	_build_audio_popup()

func _build_audio_popup():
	audio_popup = Panel.new()
	audio_popup.add_theme_stylebox_override("panel", _make_box(Color(0.1, 0.07, 0.05, 0.92), 8, false))
	audio_popup.set_anchors_preset(Control.PRESET_CENTER)
	audio_popup.custom_minimum_size = Vector2(160, 130)
	audio_popup.position = Vector2(-80, -65)
	audio_popup.visible = false
	add_child(audio_popup)

	var abox = VBoxContainer.new()
	abox.set_anchors_preset(Control.PRESET_FULL_RECT)
	abox.offset_left = 10
	abox.offset_top = 8
	abox.offset_right = -10
	abox.offset_bottom = -8
	abox.add_theme_constant_override("separation", 3)
	audio_popup.add_child(abox)

	var alabel = Label.new()
	alabel.text = "Audio"
	alabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(alabel, 8)
	abox.add_child(alabel)

	master_slider = _make_slider(abox, "Master", _find_bus("Master"))
	music_slider = _make_slider(abox, "Music", _find_bus(MUSIC_BUS))
	sfx_slider = _make_slider(abox, "SFX", _find_bus(SFX_BUS))

	var back_btn = _make_pill("Back")
	back_btn.pressed.connect(_on_audio_back_pressed)
	abox.add_child(back_btn)

func _make_slider(parent: VBoxContainer, label_text: String, bus_name: String) -> HSlider:
	var lbl = Label.new()
	lbl.text = label_text
	_apply_font(lbl, 5)
	parent.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx))
	slider.value_changed.connect(func(v): _on_volume_changed(bus_name, v))
	parent.add_child(slider)
	return slider

func _on_volume_changed(bus_name: String, value: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))

# ---------------- Styling helpers ----------------

# White pill button, black text, soft shadow (kapareho ng main menu buttons)
func _make_pill(text: String) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 18)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_play_click)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.BLACK)
	b.add_theme_stylebox_override("normal", _make_box(Color.WHITE, 9, true))
	b.add_theme_stylebox_override("hover", _make_box(Color(1.0, 0.95, 0.75), 9, true))
	b.add_theme_stylebox_override("pressed", _make_box(Color(0.82, 0.82, 0.82), 9, true))
	b.add_theme_stylebox_override("focus", _make_box(Color.WHITE, 9, true))
	_apply_font(b, 6)
	return b

func _make_box(color: Color, radius: int, shadow: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.55)
		s.shadow_size = 3
		s.shadow_offset = Vector2(0, 1.5)
	return s

# Gear: walang background sa lahat ng states, icon lang na nagbabago ng kulay
func _style_gear(b: Button):
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.8, 0.3, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override("outline_size", 2)

func _apply_font(ctrl: Control, size: int):
	ctrl.add_theme_font_size_override("font_size", size)
	var font = load(UI_FONT_PATH)
	if font:
		ctrl.add_theme_font_override("font", font)

func _update_fullscreen_text():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen_btn.text = "Switch to Windowed"
	else:
		fullscreen_btn.text = "Switch to Fullscreen"

# ---------------- Actions ----------------

func _set_open(opening: bool):
	panel.visible = opening
	dim.visible = opening
	audio_popup.visible = false
	gear_button.visible = not opening
	get_tree().paused = opening

func _on_gear_pressed():
	_set_open(true)

func _on_resume_pressed():
	_set_open(false)

func _on_fullscreen_pressed():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_text()

func _on_audio_pressed():
	panel.visible = false
	audio_popup.visible = true

func _on_audio_back_pressed():
	audio_popup.visible = false
	panel.visible = true

func _on_exit_pressed():
	get_tree().paused = false
	if Global.return_scene == "":
		push_warning("MinigameSettings: walang Global.return_scene, hindi makakalabas.")
		return
	Global.spawn_position = Global.return_spawn_pos
	get_tree().change_scene_to_file(Global.return_scene)

# ---------------- Button click SFX ----------------

# One-shot na player sa root para tapusin pa rin ang tunog kahit magpalit ng scene (Exit)
func _play_click():
	if not ResourceLoader.exists(CLICK_SFX_PATH):
		return
	var p = AudioStreamPlayer.new()
	p.stream = load(CLICK_SFX_PATH)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var bus_name = _find_bus(SFX_BUS)
	if bus_name != "":
		p.bus = bus_name
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# ---------------- Background music ----------------

func _start_bgm():
	# Kunin ang scene file path ng minigame (parent ng layer na 'to)
	var scene_path := ""
	if owner:
		scene_path = owner.scene_file_path
	if scene_path == "" and get_parent():
		scene_path = get_parent().scene_file_path
	scene_path = scene_path.to_lower()

	var music_path := ""
	var should_loop := true
	for key in BGM_BY_SCENE:
		if scene_path.contains(key):
			music_path = BGM_BY_SCENE[key]
			should_loop = not (key in BGM_PLAY_ONCE)
			break
	if music_path == "":
		return   # walang music para sa scene na 'to (hal. Tnalak)

	if not ResourceLoader.exists(music_path):
		push_warning("MinigameSettings: hindi makita ang music: " + music_path)
		return

	var stream = load(music_path)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = should_loop   # i-loop ang mp3 maliban sa BGM_PLAY_ONCE

	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = stream
	bgm_player.volume_db = BGM_VOLUME_DB
	var bus_name = _find_bus(MUSIC_BUS)
	if bus_name != "":
		bgm_player.bus = bus_name
	# Pausable: titigil ang music kapag naka-pause ang laro, tuloy pag Resume
	bgm_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bgm_player)
	bgm_player.play()

# ---------------- Auto audio bus ----------------

# Hanapin ang tunay na pangalan ng bus (hindi case-sensitive). "" kung wala.
func _find_bus(bus_name: String) -> String:
	for i in AudioServer.bus_count:
		var n = AudioServer.get_bus_name(i)
		if n.to_lower() == bus_name.to_lower():
			return n
	return ""

func _on_node_added(node: Node):
	_assign_bus.call_deferred(node)

func _scan_audio(node: Node):
	_assign_bus(node)
	for child in node.get_children():
		_scan_audio(child)

func _assign_bus(node: Node):
	if not is_instance_valid(node):
		return
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	var stream: AudioStream = node.stream
	if stream == null or stream.resource_path == "":
		return
	var path = stream.resource_path.to_lower()
	var target := ""
	var is_music := false
	for k in MUSIC_KEYWORDS:
		if path.contains(k):
			is_music = true
			target = _find_bus(MUSIC_BUS)
			break
	if not is_music:
		for k in SFX_KEYWORDS:
			if path.contains(k):
				target = _find_bus(SFX_BUS)
				break
	if target != "" and node.bus != target:
		node.bus = target
