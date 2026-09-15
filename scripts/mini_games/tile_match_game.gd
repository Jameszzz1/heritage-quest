extends Control

@onready var grid_container = $Grid
@onready var score_label = $ScoreLabel
@onready var timer_label = $TimerLabel
@onready var game_timer = $GameTimer
@onready var match_sound = $MatchSound

const GRID_SIZE = 8
const TILE_WIDTH = 21
const TILE_HEIGHT = 17
const TARGET_SCORE = 50000   # 50,000

var score = 0
var time_left = 120
var game_over = false
var game_started = false

var tile_textures = [
	preload("res://assets/images/provinces/sultan_kudarat/blue.png"),
	preload("res://assets/images/provinces/sultan_kudarat/yellow.png"),
	preload("res://assets/images/provinces/sultan_kudarat/purple.png"),
	preload("res://assets/images/provinces/sultan_kudarat/red.png"),
	preload("res://assets/images/provinces/sultan_kudarat/green.png"),
	preload("res://assets/images/provinces/sultan_kudarat/cyan.png")
]

var grid_matrix = []
var first_selected_tile = null
var second_selected_tile = null
var is_animating = false
var drag_start_pos = Vector2.ZERO
var is_holding = false
var combo_count = 0

func _ready():
	randomize()
	grid_container.columns = GRID_SIZE
	score_label.text = "SCORE: 0 / 50,000"
	timer_label.text = "TIME: " + str(time_left) + "s"
	setup_grid()
	game_timer.wait_time = 1.0
	game_timer.one_shot = false
	game_timer.timeout.connect(_on_timer_timeout)
	show_instructions_popup()

func show_instructions_popup() -> void:
	var popup := InstructionsPopup.new()
	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "SULTAN KUDARAT: Tile Match"
	popup.start_hint = "Press SPACE to start
"
	popup.steps = [
		{"icon": "match_three", "caption": "Match 3+ identical colors or icons."},
		{"icon": "tile_click", "caption": "Drag to swap with the adjacent tile."},
		{"icon": "timer", "caption": "Reach the target score of 50,000 before time runs out."}
	]
	popup.dismissed.connect(_on_instructions_dismissed)
	add_child(popup)

func _on_instructions_dismissed() -> void:
	game_started = true
	game_timer.start()

func setup_grid():
	grid_matrix.resize(GRID_SIZE)
	for x in range(GRID_SIZE):
		grid_matrix[x] = []
		grid_matrix[x].resize(GRID_SIZE)
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var random_index = randi() % tile_textures.size()
			while (x > 1 and grid_matrix[x-1][y] != null and grid_matrix[x-1][y].get_meta("tile_type") == random_index and grid_matrix[x-2][y].get_meta("tile_type") == random_index) or \
			  (y > 1 and grid_matrix[x][y-1] != null and grid_matrix[x][y-1].get_meta("tile_type") == random_index and grid_matrix[x][y-2].get_meta("tile_type") == random_index):
				random_index = randi() % tile_textures.size()
			create_tile_button(x, y, random_index)
	check_board_moves_availability()

func create_tile_button(x, y, type_index):
	var button = TextureButton.new()
	button.texture_normal = tile_textures[type_index]
	button.ignore_texture_size = true
	button.custom_minimum_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.pivot_offset = Vector2(TILE_WIDTH / 2, TILE_HEIGHT / 2)
	button.set_meta("grid_pos", Vector2i(x, y))
	button.set_meta("tile_type", type_index)
	button.gui_input.connect(func(event): _on_tile_gui_input(button, event))
	grid_container.add_child(button)
	grid_matrix[x][y] = button

