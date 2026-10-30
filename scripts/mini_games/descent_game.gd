extends Node2D

# ---------- CONFIG ----------
@export var screen_width: float = 320.0
@export var screen_height: float = 180.0
@export var bottom_offset_from_end: float = 60.0

@export var obstacle_gap_min: float = 50.0
@export var obstacle_gap_max: float = 90.0
@export var edge_margin: float = 20.0
@export var obstacle_scale_width: float = 64.0

@export var camera_follow_threshold: float = 30.0

const DESCENT_BG_PATH: String = "res://assets/mini_games/descent/descent_background.png"
@export var bg_texture: Texture2D

@export var return_scene_path: String = "res://scenes/provinces/south_cotabato/homebase.tscn"
@export var return_spawn_pos: Vector2 = Vector2.ZERO
@export var win_delay_seconds: float = 2.0

# ---------- DESCENT MUSIC (nagsisimula lang pag pinindot ang SPACE sa instructions) ----------
# Ilagay dito ang path ng background music ng descent. Iwanang "" kung walang idadagdag.
const DESCENT_MUSIC_PATH: String = ""
@export var descent_music_volume_db: float = 0.0
var descent_music_player: AudioStreamPlayer
var held_scene_music: Array[AudioStreamPlayer] = []
var music_bus_name: String = "Master"
var music_bus_muted: bool = false

# ---------- ENDING: COMICS + CREDITS ----------
const ENDING_COMIC_PATHS: Array[String] = [
	"res://assets/comics/1_comic_descent.png",
	"res://assets/comics/2_comic_descent.png",
	"res://assets/comics/3_comic_descent.png",
]
const CREDITS_BG_PATH: String = "res://assets/comics/end_credit_background.png"
const ENDING_MUSIC_PATH: String = "res://assets/audio/music/MainmenuBG.mp3"
@export var ending_music_volume_db: float = 0.0

# Palitan ng totoong pangalan at sources
const CREDITS_LINES: Array[String] = [
	"THANK YOU FOR PLAYING",
	"",
	"DEVELOPED BY",
	"Member Name 1",
	"Member Name 2",
	"Member Name 3",
	"Member Name 4",
	"",
	"ADVISER",
	"Adviser Name",
	"",
	"FREE ASSETS AND SOURCES",
	"Source / Artist Name 1",
	"Source / Artist Name 2",
	"Source / Artist Name 3",
	"",
	"Made with Godot Engine",
	"",
	"",
	"THE END",
]
@export var credits_scroll_seconds: float = 24.0
@export var credits_font_size: int = 10

signal ending_advance
var ending_waiting: bool = false
var ending_sequence_started: bool = false
var ending_music_player: AudioStreamPlayer

# ---------- SFX ----------
@export var falling_sfx_volume_db: float = 0.0
var falling_sfx_stream: AudioStream = preload("res://assets/audio/mini_game_audio/Cotabato_descent_falling.wav")
var falling_sfx_player: AudioStreamPlayer

@export var hit_sfx_volume_db: float = 0.0
var damage_sfx_stream: AudioStream = preload("res://assets/audio/mini_game_audio/Cotabato_descent_damage_james.wav")
var branch_hit_sfx_stream: AudioStream = preload("res://assets/audio/mini_game_audio/Cotabato_descent_brach_hit.wav")
var thunder_hit_sfx_stream: AudioStream = preload("res://assets/audio/mini_game_audio/Cotabato_descent_thunderhit.wav")
var damage_sfx_player: AudioStreamPlayer
var obstacle_sfx_player: AudioStreamPlayer

# ---------- ASSETS ----------
var left_branch_texture: Texture2D = preload("res://assets/mini_games/descent/descent_left_branch_asset.png")
var left_rockcliff_texture: Texture2D = preload("res://assets/mini_games/descent/descent_left_edgerockcliff_asset.png")
var right_branch_texture: Texture2D = preload("res://assets/mini_games/descent/descent_right_branch_asset.png")
var right_rockcliff_texture: Texture2D = preload("res://assets/mini_games/descent/descent_right_edgerockcliff_asset.png")
var middle_thundercloud_texture: Texture2D = preload("res://assets/mini_games/descent/descent_middle_thunderclouds_asset.png")

