extends Node2D

# ---------- CONFIG ----------
@export var screen_width: float = 320.0
@export var screen_height: float = 180.0
@export var bottom_offset_from_end: float = 60.0  # margin bago maabot ang literal na dulo ng bg

@export var obstacle_gap_min: float = 50.0
@export var obstacle_gap_max: float = 90.0
@export var edge_margin: float = 20.0   # gaano kalapit sa gilid ang left/right obstacles
@export var obstacle_scale_width: float = 64.0

@export var camera_follow_threshold: float = 30.0

# ---------- ASSETS ----------
var bg_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentbackground.png")

var left_branch_texture: Texture2D = preload("res://assets/sprites/characters/DescentSpriteAssetJames/descent_left_branch_asset.png")
var left_rockcliff_texture: Texture2D = preload("res://assets/sprites/characters/DescentSpriteAssetJames/descent_left_edgerockcliff_asset.png")
var right_branch_texture: Texture2D = preload("res://assets/sprites/characters/DescentSpriteAssetJames/descent_right_branch_asset.png")
var right_rockcliff_texture: Texture2D = preload("res://assets/sprites/characters/DescentSpriteAssetJames/descent_right_edgerockcliff_asset.png")
var middle_thundercloud_texture: Texture2D = preload("res://assets/sprites/characters/DescentSpriteAssetJames/descent_middle_thunderclouds_asset.png")

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

	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)

	if background != null:
		background.texture = bg_texture

	create_ui()
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

	# Huwag munang bigyan ng control ang player hanggang ma-dismiss ang instructions popup
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	# Ifreeze din ang physics niya (gravity/movement) para hindi siya mahulog nang mag-isa
	player.set_physics_process(false)

	show_instructions_popup()

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

	# Itaas ng background ang nakatapat sa starting position ni James (reverse ng Ascent)
	background.position = Vector2(0, start_player_y + bg_height_scaled / 2.0)

	total_descent_height = bg_height_scaled
	bottom_y = start_player_y + total_descent_height - bottom_offset_from_end

func _process(delta: float) -> void:
	# ---------- WAITING FOR INSTRUCTIONS POPUP TO BE DISMISSED ----------
	if not game_started:
		return

	if is_game_over or has_won:
		if Input.is_key_pressed(KEY_R):
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
#  OBSTACLE SPAWNING (left corner / right corner / middle)
# =========================================================================
func spawn_next_obstacle() -> void:
	var gap: float = randf_range(obstacle_gap_min, obstacle_gap_max)
	var new_y: float = lowest_obstacle_y + gap

	var lane_roll: float = randf()
	var texture: Texture2D
	var pos_x: float

	if lane_roll < 0.35:
		# LEFT CORNER
		texture = left_branch_texture if randf() > 0.5 else left_rockcliff_texture
		pos_x = -screen_width / 2.0 + edge_margin
	elif lane_roll < 0.7:
		# RIGHT CORNER
		texture = right_branch_texture if randf() > 0.5 else right_rockcliff_texture
		pos_x = screen_width / 2.0 - edge_margin
	else:
		# MIDDLE
		texture = middle_thundercloud_texture
		pos_x = randf_range(-20.0, 20.0)

	create_obstacle(Vector2(pos_x, new_y), texture)

	lowest_obstacle_y = new_y

func create_obstacle(pos: Vector2, texture: Texture2D) -> void:
	var area := Area2D.new()
	area.position = pos
	area.add_to_group("obstacles")

	var visual := Sprite2D.new()
	visual.texture = texture
	visual.name = "Visual"

	var tex_size := texture.get_size()
	var scale_factor: float = obstacle_scale_width / tex_size.x
	visual.scale = Vector2(scale_factor, scale_factor)
	area.add_child(visual)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tex_size.x * scale_factor * 0.7, tex_size.y * scale_factor * 0.7)  # medyo mas maliit sa sprite para forgiving ang hitbox
	collision.shape = shape
	area.add_child(collision)

	area.body_entered.connect(_on_obstacle_body_entered)

	add_child(area)
	obstacles.append(area)

func _on_obstacle_body_entered(body: Node2D) -> void:
	if body == player and game_started and not is_game_over and not has_won:
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
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	else:
		player.set_physics_process(false)
	game_over_label.visible = true

func trigger_win() -> void:
	has_won = true
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	else:
		player.set_physics_process(false)
	win_popup_label.visible = true

func restart_game() -> void:
	get_tree().reload_current_scene()


# =========================================================================
#  PROGRESS BAR (simpleng reuse ng Ascent style)
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
