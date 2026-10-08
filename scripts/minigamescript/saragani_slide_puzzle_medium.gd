extends Control

@onready var grid_container = $GridContainer
@onready var timer_label = $TimerLabel
@onready var game_over_label = $GameOverLabel
@onready var try_again_button = $TryAgainButton
@onready var tile_sound = $TileSound

# LINKED NA ULIT SA NODE NA ILALAGAY MO SA EDITOR
@onready var shuffle_button = $ShuffleButton

const GRID_COLS = 3
const GRID_ROWS = 4

var puzzle_texture = preload("res://assets/images/provinces/sarangani/SlidePuzzle.png")
var grid_matrix = []
var blank_tile_pos = Vector2i(2, 3) # Bottom-right position
var is_shuffling = false
var display_tile_size_x = 0.0
var display_tile_size_y = 0.0
var selected_tile = null
var glow_tween = null

var time_left = 300.0
var timer_running = false

func _ready():
	randomize()
	grid_container.columns = GRID_COLS
	game_over_label.visible = false
	try_again_button.visible = false
	try_again_button.pressed.connect(_on_try_again_pressed)

	# IKONEKTA ANG CLICK SIGNAL SA SHUFFLE BUTTON
	if shuffle_button != null:
		shuffle_button.pressed.connect(_on_shuffle_button_pressed)

	var viewport_size = get_viewport().get_visible_rect().size

	# Sizing calculation para sa 3x4 grid
	display_tile_size_x = floor(viewport_size.x * 0.75 / GRID_COLS)
	display_tile_size_y = floor(viewport_size.y * 0.75 / GRID_ROWS)

	var tile_size = min(display_tile_size_x, display_tile_size_y)
	display_tile_size_x = tile_size
	display_tile_size_y = tile_size

	var total_px_x = display_tile_size_x * GRID_COLS
	var total_px_y = display_tile_size_y * GRID_ROWS

	grid_container.position = Vector2(
		(viewport_size.x - total_px_x) / 2.0,
		(viewport_size.y - total_px_y) / 2.0
	)
	grid_container.custom_minimum_size = Vector2(total_px_x, total_px_y)
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)

	setup_puzzle_grid()
	shuffle_board()

	timer_label.text = "Time: 5:00"

	# Huwag munang tumakbo ang timer hanggang ma-dismiss ang instructions popup
	show_instructions_popup()

func show_instructions_popup() -> void:
	var popup := InstructionsPopup.new()
	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "SARANGANI: Slide Puzzle"
	popup.start_hint = "Press SPACE to start"
	popup.steps = [
		{"icon": "tile_click", "caption": "Tap the tile next to the blank space to move it."},
		{"icon": "timer", "caption": "Finish before time runs out."}
	]
	popup.dismissed.connect(_on_instructions_dismissed)
	add_child(popup)

func _on_instructions_dismissed() -> void:
	timer_running = true

# FUNCTION KAPAG PININDOT ANG SHUFFLE BUTTON MO
func _on_shuffle_button_pressed():
	if not timer_running or is_shuffling:
		return

	remove_glow_from_tile(selected_tile)
	selected_tile = null

	shuffle_board()

	if tile_sound != null:
		tile_sound.play()

func _process(delta):
	if not timer_running:
		return

	time_left -= delta
	if time_left <= 0:
		time_left = 0
		timer_running = false
		timer_label.text = "Time: 0:00"
		trigger_game_over()
		return

	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	timer_label.text = "Time: " + str(minutes) + ":" + "%02d" % seconds

	if time_left <= 30:
		timer_label.modulate = Color(1, 0.3, 0.3)
	else:
		timer_label.modulate = Color(1, 1, 1)

func trigger_game_over():
	game_over_label.visible = true
	try_again_button.visible = true
	if shuffle_button != null:
		shuffle_button.visible = false
	timer_label.modulate = Color(1, 0.3, 0.3)
	grid_container.visible = false

func _on_try_again_pressed():
	time_left = 300.0
	timer_running = true
	timer_label.modulate = Color(1, 1, 1)
	game_over_label.visible = false
	try_again_button.visible = false
	if shuffle_button != null:
		shuffle_button.visible = true
	grid_container.visible = true
	blank_tile_pos = Vector2i(2, 3)
	selected_tile = null
	setup_puzzle_grid()
	shuffle_board()