@onready var player: CharacterBody2D = $DescentJames
@onready var background: Sprite2D = $Background
var camera: Camera2D

var camera_target_y: float = 0.0
var lowest_obstacle_y: float = 0.0
var total_descent_height: float = 0.0
var start_player_y: float = 0.0
var bottom_y: float = 0.0

var is_game_over: bool = false
var has_won: bool = false
var game_started: bool = false

var obstacles: Array[Node] = []

var ui_layer: CanvasLayer
var game_over_label: Label
var win_popup_label: Label

var procedural_progress_bar: DescentProgressBar
var ui_font: Font = preload("res://assets/fonts/GrapeSoda.ttf")

func _ready() -> void:
	randomize()

	music_bus_name = _find_bus(["music", "bgm"])
	# Itigil + i-mute ang music hanggang ma-dismiss ang instructions
	hold_scene_music()

	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)

	if background != null:
		var tex: Texture2D = bg_texture
		if tex == null:
			tex = load(DESCENT_BG_PATH) as Texture2D
		if tex != null:
			background.texture = tex
		else:
			push_error("DESCENT: Hindi mahanap ang background: " + DESCENT_BG_PATH)

	create_ui()
	setup_falling_sfx()
	setup_hit_sfx()
	setup_descent_music()
	setup_background()

	camera_target_y = player.global_position.y - screen_height / 2.0
	camera.global_position = Vector2(0, camera_target_y)

	camera.limit_left = int(-screen_width / 2.0)
	camera.limit_right = int(screen_width / 2.0)
	camera.limit_top = int(start_player_y)
	camera.limit_bottom = int(bottom_y + screen_height)

	lowest_obstacle_y = player.position.y + 40.0

	for i in range(30):
		spawn_next_obstacle()

	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	player.set_physics_process(false)

	show_instructions_popup()

func _exit_tree() -> void:
	# siguraduhing hindi maiiwang naka-mute ang Music bus
	_set_music_muted(false)

# =========================================================================
#  INPUT (pang-next ng comics / pang-skip ng credits)
# =========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if ending_waiting and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		ending_advance.emit()

# =========================================================================
#  AUDIO BUS HELPERS
# =========================================================================
func _find_bus(keywords: Array, fallback: String = "Master") -> String:
	var names: Array[String] = []
	for i in range(AudioServer.bus_count):
		var n: String = AudioServer.get_bus_name(i)
		names.append(n)
		var lower := n.to_lower()
		for k in keywords:
			if lower.contains(String(k)):
				return n
	push_warning("DESCENT: Walang bus na tugma sa %s. Mga bus: %s" % [str(keywords), str(names)])
	return fallback

func _set_music_muted(value: bool) -> void:
	if music_bus_name == "Master":
		return                      # huwag i-mute ang Master (pati sfx)
	var idx := AudioServer.get_bus_index(music_bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, value)
	music_bus_muted = value

# =========================================================================
#  SOUND
# =========================================================================
func setup_falling_sfx() -> void:
	falling_sfx_player = AudioStreamPlayer.new()
	falling_sfx_player.stream = falling_sfx_stream
	falling_sfx_player.volume_db = falling_sfx_volume_db
	if AudioServer.get_bus_index("SFX") != -1:
		falling_sfx_player.bus = "SFX"
	falling_sfx_player.finished.connect(_on_falling_sfx_finished)
	add_child(falling_sfx_player)

func _on_falling_sfx_finished() -> void:
	if game_started and not is_game_over and not has_won:
		falling_sfx_player.play()

func stop_falling_sfx() -> void:
	if falling_sfx_player != null:
		falling_sfx_player.stop()

