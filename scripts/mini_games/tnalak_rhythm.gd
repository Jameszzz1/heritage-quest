extends Control

var note_speed = 300.0
var hit_y = 147.0
var spawn_y = 29.0
var perfect_range = 20.0
var good_range = 40.0
var score = 0
var combo = 0
var max_combo = 0
var last_best_shown = 0
var target_score = 150000
var target_combo = 50
var lane_keys = [KEY_D, KEY_F, KEY_J, KEY_K]
var lane_x = [105.0, 132.0, 161.0, 187.0]
var note_textures = []
var btn_idle = []
var btn_pressed = []
var game_started = false
var game_ended = false
var song_time = 0.0
var chart_index = 0

var travel_time = (147.0 - 29.0) / note_speed

# ---------- BEAT / TIMING SETTINGS ----------
var song_bpm = 111.0           # galing sa Tunebat (palitan kung ibang kanta)
var beat_offset = 0.0          # segundo kung kailan tumama ang UNANG beat ng kanta (i-adjust)
var snap_main_notes = false    # true = i-snap din sa beat grid ang raw_chart notes
var snap_division = 2          # 1 = bawat beat, 2 = bawat 8th note
var song_start_offset = 0.0    # pang-global na shift ng lahat ng notes (+ = mas huli)

# ---------- HOLD NOTE SETTINGS ----------
var auto_hold_every = 4        # bawat ika-4 na "fill" note ay magiging long hold (0 = walang auto hold)
var hold_beats = 1.5           # haba ng auto hold, sa beats
var hold_release_grace = 0.15  # ilang segundo pwedeng bumitaw bago masira ang hold
var hold_points_per_sec = 300.0
var hold_complete_bonus = 150
var tail_width_px = 5.0
var tail_colors = [
	Color(0.6, 0.6, 0.75, 0.9),   # D
	Color(1.0, 0.8, 0.2, 0.9),    # F
	Color(1.0, 0.3, 0.3, 0.9),    # J
	Color(1.0, 1.0, 1.0, 0.9),    # K
]
var keys_down = [false, false, false, false]
var hold_score_accum = 0.0

# ---------- FIRE / EFFECT SETTINGS ----------
var fire_combo_1 = 10          # maliit na apoy (habang hawak ang key)
var fire_combo_2 = 25          # malaking apoy sa lahat ng lanes
var last_fire_level = -1
var flames = []

var chart = []

# Gumagana kahit saang node nakakabit ang script (root man o HitZone)
@onready var scene_root = get_tree().current_scene
@onready var label_score = scene_root.get_node("UI/LabelScore")
@onready var label_combo = scene_root.get_node("UI/LabelCombo")
@onready var label_timer = scene_root.get_node("UI/LabelTimer")
@onready var label_countdown = scene_root.get_node("UI/LabelCountdown")
@onready var notes_node = scene_root.get_node("Notes")
@onready var audio_player = scene_root.get_node("AudioPlayer")
@onready var buttons = [
	scene_root.get_node("HitZone/ButtonD"),
	scene_root.get_node("HitZone/ButtonF"),
	scene_root.get_node("HitZone/ButtonJ"),
	scene_root.get_node("HitZone/ButtonK")
]

# label para sa highest combo (ginagawa ng code)
var label_best: Label


func _ready():
	# Kung ang root node ay may parehong script din, ang root lang ang tatakbo.
	# Ang kopya sa ibang node ay titigil para walang duplicate na label/popup/score.
	if self != scene_root and scene_root.get_script() == get_script():
		print("SOBRANG SCRIPT sa: ", get_path(), "  <- pwede mong tanggalin ang script sa node na ito")
		set_process(false)
		set_process_input(false)
		return

	MusicManager.stop_music()
	load_drum_chart()

	note_textures = [
		load("res://assets/mini_games/note_black.png"),
		load("res://assets/mini_games/note_gold.png"),
		load("res://assets/mini_games/note_red.png"),
		load("res://assets/mini_games/note_white.png"),
	]

	btn_idle = [
		load("res://assets/mini_games/btn_d_idle.png"),
		load("res://assets/mini_games/btn_f_idle.png"),
		load("res://assets/mini_games/btn_j_idle.png"),
		load("res://assets/mini_games/btn_k_idle.png"),
	]

	btn_pressed = [
		load("res://assets/mini_games/btn_d_pressed.png"),
		load("res://assets/mini_games/btn_f_pressed.png"),
		load("res://assets/mini_games/btn_j_pressed.png"),
		load("res://assets/mini_games/btn_k_pressed.png"),
	]

	var font = load("res://assets/fonts/GrapeSoda.ttf")

	label_countdown.add_theme_font_override("font", font)
	label_countdown.add_theme_font_size_override("font_size", 80)
	label_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_countdown.set_anchors_preset(Control.PRESET_CENTER)

	create_best_label()
	create_flames()
	update_hud_text()

	show_instructions_popup()


