extends Node

const BG_PATH := "res://assets/mini_games/ascent/background.png"
const COMIC_PATHS := [
	"res://assets/mini_games/ascent/1_comics_ascent.png",
	"res://assets/mini_games/ascent/2_comics_ascent.png",
]
const HAMMER_SFX_PATH := "res://assets/audio/mini_game_audio/sfx_new_ascent_hammering.wav"
const FALL_SFX_PATH := "res://assets/audio/mini_game_audio/sfx_new_ascent_falling.mp3"

# Instructions popup (palitan ang icon/caption dito kung gusto)
const INSTRUCTION_STEPS := [
	{"icon": "move", "caption": "Press A, D, or A + D to match the key shown."},
	{"icon": "hazard", "caption": "Hit the white zone. A miss drains your grip."},
	{"icon": "goal_down", "caption": "Climb all the way to the summit."},
]

@export var screen_size := Vector2(320, 180)
@export var perfect_step_px := 28.0
@export var good_step_px := 14.0
@export var scroll_time := 0.35
@export var ground_pos := Vector2(160, 142)
@export var climb_pos := Vector2(160, 104)
@export var idle_height_px := 56.0
@export var climb_height_px := 56.0
@export var end_offset := 70.0
@export var fall_time := 0.9
@export var hammer_volume_db := 0.0
@export var fall_sfx_volume_db := 0.0
@export var label_font_size := 8
@export_file("*.tscn") var next_scene := "res://scenes/provinces/cotabato/descent_game.tscn"

enum Phase { INSTRUCTIONS, WAITING, CLIMBING, FINISHED, COMIC, GAMEOVER }

var ui_font: Font = preload("res://assets/fonts/GrapeSoda.ttf")

var player: Node2D
var hud: CanvasLayer
var timing_bar: TimingBar
var grip_bar: ProgressBar
var prompt: Label
var stage_label: Label
var game_over_label: Label

var comic_layer: CanvasLayer
var comic_rect: TextureRect
var comic_hint: Label
var comic_textures: Array[Texture2D] = []
var comic_index := 0

var hammer_left: AudioStreamPlayer
var hammer_right: AudioStreamPlayer
var hammer_both: AudioStreamPlayer
var fall_sfx_player: AudioStreamPlayer

var phase: Phase = Phase.INSTRUCTIONS
var world: Node2D
var total_h := 0.0
var max_scroll := 0.0
var goal_scroll := 0.0
var scroll := 0.0
var scroll_target := 0.0
var stage := 1
var scroll_tween: Tween
var fall_tween: Tween
var ready_ok := false

var _old_scale_mode := Window.CONTENT_SCALE_MODE_DISABLED
var _old_scale_aspect := Window.CONTENT_SCALE_ASPECT_KEEP


func _ready() -> void:
	MusicManager.stop_music()
	var win := get_window()
	_old_scale_mode = win.content_scale_mode
	_old_scale_aspect = win.content_scale_aspect
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	_ensure_action()

	player = get_node_or_null("AscentPlayer") as Node2D
	if player == null:
		for c in get_children():
			if c is CharacterBody2D:
				player = c
				break
	if player == null:
		push_error("ASCENT: Walang player node. Dapat 'AscentPlayer' (CharacterBody2D) ang pangalan sa scene.")
		return
	for sig in ["step_done", "grip_changed", "fell"]:
		if not player.has_signal(sig):
			push_error("ASCENT: Walang signal '%s' ang script ng player." % sig)
			return

	_build_world()
	_build_ui()
	_build_comic()
	_setup_sfx()

	timing_bar.hit.connect(_on_hit)
	timing_bar.missed.connect(_on_missed)
	player.step_done.connect(_on_step_done)
	player.grip_changed.connect(_on_grip_changed)
	player.fell.connect(_on_fell)

	ready_ok = true
	_reset_to_ground()
	_show_instructions()


