extends Node2D

# ---------- CONFIG ----------
@export var gap_min: float = 40.0
@export var gap_max: float = 75.0
@export var min_x_distance: float = 60.0
@export var screen_width: float = 320.0
@export var screen_height: float = 180.0
@export var fall_death_margin: float = 60.0
@export var target_platform_width: float = 96.0
@export var final_platform_width: float = 280.0
@export var final_platform_offset_from_top: float = 60.0
@export var final_platform_visual_y_offset: float = 0.0
@export var jump_velocity_ref: float = -500.0
@export var gravity_ref: float = 1200.0
@export var move_speed_ref: float = 300.0
@export var reach_safety_factor: float = 0.65

@export var cloud_chance_level2: float = 0.15
@export var cloud_chance_level3: float = 0.35

@export var final_platform_surface_y_ratio: float = 0.70
@export var final_platform_collision_height: float = 12.0

# --- INSPECTOR TWEAKS PARA SA NORMAL PLATFORMS ---
@export var level_surface_y_ratio: float = 0.65
@export var level_collision_height: float = 16.0

# --- NEW: INSPECTOR TWEAKS PARA SA CLOUD PLATFORMS (PARA BUMAON ANG PAA) ---
# Ang 0.45 ibig sabihin ibababa natin ang tinatapakan para lumubog si James sa ulap.
@export var cloud_surface_y_ratio: float = 0.45
@export var cloud_collision_height: float = 12.0

@export var cloud_move_speed: float = 30.0
@export var cloud_move_range: float = 40.0

@export var camera_follow_threshold: float = 30.0
@export var camera_start_margin: float = 50.0

var level1_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentlevel1.png")
var level2_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentlevel2.png")
var level3_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentlevel3.png")
var clouds_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentclouds.png")
var final_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentfinal.png")
var bg_texture: Texture2D = preload("res://assets/sprites/characters/AscentSpriteAssetJames/ascentbackground.png")

@onready var player: CharacterBody2D = $AscentPlayer
@onready var background: Sprite2D = $Background
var camera: Camera2D

var camera_target_y: float = 0.0
var highest_platform_y: float = 0.0
var last_platform_x: float = 0.0
var platforms_spawned: int = 0
var platforms_before_final: int = 20
var total_climb_height: float = 0.0
var final_platform_y: float = 0.0
var is_game_over: bool = false
var has_won: bool = false
var final_platform_spawned: bool = false

var platforms: Array[Node] = []
var cloud_platforms: Array[Node] = []

var ui_layer: CanvasLayer
var game_over_label: Label
var win_label: Label

# --- PROGRESS BAR ---
var procedural_progress_bar: AscentProgressBar
var start_player_y: float = 0.0

func _ready() -> void:
	randomize()

	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)

	player.jumped_from_platform.connect(_on_player_jumped_from)

	if background != null:
		background.texture = bg_texture

	create_ui()
	setup_background()
	create_background_filler(player.position.y)

	camera_target_y = player.global_position.y - screen_height / 2.0 
	camera.global_position = Vector2(0, camera_target_y)

	camera.limit_left = int(-screen_width / 2.0)
	camera.limit_right = int(screen_width / 2.0)
	camera.limit_top = int(player.position.y - total_climb_height + 2)

	var avg_gap: float = (gap_min + gap_max) / 2.0
	platforms_before_final = max(10, int(total_climb_height / avg_gap))

	create_flat_start_platform(Vector2(player.position.x, player.position.y + 20))
	last_platform_x = player.position.x
	highest_platform_y = player.position.y + 20

	for i in range(platforms_before_final + 10):
		if final_platform_spawned:
			break
		spawn_next_platform()
		
	start_player_y = player.position.y

func setup_background() -> void:
	if background == null or background.texture == null:
		total_climb_height = 3000.0
		final_platform_y = player.position.y - total_climb_height + final_platform_offset_from_top
		return

	var bg_size: Vector2 = background.texture.get_size()
	var bg_scale: float = screen_width / bg_size.x
	background.scale = Vector2(bg_scale, bg_scale)

	var bg_height_scaled: float = bg_size.y * bg_scale
	var start_y: float = player.position.y

	background.position = Vector2(0, start_y - bg_height_scaled / 2.0)

	total_climb_height = bg_height_scaled
	final_platform_y = start_y - total_climb_height + final_platform_offset_from_top