func _on_tile_gui_input(tile_button: TextureButton, event: InputEvent):
	if not game_started or game_over or is_animating: return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		is_holding = true
		drag_start_pos = event.position
		if first_selected_tile == null:
			first_selected_tile = tile_button
			tile_button.modulate = Color(1, 0.6, 0.6)
			var tween = create_tween()
			tween.tween_property(tile_button, "scale", Vector2(1.15, 1.15), 0.1)
		elif first_selected_tile == tile_button:
			reset_selection_visuals()
			first_selected_tile = null
			is_holding = false
		else:
			var t1 = first_selected_tile
			var t2 = tile_button
			first_selected_tile = null
			second_selected_tile = null
			check_and_execute_swap(t1, t2)
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.is_pressed():
		is_holding = false
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_holding:
		if first_selected_tile == tile_button:
			var diff = event.position - drag_start_pos
			if abs(diff.x) > 15 or abs(diff.y) > 15:
				is_holding = false
				var first_grid_pos = tile_button.get_meta("grid_pos")
				var target_grid_pos = first_grid_pos
				if abs(diff.x) > abs(diff.y):
					target_grid_pos.x += 1 if diff.x > 0 else -1
				else:
					target_grid_pos.y += 1 if diff.y > 0 else -1
				if target_grid_pos.x >= 0 and target_grid_pos.x < GRID_SIZE and target_grid_pos.y >= 0 and target_grid_pos.y < GRID_SIZE:
					var t1 = first_selected_tile
					var t2 = grid_matrix[target_grid_pos.x][target_grid_pos.y]
					first_selected_tile = null
					second_selected_tile = null
					check_and_execute_swap(t1, t2)
				else:
					reset_selection_visuals()
					first_selected_tile = null

func check_and_execute_swap(tile1: TextureButton, tile2: TextureButton):
	if tile1 == null or tile2 == null:
		is_animating = false
		return
	is_animating = true
	combo_count = 0
	tile1.modulate = Color(1, 1, 1)
	var reset_tween = create_tween()
	reset_tween.tween_property(tile1, "scale", Vector2(1.0, 1.0), 0.05)
	await reset_tween.finished
	var first_pos = tile1.get_meta("grid_pos")
	var second_pos = tile2.get_meta("grid_pos")
	if (abs(first_pos.x - second_pos.x) + abs(first_pos.y - second_pos.y)) == 1:
		await execute_swap_animated(tile1, tile2)
		var matches = scan_entire_grid()
		if matches.size() > 0:
			await process_matches(matches)
		else:
			await execute_swap_animated(tile1, tile2)
	is_animating = false

func reset_selection_visuals():
	if first_selected_tile != null:
		first_selected_tile.modulate = Color(1, 1, 1)
		var tween = create_tween()
		tween.tween_property(first_selected_tile, "scale", Vector2(1.0, 1.0), 0.1)

func execute_swap_animated(tile1: TextureButton, tile2: TextureButton):
	var type1 = tile1.get_meta("tile_type")
	var type2 = tile2.get_meta("tile_type")
	tile1.texture_normal = tile_textures[type2]
	tile2.texture_normal = tile_textures[type1]
	tile1.set_meta("tile_type", type2)
	tile2.set_meta("tile_type", type1)
	tile1.modulate = Color(1, 1, 1)
	tile2.modulate = Color(1, 1, 1)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tile1, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile2, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	await tween.finished
	var tween_back = create_tween().set_parallel(true)
	tween_back.tween_property(tile1, "scale", Vector2(1.0, 1.0), 0.05)
	tween_back.tween_property(tile2, "scale", Vector2(1.0, 1.0), 0.05)
	await tween_back.finished

func scan_entire_grid() -> Array:
	var matched_positions = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE - 2):
			if grid_matrix[x][y] == null: continue
			var type = grid_matrix[x][y].get_meta("tile_type")
			if type == -1: continue
			if grid_matrix[x+1][y].get_meta("tile_type") == type and grid_matrix[x+2][y].get_meta("tile_type") == type:
				var combo = [Vector2i(x, y), Vector2i(x+1, y), Vector2i(x+2, y)]
				var next_x = x + 3
				while next_x < GRID_SIZE and grid_matrix[next_x][y].get_meta("tile_type") == type:
					combo.append(Vector2i(next_x, y))
					next_x += 1
				for pos in combo:
					if not matched_positions.has(pos):
						matched_positions.append(pos)
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE - 2):
			if grid_matrix[x][y] == null: continue
			var type = grid_matrix[x][y].get_meta("tile_type")
			if type == -1: continue
			if grid_matrix[x][y+1].get_meta("tile_type") == type and grid_matrix[x][y+2].get_meta("tile_type") == type:
				var combo = [Vector2i(x, y), Vector2i(x, y+1), Vector2i(x, y+2)]
				var next_y = y + 3
				while next_y < GRID_SIZE and grid_matrix[x][next_y].get_meta("tile_type") == type:
					combo.append(Vector2i(x, next_y))
					next_y += 1
				for pos in combo:
					if not matched_positions.has(pos):
						matched_positions.append(pos)
	return matched_positions