func _exit_tree() -> void:
	var win := get_window()
	if win:
		win.content_scale_mode = _old_scale_mode
		win.content_scale_aspect = _old_scale_aspect


# SPACEBAR ang "climb" (pang-start sa ground at pang-next ng comics)
func _ensure_action() -> void:
	if not InputMap.has_action("climb"):
		InputMap.add_action("climb")
	InputMap.action_erase_events("climb")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	InputMap.action_add_event("climb", ev)


# ---------- SFX ----------
func _make_pan_bus(bus_name: String, pan: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	var fx := AudioEffectPanner.new()
	fx.pan = pan
	AudioServer.add_bus_effect(idx, fx)
	var send := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	AudioServer.set_bus_send(idx, send)

func _make_sfx_player(stream: AudioStream, bus_name: String, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus_name
	p.volume_db = vol_db
	add_child(p)
	return p

func _setup_sfx() -> void:
	_make_pan_bus("AscentHammerL", -1.0)   # kaliwa lang
	_make_pan_bus("AscentHammerR", 1.0)    # kanan lang
	_make_pan_bus("AscentHammerC", 0.0)    # gitna (dalawa)

	var hammer := load(HAMMER_SFX_PATH) as AudioStream
	if hammer == null:
		push_error("ASCENT: Hindi mahanap ang sfx: " + HAMMER_SFX_PATH)
	else:
		hammer_left = _make_sfx_player(hammer, "AscentHammerL", hammer_volume_db)
		hammer_right = _make_sfx_player(hammer, "AscentHammerR", hammer_volume_db)
		hammer_both = _make_sfx_player(hammer, "AscentHammerC", hammer_volume_db)

	var fall_stream := load(FALL_SFX_PATH) as AudioStream
	if fall_stream == null:
		push_error("ASCENT: Hindi mahanap ang sfx: " + FALL_SFX_PATH)
	else:
		var fall_bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		fall_sfx_player = _make_sfx_player(fall_stream, fall_bus, fall_sfx_volume_db)

# side: "left" = A, "right" = D, "both" = A+D
func _play_hammer(side: String) -> void:
	var p: AudioStreamPlayer
	match side:
		"left":
			p = hammer_left
		"right":
			p = hammer_right
		_:
			p = hammer_both
	if p != null:
		p.play()


# ---------- INSTRUCTIONS ----------
func _show_instructions() -> void:
	phase = Phase.INSTRUCTIONS
	prompt.visible = false

	var popup := InstructionsPopup.new()
	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "ASCENT: Climbing the Mountain"
	popup.start_hint = "Press SPACE to start"
	popup.steps = INSTRUCTION_STEPS.duplicate(true)
	popup.dismissed.connect(_on_instructions_dismissed)
	hud.add_child(popup)

func _on_instructions_dismissed() -> void:
	await get_tree().process_frame
	phase = Phase.WAITING
	prompt.visible = true


# ---------- LAKI NG PLAYER (auto-fit sa taas) ----------
func _fit_player(anim: String, height_px: float) -> void:
	var spr := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return
	if not spr.sprite_frames.has_animation(anim):
		return
	var tex := spr.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return
	var h := tex.get_height() * absf(spr.scale.y)
	if h <= 0.0:
		return
	var k := height_px / h
	player.scale = Vector2(k, k)


# ---------- MUNDO ----------
func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)

	var tex := load(BG_PATH) as Texture2D
	if tex == null:
		push_error("ASCENT: Hindi mahanap ang background: " + BG_PATH)
		return

	var s := screen_size.x / tex.get_width()
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(s, s)
	spr.position = Vector2.ZERO
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(spr)

	total_h = tex.get_height() * s
	max_scroll = maxf(total_h - screen_size.y, 0.0)
	goal_scroll = maxf(max_scroll - end_offset, 0.0)
	if goal_scroll <= 0.0:
		push_error("ASCENT: goal_scroll = 0. Check ang BG_PATH o ang end_offset.")
	_set_scroll(0.0)

func _set_scroll(value: float) -> void:
	scroll = value
	world.position.y = screen_size.y - total_h + scroll


# ---------- UI ----------
func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	timing_bar = TimingBar.new()
	timing_bar.name = "TimingBar"
	timing_bar.position = Vector2((screen_size.x - 120.0) / 2.0, 12.0)
	hud.add_child(timing_bar)

	grip_bar = ProgressBar.new()
	grip_bar.name = "GripBar"
	grip_bar.min_value = 0.0
	grip_bar.max_value = 100.0
	grip_bar.value = 100.0
	grip_bar.show_percentage = false
	grip_bar.custom_minimum_size = Vector2(120, 6)
	grip_bar.size = Vector2(120, 6)
	grip_bar.position = Vector2((screen_size.x - 120.0) / 2.0, 26.0)
	hud.add_child(grip_bar)

	prompt = _make_label(Vector2(0, 156), Vector2(screen_size.x, 16), HORIZONTAL_ALIGNMENT_CENTER)
	prompt.name = "PressKey"
	hud.add_child(prompt)

	stage_label = _make_label(Vector2(6, 4), Vector2(100, 14), HORIZONTAL_ALIGNMENT_LEFT)
	stage_label.name = "StageLabel"
	hud.add_child(stage_label)

	game_over_label = Label.new()
	game_over_label.name = "GameOver"
	game_over_label.text = "GAME OVER\nPress R to Restart"
	game_over_label.add_theme_font_override("font", ui_font)
	game_over_label.add_theme_font_size_override("font_size", 12)
	game_over_label.add_theme_color_override("font_color", Color.WHITE)
	game_over_label.add_theme_color_override("font_outline_color", Color.BLACK)
	game_over_label.add_theme_constant_override("outline_size", 3)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.size = Vector2(160, 40)
	game_over_label.position = Vector2(screen_size.x / 2.0 - 80, screen_size.y / 2.0 - 20)
	game_over_label.visible = false
	hud.add_child(game_over_label)

func _make_label(pos: Vector2, sz: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", label_font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	return l


# ---------- COMICS ----------
func _build_comic() -> void:
	for p in COMIC_PATHS:
		var t := load(p) as Texture2D
		if t == null:
			push_error("ASCENT: Hindi mahanap ang comic: " + p)
		else:
			comic_textures.append(t)

	comic_layer = CanvasLayer.new()
	comic_layer.name = "ComicLayer"
	comic_layer.layer = 10
	comic_layer.visible = false
	add_child(comic_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.position = Vector2.ZERO
	dim.size = screen_size
	comic_layer.add_child(dim)

	comic_rect = TextureRect.new()
	comic_rect.position = Vector2(10, 6)
	comic_rect.size = screen_size - Vector2(20, 22)
	comic_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	comic_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	comic_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	comic_layer.add_child(comic_rect)

	comic_hint = _make_label(Vector2(0, 166), Vector2(screen_size.x, 12), HORIZONTAL_ALIGNMENT_CENTER)
	comic_layer.add_child(comic_hint)

func _show_comic() -> void:
	if comic_textures.is_empty():
		_go_next_scene()
		return
	phase = Phase.COMIC
	comic_index = 0
	comic_layer.visible = true
	_show_comic_page()

func _show_comic_page() -> void:
	comic_rect.texture = comic_textures[comic_index]
	var last := comic_index >= comic_textures.size() - 1
	comic_hint.text = "SPACE - magpatuloy" if last else "SPACE - susunod"
	comic_rect.modulate.a = 0.0
	create_tween().tween_property(comic_rect, "modulate:a", 1.0, 0.3)

func _next_comic() -> void:
	comic_index += 1
	if comic_index >= comic_textures.size():
		comic_layer.visible = false
		_go_next_scene()
	else:
		_show_comic_page()

func _go_next_scene() -> void:
	get_tree().change_scene_to_file(next_scene)


# ---------- SIMULA ----------
func _reset_to_ground() -> void:
	phase = Phase.WAITING
	stage = 1
	scroll_target = 0.0
	_set_scroll(0.0)
	player.set_process(true)
	player.position = ground_pos
	player.reset_to_idle()
	_fit_player("idle", idle_height_px)
	timing_bar.set_active(false)
	timing_bar.visible = false
	grip_bar.visible = false
	game_over_label.visible = false
	prompt.text = "Press SPACE to climb"
	prompt.visible = true
	_update_stage_label()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_ok:
		return
	if phase == Phase.WAITING and event.is_action_pressed("climb"):
		get_viewport().set_input_as_handled()
		_start_climb()
	elif phase == Phase.COMIC and event.is_action_pressed("climb"):
		get_viewport().set_input_as_handled()
		_next_comic()
	elif phase == Phase.GAMEOVER and event is InputEventKey \
			and event.pressed and not event.echo and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_restart()

func _restart() -> void:
	get_tree().reload_current_scene()

func _start_climb() -> void:
	phase = Phase.CLIMBING
	prompt.visible = false
	var tw := create_tween()
	tw.tween_property(player, "position", climb_pos, 0.8)
	await tw.finished
	_fit_player("hold", climb_height_px)
	player.begin_climb()
	timing_bar.visible = true
	grip_bar.visible = true
	timing_bar.set_active(true)


# ---------- PAG-AKYAT ----------
func _on_hit(quality: String, side: String) -> void:
	if phase != Phase.CLIMBING:
		return
	_play_hammer(side)
	timing_bar.set_active(false)
	var step := perfect_step_px if quality == "perfect" else good_step_px
	scroll_target = minf(scroll_target + step, goal_scroll)
	player.climb(quality, side)
	_scroll_to(scroll_target, scroll_time)

func _on_missed(_side: String) -> void:
	if phase == Phase.CLIMBING:
		player.slip()

func _on_step_done(_quality: String) -> void:
	if phase != Phase.CLIMBING:
		return
	_update_stage()
	if goal_scroll > 0.0 and scroll_target >= goal_scroll - 1.0:
		_finish()
	else:
		timing_bar.set_active(true)

func _scroll_to(target: float, time: float) -> void:
	if scroll_tween:
		scroll_tween.kill()
	scroll_tween = create_tween()
	scroll_tween.tween_method(_set_scroll, scroll, target, time)

func _on_grip_changed(ratio: float) -> void:
	grip_bar.value = ratio * 100.0


# ---------- YUGTO ----------
func _update_stage() -> void:
	var b1 := goal_scroll * 0.33
	var b2 := goal_scroll * 0.66
	var new_stage := 1
	if scroll_target >= b2:
		new_stage = 3
	elif scroll_target >= b1:
		new_stage = 2
	if new_stage != stage:
		stage = new_stage
		_update_stage_label()

func _update_stage_label() -> void:
	stage_label.text = ["Paanan", "Bato", "Tuktok"][stage - 1]


# ---------- BAGSAK: TOTOONG HULOG, TAPOS GAME OVER ----------
func _on_fell() -> void:
	if phase != Phase.CLIMBING:
		return
	phase = Phase.GAMEOVER
	timing_bar.set_active(false)
	if scroll_tween:
		scroll_tween.kill()

	if fall_sfx_player != null:
		fall_sfx_player.play()

	var end_y := screen_size.y + 90.0
	fall_tween = create_tween()
	fall_tween.tween_property(player, "position:y", end_y, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall_tween.finished

	if phase == Phase.GAMEOVER and is_inside_tree():
		game_over_label.visible = true


# ---------- DULO: diretso comics ----------
func _finish() -> void:
	phase = Phase.FINISHED
	timing_bar.set_active(false)
	timing_bar.visible = false
	grip_bar.visible = false
	prompt.visible = false
	player.set_process(false)
	await get_tree().create_timer(0.5).timeout
	_show_comic()