func setup_puzzle_grid():
	for child in grid_container.get_children():
		child.queue_free()

	grid_matrix.resize(GRID_COLS)
	for x in range(GRID_COLS):
		grid_matrix[x] = []
		grid_matrix[x].resize(GRID_ROWS)

	var orig_tile_w = puzzle_texture.get_width() / float(GRID_COLS)
	var orig_tile_h = puzzle_texture.get_height() / float(GRID_ROWS)
	var tile_index = 0

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var container = Panel.new()
			container.custom_minimum_size = Vector2(display_tile_size_x, display_tile_size_y)
			container.size = Vector2(display_tile_size_x, display_tile_size_y)

			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0, 0, 0, 0)
			container.add_theme_stylebox_override("panel", normal_style)

			var button = TextureButton.new()
			button.custom_minimum_size = Vector2(display_tile_size_x, display_tile_size_y)
			button.size = Vector2(display_tile_size_x, display_tile_size_y)
			button.ignore_texture_size = true
			button.stretch_mode = TextureButton.STRETCH_SCALE
			button.position = Vector2(0, 0)

			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = puzzle_texture
			atlas_tex.region = Rect2(
				x * orig_tile_w,
				y * orig_tile_h,
				orig_tile_w,
				orig_tile_h
			)
			atlas_tex.filter_clip = true

			if x == GRID_COLS - 1 and y == GRID_ROWS - 1:
				button.texture_normal = null
				button.set_meta("is_blank", true)
			else:
				button.texture_normal = atlas_tex
				button.set_meta("is_blank", false)

			button.set_meta("original_id", tile_index)
			button.set_meta("grid_x", x)
			button.set_meta("grid_y", y)
			button.set_meta("container", container)

			button.pressed.connect(func(): _on_tile_pressed(button))

			container.add_child(button)
			grid_container.add_child(container)
			grid_matrix[x][y] = button
			tile_index += 1

func apply_glow_to_tile(button: TextureButton):
	var container = button.get_meta("container")
	if glow_tween != null and glow_tween.is_valid():
		glow_tween.kill()

	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(1, 0.85, 0.2, 0.15)
	glow_style.border_color = Color(1, 0.85, 0.2, 1.0)
	glow_style.border_width_left = 3
	glow_style.border_width_right = 3
	glow_style.border_width_top = 3
	glow_style.border_width_bottom = 3
	glow_style.corner_radius_top_left = 4
	glow_style.corner_radius_top_right = 4
	glow_style.corner_radius_bottom_left = 4
	glow_style.corner_radius_bottom_right = 4
	container.add_theme_stylebox_override("panel", glow_style)

	button.scale = Vector2(1.0, 1.0)
	var scale_tween = create_tween()
	scale_tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_SINE)

	glow_tween = create_tween().set_loops()
	glow_tween.tween_method(
		func(val):
			var pulsing_style = StyleBoxFlat.new()
			pulsing_style.bg_color = Color(1, 0.85, 0.2, val * 0.2)
			pulsing_style.border_color = Color(1, 0.85, 0.2, val)
			pulsing_style.border_width_left = 3
			pulsing_style.border_width_right = 3
			pulsing_style.border_width_top = 3
			pulsing_style.border_width_bottom = 3
			pulsing_style.corner_radius_top_left = 4
			pulsing_style.corner_radius_top_right = 4
			pulsing_style.corner_radius_bottom_left = 4
			pulsing_style.corner_radius_bottom_right = 4
			container.add_theme_stylebox_override("panel", pulsing_style),
		0.5, 1.0, 0.6
	)
	glow_tween.tween_method(
		func(val):
			var pulsing_style = StyleBoxFlat.new()
			pulsing_style.bg_color = Color(1, 0.85, 0.2, val * 0.2)
			pulsing_style.border_color = Color(1, 0.85, 0.2, val)
			pulsing_style.border_width_left = 3
			pulsing_style.border_width_right = 3
			pulsing_style.border_width_top = 3
			pulsing_style.border_width_bottom = 3
			pulsing_style.corner_radius_top_left = 4
			pulsing_style.corner_radius_top_right = 4
			pulsing_style.corner_radius_bottom_left = 4
			pulsing_style.corner_radius_bottom_right = 4
			container.add_theme_stylebox_override("panel", pulsing_style),
		1.0, 0.5, 0.6
	)