func create_background_filler(bottom_y: float) -> void:
	var filler := ColorRect.new()
	filler.color = Color(0.125, 0.176, 0.059)
	filler.size = Vector2(screen_width * 3, 2000)
	filler.position = Vector2(-screen_width * 1.5, bottom_y)
	filler.z_index = -100
	add_child(filler)

func create_flat_start_platform(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.add_to_group("platforms")

	var visual := ColorRect.new()
	var plat_width: float = screen_width * 0.9
	var plat_height: float = 16.0
	visual.size = Vector2(plat_width, plat_height)
	visual.position = Vector2(-plat_width / 2.0, 0)
	visual.color = Color(0.45, 0.32, 0.18)
	body.add_child(visual)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(plat_width, plat_height)
	collision.shape = shape
	collision.position = Vector2(0, plat_height / 2.0)
	collision.one_way_collision = true
	collision.one_way_collision_margin = 5.0
	body.add_child(collision)

	add_child(body)
	platforms.append(body)

func _on_player_jumped_from(platform_node: Node) -> void:
	if is_instance_valid(platform_node) and platform_node.is_in_group("cloud_platform"):
		fade_and_remove_platform(platform_node)

func _process(delta: float) -> void:
	update_cloud_movement(delta)

	if is_game_over or has_won:
		if Input.is_key_pressed(KEY_R):
			restart_game()
		return

	update_camera(delta)
	wrap_player_x()

	if procedural_progress_bar != null and not has_won:
		var current_climb: float = start_player_y - player.position.y
		var target_distance: float = start_player_y - final_platform_y
		
		if target_distance > 0:
			var progress_percentage: float = (current_climb / target_distance) * 100.0
			procedural_progress_bar.update_progress(progress_percentage)

	if not final_platform_spawned and player.position.y < highest_platform_y + screen_height:
		spawn_next_platform()

	if final_platform_spawned and player.is_on_floor() and player.position.y <= final_platform_y + 5.0:
		trigger_win()

	if player.position.y > camera.global_position.y + screen_height / 2.0 + fall_death_margin:
		trigger_game_over()

func update_cloud_movement(delta: float) -> void:
	for body in cloud_platforms.duplicate():
		if not is_instance_valid(body):
			cloud_platforms.erase(body)
			continue

		var base_x: float = body.get_meta("base_x")
		var move_dir: float = body.get_meta("move_dir")
		var speed_mult: float = body.get_meta("speed_mult")

		var offset: float = body.get_meta("offset")
		offset += cloud_move_speed * speed_mult * move_dir * delta

		if offset > cloud_move_range or offset < -cloud_move_range:
			move_dir *= -1.0
			body.set_meta("move_dir", move_dir)

		body.set_meta("offset", offset)
		body.position.x = base_x + offset

func wrap_player_x() -> void:
	var half_width := screen_width / 2.0
	if player.position.x < -half_width - 10:
		player.position.x = half_width + 10
	elif player.position.x > half_width + 10:
		player.position.x = -half_width - 10

func update_camera(delta: float) -> void:
	var player_screen_y: float = player.global_position.y - camera.global_position.y
	if player_screen_y < -camera_follow_threshold:
		camera_target_y = player.global_position.y + camera_follow_threshold
	camera.global_position.y = camera_target_y
	camera.global_position.x = 0

func max_reachable_x(gap: float) -> float:
	var g: float = gravity_ref
	var v0: float = absf(jump_velocity_ref)
	var discriminant: float = v0 * v0 - 2.0 * g * gap
	if discriminant < 0.0:
		return 0.0
	var t: float = (v0 + sqrt(discriminant)) / g
	return move_speed_ref * t * reach_safety_factor

func create_platform(pos: Vector2, texture: Texture2D, is_cloud: bool = false, custom_width: float = -1.0, collision_height_override: float = -1.0, collision_y_offset: float = 0.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	body.add_to_group("platforms")
	if is_cloud:
		body.add_to_group("cloud_platform")
		body.set_meta("base_x", pos.x)
		body.set_meta("offset", 0.0)
		body.set_meta("move_dir", 1.0 if randf() > 0.5 else -1.0)
		body.set_meta("speed_mult", randf_range(0.7, 1.3))

	var visual := Sprite2D.new()
	visual.texture = texture
	visual.name = "Visual"

	var tex_size := texture.get_size()
	var use_width: float = target_platform_width if custom_width < 0.0 else custom_width
	var scale_factor: float = use_width / tex_size.x
	visual.scale = Vector2(scale_factor, scale_factor)
	body.add_child(visual)

	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()

	var col_height: float = collision_height_override if collision_height_override > 0.0 else tex_size.y * scale_factor
	shape.size = Vector2(tex_size.x * scale_factor, col_height)
	collision.shape = shape
	collision.position.y = collision_y_offset
	collision.one_way_collision = true
	collision.one_way_collision_margin = 5.0
	body.add_child(collision)

	add_child(body)
	platforms.append(body)

	if is_cloud:
		cloud_platforms.append(body)

	return body

func get_platform_data(index: int) -> Dictionary:
	var progress: float = float(index) / float(platforms_before_final)
	var base_texture: Texture2D
	var cloud_chance: float = 0.0

	if progress < 0.35:
		base_texture = level1_texture
		cloud_chance = 0.0
	elif progress < 0.7:
		base_texture = level2_texture
		cloud_chance = cloud_chance_level2
	else:
		base_texture = level3_texture
		cloud_chance = cloud_chance_level3

	var is_cloud: bool = randf() < cloud_chance
	var final_texture_choice: Texture2D = clouds_texture if is_cloud else base_texture

	return {"texture": final_texture_choice, "is_cloud": is_cloud}

func spawn_next_platform() -> void:
	if final_platform_spawned:
		return

	var remaining_to_final: float = highest_platform_y - final_platform_y
	if remaining_to_final <= gap_max:
		spawn_final_platform()
		return

	var gap: float = randf_range(gap_min, gap_max)
	var new_y: float = highest_platform_y - gap

	var min_x: float = -screen_width / 2.0 + 40.0
	var max_x: float = screen_width / 2.0 - 40.0

	var reach: float = max_reachable_x(gap)
	var range_min: float = max(min_x, last_platform_x - reach)
	var range_max: float = min(max_x, last_platform_x + reach)
	if range_min > range_max:
		range_min = min_x
		range_max = max_x

	var new_x: float = randf_range(range_min, range_max)

	if gap < (gap_min + gap_max) / 2.0:
		var attempts := 0
		while absf(new_x - last_platform_x) < min_x_distance and attempts < 10:
			new_x = randf_range(range_min, range_max)
			attempts += 1

	var data := get_platform_data(platforms_spawned)
	var is_cloud: bool = data["is_cloud"]

	var tex_size: Vector2 = data["texture"].get_size()
	var scale_factor: float = target_platform_width / tex_size.x
	var scaled_height: float = tex_size.y * scale_factor

	# FIXED: May magkahiwalay na offset engine na ngayon para sa Normal at Cloud Platforms
	if is_cloud:
		var cloud_surface_offset: float = (cloud_surface_y_ratio * scaled_height) - (scaled_height / 2.0)
		create_platform(Vector2(new_x, new_y), data["texture"], true, target_platform_width, cloud_collision_height, cloud_surface_offset)
	else:
		var surface_offset: float = (level_surface_y_ratio * scaled_height) - (scaled_height / 2.0)
		create_platform(Vector2(new_x, new_y), data["texture"], false, target_platform_width, level_collision_height, surface_offset)

	last_platform_x = new_x
	highest_platform_y = new_y
	platforms_spawned += 1
	cleanup_old_platforms()

func fade_and_remove_platform(body: Node) -> void:
	if not is_instance_valid(body):
		return
	body.remove_from_group("cloud_platform")
	cloud_platforms.erase(body)

	var collision := body.get_node_or_null("Collision")
	if collision:
		collision.set_deferred("disabled", true)

	var visual := body.get_node_or_null("Visual")
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.15)
		await tween.finished

	platforms.erase(body)
	body.queue_free()

func spawn_final_platform() -> void:
	var tex_size: Vector2 = final_texture.get_size()
	var scale_factor: float = final_platform_width / tex_size.x
	var scaled_height: float = tex_size.y * scale_factor

	var surface_offset_from_center: float = (final_platform_surface_y_ratio * scaled_height) - (scaled_height / 2.0)

	var body := create_platform(
		Vector2(0, final_platform_y),
		final_texture,
		false,
		final_platform_width,
		final_platform_collision_height,
		surface_offset_from_center
	)

	var visual := body.get_node_or_null("Visual")
	if visual:
		visual.position.y = final_platform_visual_y_offset

	final_platform_spawned = true

func cleanup_old_platforms() -> void:
	for p in platforms.duplicate():
		if p.position.y > camera.global_position.y + screen_height:
			p.queue_free()
			platforms.erase(p)
			cloud_platforms.erase(p)

func create_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var viewport_size: Vector2 = get_viewport_rect().size

	procedural_progress_bar = AscentProgressBar.new()
	procedural_progress_bar.position = Vector2(viewport_size.x - 32, (viewport_size.y - 160) / 2.0)
	ui_layer.add_child(procedural_progress_bar)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER\nPress R to Restart"
	game_over_label.add_theme_font_size_override("font_size", 12)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.size = Vector2(160, 40)
	game_over_label.position = Vector2(viewport_size.x / 2.0 - 80, viewport_size.y / 2.0 - 20)
	game_over_label.visible = false
	ui_layer.add_child(game_over_label)

	win_label = Label.new()
	win_label.text = "YOU WIN!\nPress R to Restart"
	win_label.add_theme_font_size_override("font_size", 12)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.size = Vector2(160, 40)
	win_label.position = Vector2(viewport_size.x / 2.0 - 80, viewport_size.y / 2.0 - 20)
	win_label.visible = false
	ui_layer.add_child(win_label)

func trigger_game_over() -> void:
	is_game_over = true
	game_over_label.visible = true

func trigger_win() -> void:
	has_won = true
	win_label.visible = true

func restart_game() -> void:
	get_tree().reload_current_scene()


# =========================================================================
#  CUSTOM IN-LINE PROGRESS TRACKER (WITH CHARACTER HEAD INDICATOR)
# =========================================================================
class AscentProgressBar extends Control:
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
		
		var current_head_y: float = end_y
		
		if current_value > 0.0:
			var fill_ratio: float = current_value / 100.0
			var fill_length: float = bar_height * fill_ratio
			var fill_start_y: float = end_y
			var fill_end_y: float = end_y - fill_length
			
			current_head_y = fill_end_y
			
			draw_line(Vector2(center_x, fill_start_y), Vector2(center_x, fill_end_y), Color("#dca134"), bar_width - 2.0, true)
			draw_line(Vector2(center_x - 1, fill_start_y), Vector2(center_x - 1, fill_end_y), Color("#f7d070"), 1.0, true)

		var blimp_center := Vector2(center_x, 10.0)
		draw_rect(Rect2(blimp_center.x - 7, blimp_center.y - 7, 14, 14), Color("#2e2219"), false, 2.0)
		draw_rect(Rect2(blimp_center.x - 6, blimp_center.y - 6, 12, 12), Color("#4a3728"), true)
		
		var icon_color: Color = Color("#dca134") if current_value >= 100.0 else Color("#82664d")
		draw_rect(Rect2(blimp_center.x - 4, blimp_center.y - 3, 8, 6), icon_color, true)
		draw_rect(Rect2(blimp_center.x - 5, blimp_center.y - 2, 1, 4), icon_color, true)
		draw_rect(Rect2(blimp_center.x + 4, blimp_center.y - 4, 1, 8), Color("#2e2219"), true)
		draw_rect(Rect2(blimp_center.x + 5, blimp_center.y - 3, 1, 6), icon_color, true)

		var base_center := Vector2(center_x, end_y + 10.0)
		draw_rect(Rect2(base_center.x - 7, base_center.y - 6, 14, 12), Color("#2e2219"), false, 2.0)
		draw_rect(Rect2(base_center.x - 6, base_center.y - 5, 12, 10), Color("#4a3728"), true)
		
		var base_color := Color("#9a7d66")
		draw_rect(Rect2(base_center.x - 3, base_center.y + 1, 6, 3), base_color, true)
		draw_rect(Rect2(base_center.x - 2, base_center.y - 3, 4, 4), base_color, true)
		draw_rect(Rect2(base_center.x - 4, base_center.y - 4, 8, 1), Color("#dca134"), true)

		if face_texture != null:
			var face_size: float = 16.0 
			var face_rect := Rect2(center_x - (face_size / 2.0), current_head_y - (face_size / 2.0), face_size, face_size)
			draw_texture_rect(face_texture, face_rect, false)

	func update_progress(percentage: float) -> void:
		current_value = clampf(percentage, 0.0, 100.0)
		queue_redraw()