# Gumagawa ng BEST label. Binubura muna ang anumang lumang "LabelBest" sa buong scene.
func create_best_label() -> void:
	for old in scene_root.find_children("LabelBest*", "Label", true, false):
		old.get_parent().remove_child(old)
		old.queue_free()

	label_best = Label.new()
	label_best.name = "LabelBest"
	label_best.text = "BEST: 0"
	label_best.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_best.autowrap_mode = TextServer.AUTOWRAP_OFF
	label_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# kopyahin ang itsura ng LabelCombo
	label_best.add_theme_font_override("font", label_combo.get_theme_font("font"))
	label_best.add_theme_font_size_override("font_size", label_combo.get_theme_font_size("font_size"))
	label_best.add_theme_color_override("font_outline_color", label_combo.get_theme_color("font_outline_color"))
	label_best.add_theme_constant_override("outline_size", label_combo.get_theme_constant("outline_size"))

	label_score.get_parent().add_child(label_best)

	# ilagay sa ilalim ng score
	var score_h: float = max(label_score.size.y, label_score.get_minimum_size().y)
	label_best.position = Vector2(
		round(label_score.position.x),
		round(label_score.position.y + score_h + 4)
	)
	label_best.size = label_best.get_minimum_size()
	label_best.pivot_offset = Vector2(0, label_best.size.y / 2.0)
	label_best.modulate = Color(1, 0.9, 0.4)   # ginto


# pang-comma ng numbers (150000 -> 150,000)
func format_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


# score, combo, at best combo
func update_hud_text() -> void:
	label_score.text = "SCORE: " + format_number(score) + " / " + format_number(target_score)
	label_combo.text = "COMBO: " + str(combo) + " / " + str(target_combo)

	if label_best:
		var new_text := "BEST: " + str(max_combo)
		if label_best.text != new_text:
			label_best.text = new_text
			label_best.size = label_best.get_minimum_size()
			label_best.pivot_offset = Vector2(0, label_best.size.y / 2.0)
		if max_combo > last_best_shown:
			last_best_shown = max_combo
			pop_best_label()

	# Nagiging green kapag naabot na ang target
	label_score.modulate = Color(0.3, 1, 0.4) if score >= target_score else Color(1, 1, 1)
	label_combo.modulate = Color(0.3, 1, 0.4) if max_combo >= target_combo else Color(1, 1, 1)
	if label_best:
		label_best.modulate = Color(0.3, 1, 0.4) if max_combo >= target_combo else Color(1, 0.9, 0.4)


# maliit na pop kapag nag-new record
func pop_best_label() -> void:
	if label_best == null or last_best_shown <= 1:
		return
	label_best.scale = Vector2(1.0, 1.0)
	var tw := label_best.create_tween()
	tw.tween_property(label_best, "scale", Vector2(1.25, 1.25), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label_best, "scale", Vector2(1.0, 1.0), 0.1)


# Isinasara ang oras sa pinakamalapit na beat/subdivision ng kanta
func snap_to_grid(t: float) -> float:
	var step = (60.0 / song_bpm) / snap_division
	return beat_offset + round((t - beat_offset) / step) * step