func _make_hit_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = hit_sfx_volume_db
	if AudioServer.get_bus_index("SFX") != -1:
		p.bus = "SFX"
	add_child(p)
	return p

func setup_hit_sfx() -> void:
	damage_sfx_player = _make_hit_player()
	obstacle_sfx_player = _make_hit_player()

func play_hit_sfx(obstacle_type: String) -> void:
	damage_sfx_player.stream = damage_sfx_stream
	damage_sfx_player.play()

	if obstacle_type == "thunder":
		obstacle_sfx_player.stream = thunder_hit_sfx_stream
	else:
		obstacle_sfx_player.stream = branch_hit_sfx_stream
	obstacle_sfx_player.play()

# --- Background music ng descent: tahimik hanggang pindutin ang SPACE sa instructions ---
func _is_own_player(p: Node) -> bool:
	return p == falling_sfx_player or p == damage_sfx_player or p == obstacle_sfx_player \
		or p == descent_music_player or p == ending_music_player

func _stop_scene_music() -> void:
	if has_node("/root/MusicManager"):
		MusicManager.stop_music()
	# hanapin ang LAHAT ng AudioStreamPlayer sa scene (kahit nakatago sa loob ng ibang node)
	for n in find_children("*", "AudioStreamPlayer", true, false):
		var p := n as AudioStreamPlayer
		if p == null or _is_own_player(p):
			continue
		p.autoplay = false
		p.stop()
		if not held_scene_music.has(p):
			held_scene_music.append(p)

func hold_scene_music() -> void:
	_set_music_muted(true)
	_stop_scene_music()
	_recheck_scene_music()

func _recheck_scene_music() -> void:
	# ulitin pagkatapos ng ilang frame para sa mga nagsisimula nang late
	for i in range(2):
		await get_tree().process_frame
		if game_started:
			return
		_stop_scene_music()

func setup_descent_music() -> void:
	if DESCENT_MUSIC_PATH.is_empty():
		return
	var stream := load(DESCENT_MUSIC_PATH) as AudioStream
	if stream == null:
		push_error("DESCENT: Hindi mahanap ang music: " + DESCENT_MUSIC_PATH)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	descent_music_player = AudioStreamPlayer.new()
	descent_music_player.stream = stream
	descent_music_player.volume_db = descent_music_volume_db
	descent_music_player.bus = music_bus_name
	add_child(descent_music_player)

func start_descent_music() -> void:
	_set_music_muted(false)
	for p in held_scene_music:
		if is_instance_valid(p):
			p.play()
	if descent_music_player != null:
		descent_music_player.play()

# --- Music ng ending (comics + credits) ---
func stop_descent_music() -> void:
	stop_falling_sfx()
	for p in held_scene_music:
		if is_instance_valid(p):
			p.stop()
	if descent_music_player != null:
		descent_music_player.stop()
	if has_node("/root/MusicManager"):
		MusicManager.stop_music()

func start_ending_music() -> void:
	_set_music_muted(false)
	var stream := load(ENDING_MUSIC_PATH) as AudioStream
	if stream == null:
		push_error("DESCENT: Hindi mahanap ang music: " + ENDING_MUSIC_PATH)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	ending_music_player = AudioStreamPlayer.new()
	ending_music_player.stream = stream
	ending_music_player.volume_db = ending_music_volume_db
	ending_music_player.bus = music_bus_name      # sumusunod na sa Music slider
	add_child(ending_music_player)
	ending_music_player.play()

func stop_ending_music() -> void:
	if ending_music_player != null:
		ending_music_player.stop()
		ending_music_player.queue_free()
		ending_music_player = null

# =========================================================================
#  INSTRUCTIONS / SETUP
# =========================================================================
func show_instructions_popup() -> void:
	var popup := InstructionsPopup.new()
	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "DESCENT: Descending the Mountain"
	popup.start_hint = "Press SPACE to start"
	popup.steps = [
		{"icon": "move", "caption": "Press A or D to move left or right."},
		{"icon": "hazard", "caption": "Avoid branches, rocks, and clouds."},
		{"icon": "goal_down", "caption": "Go all the way down to the bottom."}
	]
	popup.dismissed.connect(start_game)
	ui_layer.add_child(popup)