func remove_glow_from_tile(button: TextureButton):
	if button == null: return
	var container = button.get_meta("container")
	if glow_tween != null and glow_tween.is_valid():
		glow_tween.kill()
		glow_tween = null

	var scale_tween = create_tween()
	scale_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

	var fade_tween = create_tween()
	fade_tween.tween_method(
		func(val):
			var fading_style = StyleBoxFlat.new()
			fading_style.bg_color = Color(1, 0.85, 0.2, val * 0.15)
			fading_style.border_color = Color(1, 0.85, 0.2, val)
			fading_style.border_width_left = 3
			fading_style.border_width_right = 3
			fading_style.border_width_top = 3
			fading_style.border_width_bottom = 3
			fading_style.corner_radius_top_left = 4
			fading_style.corner_radius_top_right = 4
			fading_style.corner_radius_bottom_left = 4
			fading_style.corner_radius_bottom_right = 4
			container.add_theme_stylebox_override("panel", fading_style),
		0.8, 0.0, 0.2
	)

func _on_tile_pressed(tile_button: TextureButton):
	if not timer_running: return
	if tile_button.get_meta("is_blank"): return
	var current_pos = get_tile_grid_pos(tile_button)
	if current_pos == Vector2i(-1, -1): return
	var distance = abs(current_pos.x - blank_tile_pos.x) + abs(current_pos.y - blank_tile_pos.y)
	if distance == 1:
		remove_glow_from_tile(selected_tile)
		selected_tile = null
		swap_tiles(current_pos, blank_tile_pos)
		if tile_sound != null:
			tile_sound.play()
		if not is_shuffling and check_victory():
			timer_running = false
			timer_label.text = "SOLVED! 🎉"
			timer_label.modulate = Color(0.3, 1, 0.3)
			if shuffle_button != null:
				shuffle_button.visible = false
	else:
		if selected_tile == tile_button:
			remove_glow_from_tile(selected_tile)
			selected_tile = null
		else:
			remove_glow_from_tile(selected_tile)
			selected_tile = tile_button
			apply_glow_to_tile(tile_button)

func swap_tiles(pos1: Vector2i, pos2: Vector2i):
	var tile1 = grid_matrix[pos1.x][pos1.y]
	var tile2 = grid_matrix[pos2.x][pos2.y]
	var temp_tex = tile1.texture_normal
	tile1.texture_normal = tile2.texture_normal
	tile2.texture_normal = temp_tex
	var temp_blank = tile1.get_meta("is_blank")
	tile1.set_meta("is_blank", tile2.get_meta("is_blank"))
	tile2.set_meta("is_blank", temp_blank)
	var temp_id = tile1.get_meta("original_id")
	tile1.set_meta("original_id", tile2.get_meta("original_id"))
	tile2.set_meta("original_id", temp_id)
	if tile1.get_meta("is_blank"):
		blank_tile_pos = pos1
	else:
		blank_tile_pos = pos2

func get_tile_grid_pos(tile_button: TextureButton) -> Vector2i:
	for x in range(GRID_COLS):
		for y in range(GRID_ROWS):
			if grid_matrix[x][y] == tile_button:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func shuffle_board():
	is_shuffling = true
	for i in range(80):
		var valid_neighbors = []
		var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for dir in directions:
			var target = blank_tile_pos + dir
			if target.x >= 0 and target.x < GRID_COLS and target.y >= 0 and target.y < GRID_ROWS:
				valid_neighbors.append(target)
		var random_target = valid_neighbors[randi() % valid_neighbors.size()]
		swap_tiles(blank_tile_pos, random_target)
	is_shuffling = false

func check_victory() -> bool:
	var expected_id = 0
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			if grid_matrix[x][y].get_meta("original_id") != expected_id:
				return false
			expected_id += 1
	return true