# Format ng chart: [oras, lane] o [oras, lane, haba_ng_hold_sa_segundo]
# Halimbawa ng long hold sa raw_chart:  [4.833, 0, 1.2]
func load_drum_chart():
	var raw_chart = [
		[0.417, 0], [4.833, 0], [14.406, 3], [19.005, 3], [22.526, 3],
		[23.874, 3], [29.822, 3], [31.180, 3], [35.502, 3], [36.327, 3],
		[38.198, 3], [38.477, 3], [41.450, 3], [43.740, 0], [48.154, 0],
		[55.903, 3], [56.576, 0], [64.419, 3], [65.092, 0], [67.939, 3],
		[76.570, 3], [77.395, 1], [84.424, 3], [86.909, 0], [91.708, 3],
		[92.266, 3], [95.368, 1], [96.854, 3], [98.759, 1], [103.883, 3],
		[104.696, 3], [108.506, 0], [108.901, 0], [112.851, 0], [113.341, 2],
		[115.919, 2], [120.217, 1], [120.356, 1], [126.723, 1], [128.895, 1],
		[132.369, 1], [137.516, 1], [146.090, 1], [147.101, 1], [147.113, 3],
		[151.701, 0], [164.723, 0], [177.689, 0], [180.778, 1], [189.434, 1],
		[190.689, 0], [191.351, 0], [191.931, 0], [193.535, 0], [193.617, 2],
		[194.000, 2]
	]

	chart.clear()

	var sec_per_beat = 60.0 / song_bpm
	var current_lane = 0
	var fill_count = 0

	for i in range(raw_chart.size()):
		var current_note = raw_chart[i]
		var note_t: float = current_note[0]

		if i > 0:
			var prev_time = raw_chart[i - 1][0]
			var gap = note_t - prev_time

			if gap > 2.0:
				# unang beat na SUNOD sa nakaraang note, nakakabit sa beat grid ng music
				var n = ceil((prev_time - beat_offset) / sec_per_beat + 0.01)
				var fill_time = beat_offset + n * sec_per_beat

				while fill_time < (note_t - 0.5):
					current_lane = (current_lane + 1) % 4
					fill_count += 1

					var hold_len = 0.0
					if auto_hold_every > 0 and fill_count % auto_hold_every == 0:
						hold_len = sec_per_beat * hold_beats
						# huwag lumampas sa susunod na raw note
						hold_len = min(hold_len, note_t - fill_time - 0.3)
						if hold_len < 0.4:
							hold_len = 0.0

					chart.append([fill_time, current_lane, hold_len])
					fill_time += sec_per_beat

		if snap_main_notes:
			note_t = snap_to_grid(note_t)

		var main_hold = 0.0
		if current_note.size() > 2:
			main_hold = current_note[2]

		chart.append([note_t, current_note[1], main_hold])

	chart.sort_custom(func(a, b): return a[0] < b[0])


func show_instructions_popup() -> void:
	var popup := InstructionsPopup.new()

	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "T'NALAK RHYTHM: The Rhythm of the Weave"
	popup.start_hint = "Press SPACE to start"

	popup.steps = [
		{
			"icon": "rhythm_keys",
			"caption": "Press D, F, J, and K when the note reaches the line. Hold the key on long notes."
		},
		{
			"icon": "target",
			"caption": "Achieve a target score of 150,000 and a 50-hit combo."
		}
	]

	popup.dismissed.connect(start_countdown)

	scene_root.add_child(popup)


func start_countdown():
	var countdown_values = ["3", "2", "1", "START!"]

	for val in countdown_values:
		label_countdown.text = val
		await get_tree().create_timer(1.0).timeout

	label_countdown.visible = false

	# Start the rhythm game's own music
	audio_player.play()

	game_started = true


func _process(delta):
	if not game_started or game_ended:
		return

	if audio_player.playing:
		song_time = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	else:
		song_time += delta

	spawn_notes()
	move_notes(delta)
	update_fire()
	update_ui()

	if song_time > 1.0 and not audio_player.playing:
		end_game()


func spawn_notes():
	while chart_index < chart.size():
		var entry = chart[chart_index]
		var note_time = entry[0] + song_start_offset
		var lane = entry[1]
		var hold_len = 0.0
		if entry.size() > 2:
			hold_len = entry[2]

		if song_time >= (note_time - travel_time):
			create_note(lane, note_time, hold_len)
			chart_index += 1
		else:
			break


func create_note(lane, note_time, hold_len := 0.0):
	var sprite = Sprite2D.new()
	sprite.texture = note_textures[lane]
	sprite.set_meta("lane", lane)
	sprite.set_meta("note_time", note_time)
	sprite.set_meta("hold_len", hold_len)
	sprite.set_meta("holding", false)
	sprite.set_meta("lost", 0.0)
	notes_node.add_child(sprite)
	sprite.global_position = Vector2(lane_x[lane] + 14, spawn_y)
	sprite.scale = Vector2(0.05, 0.05)

	# Buntot ng long hold (child ng note, nasa likod ng ulo)
	if hold_len > 0.0:
		var tail = ColorRect.new()
		tail.name = "Tail"
		tail.color = tail_colors[lane]
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tail.show_behind_parent = true
		sprite.add_child(tail)
		set_tail(sprite, 0.0)


# Inaayos ang haba ng buntot (sa pixels). Hindi lumalampas sa taas ng playfield.
func set_tail(note: Node, length_px: float) -> void:
	var tail = note.get_node_or_null("Tail")
	if tail == null:
		return

	var visible_px = clamp(length_px, 0.0, max(0.0, note.position.y - spawn_y))
	var s = note.scale.x
	var w = tail_width_px / s
	var h = visible_px / s

	tail.size = Vector2(w, h)
	tail.position = Vector2(-w / 2.0, -h)