func setup_background() -> void:
	if background == null or background.texture == null:
		total_descent_height = 3000.0
		start_player_y = player.position.y
		bottom_y = start_player_y + total_descent_height - bottom_offset_from_end
		return

	var bg_size: Vector2 = background.texture.get_size()
	var bg_scale: float = screen_width / bg_size.x
	background.scale = Vector2(bg_scale, bg_scale)

	var bg_height_scaled: float = bg_size.y * bg_scale
	start_player_y = player.position.y

	background.position = Vector2(0, start_player_y + bg_height_scaled / 2.0)

	total_descent_height = bg_height_scaled
	bottom_y = start_player_y + total_descent_height - bottom_offset_from_end

func _process(delta: float) -> void:
	if not game_started:
		return

	if is_game_over or has_won:
		if Input.is_key_pressed(KEY_R) and is_game_over:
			restart_game()
		return

	update_camera(delta)
	clamp_player_x()

	if procedural_progress_bar != null:
		var current_descent: float = player.position.y - start_player_y
		var target_distance: float = bottom_y - start_player_y
		if target_distance > 0:
			var progress_percentage: float = (current_descent / target_distance) * 100.0
			procedural_progress_bar.update_progress(progress_percentage)

	if player.position.y < lowest_obstacle_y + screen_height * 2.0:
		spawn_next_obstacle()

	cleanup_old_obstacles()

	if not has_won and player.position.y >= bottom_y:
		trigger_win()

func start_game() -> void:
	game_started = true
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
	player.set_physics_process(true)
	start_descent_music()      # dito lang magsisimula ang music
	falling_sfx_player.play()

func update_camera(delta: float) -> void:
	var player_screen_y: float = player.global_position.y - camera.global_position.y
	if player_screen_y > camera_follow_threshold:
		camera_target_y = player.global_position.y - camera_follow_threshold
	camera.global_position.y = camera_target_y
	camera.global_position.x = 0

func clamp_player_x() -> void:
	var half_width := screen_width / 2.0
	player.position.x = clamp(player.position.x, -half_width + 10, half_width - 10)

# =========================================================================
#  OBSTACLE SPAWNING
# =========================================================================
func spawn_next_obstacle() -> void:
	var gap: float = randf_range(obstacle_gap_min, obstacle_gap_max)
	var new_y: float = lowest_obstacle_y + gap

	var lane_roll: float = randf()
	var texture: Texture2D
	var pos_x: float
	var obstacle_type: String

	if lane_roll < 0.35:
		texture = left_branch_texture if randf() > 0.5 else left_rockcliff_texture
		pos_x = -screen_width / 2.0 + edge_margin
		obstacle_type = "branch"
	elif lane_roll < 0.7:
		texture = right_branch_texture if randf() > 0.5 else right_rockcliff_texture
		pos_x = screen_width / 2.0 - edge_margin
		obstacle_type = "branch"
	else:
		texture = middle_thundercloud_texture
		pos_x = randf_range(-20.0, 20.0)
		obstacle_type = "thunder"

	create_obstacle(Vector2(pos_x, new_y), texture, obstacle_type)

	lowest_obstacle_y = new_y

func create_obstacle(pos: Vector2, texture: Texture2D, obstacle_type: String = "branch") -> void:
	var area := Area2D.new()
	area.position = pos
	area.add_to_group("obstacles")
	area.set_meta("obstacle_type", obstacle_type)

	var visual := Sprite2D.new()
	visual.texture = texture
	visual.name = "Visual"

	var tex_size := texture.get_size()
	var scale_factor: float = obstacle_scale_width / tex_size.x
	visual.scale = Vector2(scale_factor, scale_factor)
	area.add_child(visual)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tex_size.x * scale_factor * 0.7, tex_size.y * scale_factor * 0.7)
	collision.shape = shape
	area.add_child(collision)

	area.body_entered.connect(_on_obstacle_body_entered.bind(area))

	add_child(area)
	obstacles.append(area)