func process_matches(match_list: Array):
	if match_list.size() == 0:
		is_animating = false
		return
	combo_count += 1
	var base = match_list.size()
	var bonus = 0
	if base == 4: bonus = 100
	elif base == 5: bonus = 300
	elif base > 5: bonus = 500
	score += (base * 100) + bonus
	score_label.text = "SCORE: " + str(score) + " / 50,000"
	
	if match_sound:
		match_sound.stop()
		match_sound.pitch_scale = min(0.9 + (combo_count * 0.15), 2.0)
		match_sound.play()
	
	var fade_tween = create_tween().set_parallel(true)
	for pos in match_list:
		var tile = grid_matrix[pos.x][pos.y]
		fade_tween.tween_property(tile, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK)
		fade_tween.tween_property(tile, "modulate:a", 0.0, 0.15)
	await fade_tween.finished
	
	for pos in match_list:
		var tile = grid_matrix[pos.x][pos.y]
		tile.texture_normal = null
		tile.modulate = Color(1, 1, 1, 1)
		tile.scale = Vector2(1.0, 1.0)
		tile.set_meta("tile_type", -1)
	
	await drop_tiles_down()
	await fill_empty_tiles()
	await get_tree().create_timer(0.15).timeout
	
	var chain_matches = scan_entire_grid()
	if chain_matches.size() > 0:
		await process_matches(chain_matches)
	else:
		combo_count = 0
		if score >= TARGET_SCORE and not game_over:
			trigger_end_state(true)
		else:
			check_board_moves_availability()

# Paste the remaining functions (drop_tiles_down, fill_empty_tiles, etc.) below if needed.
# Let me know if there are more errors.

func drop_tiles_down():
	var has_movement = false
	for x in range(GRID_SIZE):
		var empty_slots = 0
		for y in range(GRID_SIZE - 1, -1, -1):
			if grid_matrix[x][y].get_meta("tile_type") == -1:
				empty_slots += 1
			elif empty_slots > 0:
				has_movement = true
				var target_y = y + empty_slots
				var moving_type = grid_matrix[x][y].get_meta("tile_type")
				grid_matrix[x][target_y].texture_normal = tile_textures[moving_type]
				grid_matrix[x][target_y].set_meta("tile_type", moving_type)
				grid_matrix[x][target_y].scale = Vector2(1.0, 1.0)
				grid_matrix[x][y].texture_normal = null
				grid_matrix[x][y].set_meta("tile_type", -1)
				grid_matrix[x][y].scale = Vector2(1.0, 1.0)
	
	if has_movement:
		var drop_tween = create_tween().set_parallel(true)
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				if grid_matrix[x][y].get_meta("tile_type") != -1:
					drop_tween.tween_property(grid_matrix[x][y], "scale", Vector2(1.0, 1.0), 0.08)
		await drop_tween.finished
	else:
		await get_tree().create_timer(0.05).timeout