func move_notes(delta):
	for note in notes_node.get_children():
		if note.is_queued_for_deletion():
			continue

		# Hold na hawak ngayon
		if note.get_meta("holding"):
			update_hold(note, delta)
			continue

		var target_time = note.get_meta("note_time")
		var time_until_hit = target_time - song_time
		var calculated_y = hit_y - (time_until_hit * note_speed)

		note.position.y = calculated_y

		var hold_len: float = note.get_meta("hold_len")
		if hold_len > 0.0:
			set_tail(note, hold_len * note_speed)

		if note.position.y > hit_y + good_range:
			note.queue_free()
			miss()


# Habang hawak ang long note
func update_hold(note: Node, delta: float) -> void:
	var lane: int = note.get_meta("lane")
	var end_time: float = note.get_meta("note_time") + note.get_meta("hold_len")
	var remaining: float = end_time - song_time

	note.position.y = hit_y
	set_tail(note, remaining * note_speed)

	if keys_down[lane]:
		note.set_meta("lost", 0.0)
		hold_score_accum += delta * hold_points_per_sec
		var add_pts = int(hold_score_accum)
		if add_pts > 0:
			score += add_pts
			hold_score_accum -= add_pts
	else:
		note.set_meta("lost", float(note.get_meta("lost")) + delta)

	# Natapos ang hold
	if remaining <= 0.08:
		score += hold_complete_bonus
		spawn_burst(lane, true)
		note.queue_free()
		return

	# Bumitaw nang masyadong maaga
	if float(note.get_meta("lost")) > hold_release_grace:
		miss()
		note.queue_free()


func _input(event):
	if not game_started or game_ended:
		return
	if event is InputEventKey and not event.echo:
		for i in range(4):
			if event.keycode == lane_keys[i]:
				keys_down[i] = event.pressed
				if event.pressed:
					buttons[i].texture_normal = btn_pressed[i]
					press_anim(i)
					check_hit(i)
				else:
					buttons[i].texture_normal = btn_idle[i]
					release_anim(i)


func check_hit(lane):
	var closest = null
	var closest_dist = 9999.0
	for note in notes_node.get_children():
		if note.is_queued_for_deletion():
			continue
		if note.get_meta("holding"):
			continue
		if note.get_meta("lane") == lane:
			var dist = abs(note.position.y - hit_y)
			if dist < closest_dist:
				closest_dist = dist
				closest = note
	if closest == null:
		return
	if closest_dist <= perfect_range:
		hit(100)
		on_note_hit(lane, closest, true)
	elif closest_dist <= good_range:
		hit(50)
		on_note_hit(lane, closest, false)
	else:
		miss()


# Ano ang mangyayari sa note kapag tinamaan
func on_note_hit(lane: int, note: Node, perfect: bool) -> void:
	spawn_burst(lane, perfect)
	flash_button(lane)

	if float(note.get_meta("hold_len")) > 0.0:
		# long note: i-pin sa hit line at hintayin ang hold
		note.set_meta("holding", true)
		note.set_meta("lost", 0.0)
		note.position.y = hit_y
	else:
		note.queue_free()


func hit(points):
	combo += 1
	if combo > max_combo:
		max_combo = combo
	score += points * combo


func miss():
	combo = 0


# ---------------- ANIMATIONS / EFFECTS ----------------

# Lumiliit ng konti ang button kapag pinindot
func press_anim(i: int) -> void:
	var b = buttons[i]
	b.pivot_offset = b.size / 2.0
	b.scale = Vector2(0.9, 0.9)


func release_anim(i: int) -> void:
	var tw = buttons[i].create_tween()
	tw.tween_property(buttons[i], "scale", Vector2.ONE, 0.08)


# Mabilis na liwanag sa button kapag tumama
func flash_button(i: int) -> void:
	var b = buttons[i]
	b.modulate = Color(1.9, 1.7, 1.2)
	var tw = b.create_tween()
	tw.tween_property(b, "modulate", Color(1, 1, 1), 0.18)


func make_gradient(c0: Color, c1: Color, c2: Color) -> Gradient:
	var g = Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c2)
	g.add_point(0.5, c1)
	return g