func _on_obstacle_body_entered(body: Node2D, area: Area2D) -> void:
	if body == player and game_started and not is_game_over and not has_won:
		play_hit_sfx(area.get_meta("obstacle_type", "branch"))
		if player.has_method("play_hit_animation"):
			player.play_hit_animation()
		trigger_game_over()

func cleanup_old_obstacles() -> void:
	for o in obstacles.duplicate():
		if not is_instance_valid(o):
			obstacles.erase(o)
			continue
		if o.position.y < camera.global_position.y - screen_height:
			o.queue_free()
			obstacles.erase(o)

# =========================================================================
#  UI / GAME STATE
# =========================================================================
func create_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var viewport_size: Vector2 = get_viewport_rect().size

	procedural_progress_bar = DescentProgressBar.new()
	procedural_progress_bar.position = Vector2(viewport_size.x - 32, (viewport_size.y - 160) / 2.0)
	ui_layer.add_child(procedural_progress_bar)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER\nPress R to Restart"
	game_over_label.add_theme_font_override("font", ui_font)
	game_over_label.add_theme_font_size_override("font_size", 12)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.size = Vector2(160, 40)
	game_over_label.position = Vector2(viewport_size.x / 2.0 - 80, viewport_size.y / 2.0 - 20)
	game_over_label.visible = false
	ui_layer.add_child(game_over_label)

	win_popup_label = Label.new()
	win_popup_label.text = "You made it down safely!"
	win_popup_label.add_theme_font_override("font", ui_font)
	win_popup_label.add_theme_font_size_override("font_size", 12)
	win_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_popup_label.size = Vector2(260, 40)
	win_popup_label.position = Vector2(viewport_size.x / 2.0 - 130, 20)
	win_popup_label.visible = false
	ui_layer.add_child(win_popup_label)

func trigger_game_over() -> void:
	is_game_over = true
	stop_falling_sfx()
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	else:
		player.set_physics_process(false)
	game_over_label.visible = true

func trigger_win() -> void:
	if has_won:
		return

	has_won = true
	stop_falling_sfx()

	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	else:
		player.set_physics_process(false)

	win_popup_label.text = "You made it down safely!"
	win_popup_label.visible = true

	await get_tree().create_timer(win_delay_seconds).timeout
	win_popup_label.visible = false

	await play_ending_sequence()

	Global.mark_minigame_passed(Global.current_minigame_npc)
	Global.complete_heritage_pillar()
	Global.unlock_badge("mountain_climber_safe_descent")

	await return_to_homebase()

# =========================================================================
#  ENDING: 3 COMICS -> CREDITS (may MainmenuBG music)
# =========================================================================
func play_ending_sequence() -> void:
	if ending_sequence_started:
		return
	ending_sequence_started = true

	stop_descent_music()      # alisin ang music ng descent
	start_ending_music()      # MainmenuBG.mp3 (sa Music bus)

	await play_ending_comics()
	await play_credits()

	stop_ending_music()