func fill_empty_tiles():
	var empty_tiles = []
	for x in range(GRID_SIZE):
		var fill_y = 0
		for y in range(GRID_SIZE):
			if grid_matrix[x][y].get_meta("tile_type") == -1:
				empty_tiles.append({"tile": grid_matrix[x][y], "delay": fill_y * 0.03})
				fill_y += 1
	
	if empty_tiles.size() == 0:
		return
	
	for entry in empty_tiles:
		var new_type = randi() % tile_textures.size()
		entry.tile.texture_normal = tile_textures[new_type]
		entry.tile.set_meta("tile_type", new_type)
		entry.tile.scale = Vector2(0.3, 0.3)
		entry.tile.modulate = Color(1, 1, 1, 0)
	
	var fill_tween = create_tween().set_parallel(true)
	for entry in empty_tiles:
		fill_tween.tween_property(entry.tile, "scale", Vector2(1.0, 1.0), 0.2) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(entry.delay)
		fill_tween.tween_property(entry.tile, "modulate:a", 1.0, 0.15) \
			.set_delay(entry.delay)
	await fill_tween.finished


func check_board_moves_availability():
	if has_valid_moves_left(): 
		return
	is_animating = true
	var alert_tween = create_tween()
	alert_tween.tween_property(score_label, "modulate", Color(1, 0.3, 0.3), 0.15)
	alert_tween.tween_property(score_label, "modulate", Color(1, 1, 1), 0.15)
	alert_tween.tween_property(score_label, "modulate", Color(1, 0.3, 0.3), 0.15)
	alert_tween.tween_property(score_label, "modulate", Color(1, 1, 1), 0.15)
	await alert_tween.finished
	
	var shuffle_success = false
	var attempts = 0
	while not shuffle_success and attempts < 100:
		attempts += 1
		var all_types = []
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				all_types.append(grid_matrix[x][y].get_meta("tile_type"))
		all_types.shuffle()
		
		var index = 0
		for y in range(GRID_SIZE):
			for x in range(GRID_SIZE):
				grid_matrix[x][y].set_meta("tile_type", all_types[index])
				grid_matrix[x][y].texture_normal = tile_textures[all_types[index]]
				index += 1
		
		if scan_entire_grid().size() == 0 and has_valid_moves_left():
			shuffle_success = true
	
	var pop_tween = create_tween().set_parallel(true)
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var delay = (x + y) * 0.015
			grid_matrix[x][y].scale = Vector2(0.5, 0.5)
			pop_tween.tween_property(grid_matrix[x][y], "scale", Vector2(1.0, 1.0), 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	await pop_tween.finished
	is_animating = false


func has_valid_moves_left() -> bool:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if x < GRID_SIZE - 1:
				if test_simulated_match(Vector2i(x, y), Vector2i(x + 1, y)): 
					return true
			if y < GRID_SIZE - 1:
				if test_simulated_match(Vector2i(x, y), Vector2i(x, y + 1)): 
					return true
	return false


func test_simulated_match(pos1: Vector2i, pos2: Vector2i) -> bool:
	var type1 = grid_matrix[pos1.x][pos1.y].get_meta("tile_type")
	var type2 = grid_matrix[pos2.x][pos2.y].get_meta("tile_type")
	grid_matrix[pos1.x][pos1.y].set_meta("tile_type", type2)
	grid_matrix[pos2.x][pos2.y].set_meta("tile_type", type1)
	var result = scan_entire_grid().size() > 0
	grid_matrix[pos1.x][pos1.y].set_meta("tile_type", type1)
	grid_matrix[pos2.x][pos2.y].set_meta("tile_type", type2)
	return result


func _on_timer_timeout():
	if game_over: return
	if time_left > 0:
		time_left -= 1
		timer_label.text = "TIME: " + str(time_left) + "s"
		if time_left <= 10:
			var flash = create_tween()
			flash.tween_property(timer_label, "modulate", Color(1, 0.3, 0.3), 0.3)
			flash.tween_property(timer_label, "modulate", Color(1, 1, 1), 0.3)
	else:
		trigger_end_state(false)


func trigger_end_state(is_victory: bool):
	game_over = true
	game_timer.stop()
	is_animating = true
	if is_victory:
		timer_label.text = "TASK SUCCESS!"
		score_label.modulate = Color(0.3, 1, 0.3)
	else:
		timer_label.text = "TIME'S UP!"
		score_label.modulate = Color(1, 0.3, 0.3)