func additive_material() -> CanvasItemMaterial:
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# Sparks kapag tumama ang note
func spawn_burst(lane: int, perfect: bool) -> void:
	var p = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18 if perfect else 10
	p.lifetime = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 140)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 75.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var base = Color(1.0, 0.9, 0.35, 1.0) if perfect else Color(1, 1, 1, 1)
	p.color_ramp = make_gradient(base, base, Color(base.r, base.g, base.b, 0.0))
	p.material = additive_material()
	p.z_index = 20
	scene_root.add_child(p)
	p.global_position = Vector2(lane_x[lane] + 14, hit_y)
	p.emitting = true
	p.finished.connect(p.queue_free)


# Apoy sa ilalim ng bawat lane (nag-o-on kapag mataas ang combo)
func create_flames() -> void:
	flames.clear()
	for i in range(4):
		var p = CPUParticles2D.new()
		p.emitting = false
		p.amount = 22
		p.lifetime = 0.5
		p.local_coords = false
		p.direction = Vector2(0, -1)
		p.spread = 22.0
		p.gravity = Vector2(0, -40)
		p.initial_velocity_min = 15.0
		p.initial_velocity_max = 35.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.5
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(7, 1)
		p.color_ramp = make_gradient(
			Color(1.0, 0.95, 0.4, 1.0),
			Color(1.0, 0.4, 0.1, 0.9),
			Color(0.5, 0.05, 0.0, 0.0)
		)
		p.material = additive_material()
		p.z_index = 15
		scene_root.add_child(p)
		p.global_position = Vector2(lane_x[i] + 14, hit_y)
		flames.append(p)


func update_fire() -> void:
	var level = 0
	if combo >= fire_combo_2:
		level = 2
	elif combo >= fire_combo_1:
		level = 1

	for i in range(flames.size()):
		var f = flames[i]
		# level 1: apoy lang habang hawak ang key. level 2: laging may apoy.
		f.emitting = level > 0 and (keys_down[i] or level == 2)
		if level != last_fire_level:
			f.scale_amount_max = 2.0 + level
			f.initial_velocity_max = 30.0 + level * 18.0
	last_fire_level = level


func update_ui():
	update_hud_text()

	var total_length = audio_player.stream.get_length() if audio_player.stream else 194.0
	var time_left = max(0, total_length - song_time)
	var minutes = int(time_left / 60)
	var seconds = int(fmod(time_left, 60))
	label_timer.text = "%02d:%02d" % [minutes, seconds]


func end_game():
	game_ended = true
	for f in flames:
		f.emitting = false
	for note in notes_node.get_children():
		note.queue_free()
	if score >= target_score and max_combo >= target_combo:
		show_result(true)
	else:
		show_result(false)


func show_result(success: bool):
	var font = load("res://assets/fonts/GrapeSoda.ttf")

	# Markahan agad na natapos ang mini game
	if success:
		Global.mark_minigame_passed(Global.current_minigame_npc)
		Global.unlock_badge("dreamweaver_apprentice")

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	scene_root.add_child(overlay)

	var container = CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(container)

	var box = PanelContainer.new()
	var screen_size = get_viewport_rect().size
	var panel_width = clamp(screen_size.x * 0.7, 140, 260)
	var panel_height = clamp(screen_size.y * 0.7, 110, 190)
	box.custom_minimum_size = Vector2(panel_width, panel_height)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.65, 0.2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	box.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(vbox)
	box.add_child(margin)

	var title = Label.new()
	var msg = Label.new()
	var btn = Button.new()

	if success:
		title.text = "CONGRATULATIONS!"
		msg.text = "Natapos mo ang Mini Game!\nScore: " + str(score) + "\nMax Combo: " + str(max_combo) + "\n\nKausapin si Bai Linay para makuha ang Token."
		btn.text = "Back"
	else:
		title.text = "TRY AGAIN!"
		msg.text = "Score: " + str(score) + "/" + str(target_score) + "\nMax Combo: " + str(max_combo) + "/" + str(target_combo)
		btn.text = "Try Again"

	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color(0.3, 1, 0.4) if success else Color(1, 0.35, 0.35)

	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_override("font", font)
	msg.add_theme_font_size_override("font_size", 7)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)

	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 7)
	btn.custom_minimum_size = Vector2(80, 20)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	vbox.add_child(title)
	vbox.add_child(msg)
	vbox.add_child(spacer)
	vbox.add_child(btn)

	container.add_child(box)

	if success:
		btn.pressed.connect(_on_result_back.bind(overlay))
	else:
		btn.pressed.connect(_on_result_retry)


func _on_result_back(overlay: Node) -> void:
	overlay.queue_free()
	Global.spawn_position = Global.return_spawn_pos
	get_tree().change_scene_to_file(Global.return_scene)


func _on_result_retry() -> void:
	get_tree().reload_current_scene()