func _make_ending_layer(layer_index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	add_child(layer)
	return layer

func _make_ending_label(text: String, size_px: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l

func play_ending_comics() -> void:
	var layer := _make_ending_layer(50)

	var dim := ColorRect.new()
	dim.color = Color.BLACK
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var rect := TextureRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(rect)

	var hint := _make_ending_label("", 8, HORIZONTAL_ALIGNMENT_CENTER)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -16
	layer.add_child(hint)

	for i in range(ENDING_COMIC_PATHS.size()):
		var path: String = ENDING_COMIC_PATHS[i]
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("DESCENT: Hindi mahanap ang comic: " + path)
			continue

		rect.texture = tex
		hint.text = "SPACE - magpatuloy" if i >= ENDING_COMIC_PATHS.size() - 1 else "SPACE - susunod"
		rect.modulate.a = 0.0
		create_tween().tween_property(rect, "modulate:a", 1.0, 0.4)

		ending_waiting = true
		await ending_advance
		ending_waiting = false

	layer.queue_free()

func play_credits() -> void:
	var layer := _make_ending_layer(60)
	var vp: Vector2 = get_viewport_rect().size

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg_tex := load(CREDITS_BG_PATH) as Texture2D
	if bg_tex == null:
		push_error("DESCENT: Hindi mahanap ang credits background: " + CREDITS_BG_PATH)
		var fallback := ColorRect.new()
		fallback.color = Color.BLACK
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fallback)
	else:
		bg.texture = bg_tex
		layer.add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)

	var credits := _make_ending_label("\n".join(CREDITS_LINES), credits_font_size, HORIZONTAL_ALIGNMENT_CENTER)
	credits.size = Vector2(vp.x, 0)
	credits.position = Vector2(0, vp.y)
	layer.add_child(credits)

	var skip_hint := _make_ending_label("SPACE - skip", 8, HORIZONTAL_ALIGNMENT_RIGHT)
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint.offset_top = -16
	skip_hint.offset_right = -6
	layer.add_child(skip_hint)

	await get_tree().process_frame
	var text_h: float = credits.get_combined_minimum_size().y
	credits.size = Vector2(vp.x, text_h)
	credits.position = Vector2(0, vp.y)

	var tw := create_tween()
	tw.tween_property(credits, "position:y", -text_h, credits_scroll_seconds)
	tw.finished.connect(func(): ending_advance.emit())

	ending_waiting = true
	await ending_advance
	ending_waiting = false
	tw.kill()

	layer.queue_free()

func return_to_homebase() -> void:
	if return_scene_path.is_empty():
		push_error("return_scene_path is empty!")
		return

	stop_ending_music()
	Global.spawn_position = return_spawn_pos

	if has_node("/root/LoadingScreen"):
		LoadingScreen.change_scene(return_scene_path)
	else:
		get_tree().change_scene_to_file(return_scene_path)

func restart_game() -> void:
	get_tree().reload_current_scene()


# =========================================================================
#  PROGRESS BAR
# =========================================================================
class DescentProgressBar extends Control:
	var bar_width: float = 6.0
	var bar_height: float = 130.0
	var current_value: float = 0.0

	var face_texture: Texture2D = preload("res://assets/images/mini_map/marker_james.png")

	func _ready() -> void:
		custom_minimum_size = Vector2(24, bar_height + 30)

	func _draw() -> void:
		var center_x: float = size.x / 2.0
		var start_y: float = 20.0
		var end_y: float = start_y + bar_height

		draw_line(Vector2(center_x, start_y), Vector2(center_x, end_y), Color("#2e2219"), bar_width + 4.0, true)
		draw_line(Vector2(center_x, start_y), Vector2(center_x, end_y), Color("#1a1310"), bar_width, true)

		var current_head_y: float = start_y

		if current_value > 0.0:
			var fill_ratio: float = current_value / 100.0
			var fill_length: float = bar_height * fill_ratio
			var fill_end_y: float = start_y + fill_length

			current_head_y = fill_end_y

			draw_line(Vector2(center_x, start_y), Vector2(center_x, fill_end_y), Color("#4ab0dc"), bar_width - 2.0, true)
			draw_line(Vector2(center_x - 1, start_y), Vector2(center_x - 1, fill_end_y), Color("#70d0f7"), 1.0, true)

		if face_texture != null:
			var face_size: float = 16.0
			var face_rect := Rect2(center_x - (face_size / 2.0), current_head_y - (face_size / 2.0), face_size, face_size)
			draw_texture_rect(face_texture, face_rect, false)

	func update_progress(percentage: float) -> void:
		current_value = clampf(percentage, 0.0, 100.0)
		queue_redraw()
