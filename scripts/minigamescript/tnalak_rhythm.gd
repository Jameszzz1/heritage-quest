extends Control

var note_speed = 300.0
var hit_y = 147.0
var perfect_range = 20.0
var good_range = 40.0
var score = 0
var combo = 0
var max_combo = 0
var target_score = 100000
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

# Travel time mula itaas ($Y=29.0$) hanggang HitZone ($Y=147.0$)
var travel_time = (147.0 - 29.0) / note_speed

# --- TIMING TUNING PARA SA BayanGong_Rythmn ---
var song_bpm = 120.0 
var song_start_offset = 0.0 # Naka-align na sa exact JSON timestamps

var chart = []

# Drum SFX Preload (Kapag pinipindot ang D, F, J, K)
var drum_sfx = {
	"D": preload("res://assets/audio/mini_game_audio/D_drum.wav"),
	"F": preload("res://assets/audio/mini_game_audio/F_drum.wav"),
	"J": preload("res://assets/audio/mini_game_audio/J_drum.wav"),
	"K": preload("res://assets/audio/mini_game_audio/K_drum.wav")
}

@onready var label_score = $UI/LabelScore
@onready var label_combo = $UI/LabelCombo
@onready var label_timer = $UI/LabelTimer
@onready var label_countdown = $UI/LabelCountdown
@onready var notes_node = $Notes
@onready var audio_player = $AudioPlayer
@onready var buttons = [$HitZone/BtnD, $HitZone/BtnF, $HitZone/BtnJ, $HitZone/BtnK]

func _ready():
	load_drum_chart()
	
	note_textures = [
		load("res://assets/images/mini_games/note_black.png"),
		load("res://assets/images/mini_games/note_gold.png"),
		load("res://assets/images/mini_games/note_red.png"),
		load("res://assets/images/mini_games/note_white.png"),
	]
	btn_idle = [
		load("res://assets/images/mini_games/btn_d_idle.png"),
		load("res://assets/images/mini_games/btn_f_idle.png"),
		load("res://assets/images/mini_games/btn_j_idle.png"),
		load("res://assets/images/mini_games/btn_k_idle.png"),
	]
	btn_pressed = [
		load("res://assets/images/mini_games/btn_d_pressed.png"),
		load("res://assets/images/mini_games/btn_f_pressed.png"),
		load("res://assets/images/mini_games/btn_j_pressed.png"),
		load("res://assets/images/mini_games/btn_k_pressed.png"),
	]

	var font = load("res://assets/fonts/GrapeSoda.ttf")
	label_countdown.add_theme_font_override("font", font)
	label_countdown.add_theme_font_size_override("font_size", 80)
	label_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_countdown.set_anchors_preset(Control.PRESET_CENTER)

	show_instructions_popup()

# Kinakarga ang eksaktong timing mula sa ating Drum Track JSON Data (Lane 1-4 mapped to 0-3 index)
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
	
	# Punuin ang malalaking gaps (2+ seconds) ng constant quarter-beat notes sa BPM 120
	var sec_per_beat = 60.0 / song_bpm # 0.5s bawat beat
	var current_lane = 0
	
	for i in range(raw_chart.size()):
		var current_note = raw_chart[i]
		
		# Kung may naunang note at higit sa 2.0s ang gap, punuan ito
		if i > 0:
			var prev_time = raw_chart[i - 1][0]
			var gap = current_note[0] - prev_time
			
			if gap > 2.0:
				var fill_time = prev_time + sec_per_beat
				while fill_time < (current_note[0] - 0.5):
					current_lane = (current_lane + 1) % 4
					chart.append([fill_time, current_lane])
					fill_time += sec_per_beat
		
		chart.append(current_note)
		
	# I-sort ang chart ayon sa timestamp
	chart.sort_custom(func(a, b): return a[0] < b[0])

func show_instructions_popup() -> void:
	var popup := InstructionsPopup.new()
	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "T'NALAK RHYTHM: The Rhythm of the Weave"
	popup.start_hint = "Press SPACE to start"
	popup.steps = [
		{"icon": "rhythm_keys", "caption": "Press D, F, J, and K when the note reaches the line."},
		{"icon": "target", "caption": "Achieve a target score of 100,000 and a 50-hit combo."}
	]
	popup.dismissed.connect(start_countdown)
	add_child(popup)

func start_countdown():
	var countdown_values = ["3", "2", "1", "START!"]
	for val in countdown_values:
		label_countdown.text = val
		await get_tree().create_timer(1.0).timeout
	label_countdown.visible = false
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
	move_notes()
	update_ui()
	
	if song_time > 1.0 and not audio_player.playing:
		end_game()

func spawn_notes():
	while chart_index < chart.size():
		var note_time = chart[chart_index][0] + song_start_offset
		var lane = chart[chart_index][1]
		
		if song_time >= (note_time - travel_time):
			create_note(lane, note_time)
			chart_index += 1
		else:
			break

func create_note(lane, note_time):
	var sprite = Sprite2D.new()
	sprite.texture = note_textures[lane]
	sprite.set_meta("lane", lane)
	sprite.set_meta("note_time", note_time)
	notes_node.add_child(sprite)
	sprite.global_position = Vector2(lane_x[lane] + 14, 29.0)
	sprite.scale = Vector2(0.05, 0.05)

func move_notes():
	for note in notes_node.get_children():
		var target_time = note.get_meta("note_time")
		var time_until_hit = target_time - song_time
		var calculated_y = hit_y - (time_until_hit * note_speed)
		
		note.position.y = calculated_y
		
		if note.position.y > hit_y + good_range:
			note.queue_free()
			miss()

func _input(event):
	if not game_started or game_ended:
		return
	if event is InputEventKey and not event.echo:
		var lane_names = ["D", "F", "J", "K"]
		for i in range(4):
			if event.keycode == lane_keys[i]:
				if event.pressed:
					buttons[i].texture_normal = btn_pressed[i]
					play_drum_sound(lane_names[i])
					check_hit(i)
				else:
					buttons[i].texture_normal = btn_idle[i]

func play_drum_sound(lane: String) -> void:
	if drum_sfx.has(lane):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.stream = drum_sfx[lane]
		sfx_player.volume_db = -25.0 
		
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)

func check_hit(lane):
	var closest = null
	var closest_dist = 9999.0
	for note in notes_node.get_children():
		if note.get_meta("lane") == lane:
			var dist = abs(note.position.y - hit_y)
			if dist < closest_dist:
				closest_dist = dist
				closest = note
	if closest == null:
		return
	if closest_dist <= perfect_range:
		hit(100)
		closest.queue_free()
	elif closest_dist <= good_range:
		hit(50)
		closest.queue_free()
	else:
		miss()

func hit(points):
	combo += 1
	if combo > max_combo:
		max_combo = combo
	score += points * combo

func miss():
	combo = 0

func update_ui():
	label_score.text = "SCORE: " + str(score)
	label_combo.text = "COMBO: " + str(combo)
	var total_length = audio_player.stream.get_length() if audio_player.stream else 194.0
	var time_left = max(0, total_length - song_time)
	var minutes = int(time_left / 60)
	var seconds = int(fmod(time_left, 60))
	label_timer.text = "%02d:%02d" % [minutes, seconds]

func end_game():
	game_ended = true
	for note in notes_node.get_children():
		note.queue_free()
	if score >= target_score and max_combo >= target_combo:
		show_result(true)
	else:
		show_result(false)

func show_result(success: bool):
	var font = load("res://assets/fonts/GrapeSoda.ttf")

	var popup = Panel.new()
	popup.size = Vector2(500, 300)
	popup.position = Vector2(
		(get_viewport_rect().size.x / 2) - 250,
		(get_viewport_rect().size.y / 2) - 150
	)
	add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_child(vbox)

	var title = Label.new()
	var msg = Label.new()
	var btn = Button.new()

	if success:
		title.text = "CONGRATULATIONS!"
		msg.text = "You earned the Scholar Token!\nScore: " + str(score) + "\nMax Combo: " + str(max_combo)
		btn.text = "Claim Token"
	else:
		title.text = "TRY AGAIN!"
		msg.text = "Score: " + str(score) + "/" + str(target_score) + "\nMax Combo: " + str(max_combo) + "/" + str(target_combo)
		btn.text = "Try Again"

	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 40)

	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_override("font", font)
	msg.add_theme_font_size_override("font_size", 24)

	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.custom_minimum_size = Vector2(200, 50)

	vbox.add_child(title)
	vbox.add_child(msg)
	vbox.add_child(btn)

	if success:
		btn.pressed.connect(func(): popup.queue_free())
	else:
		btn.pressed.connect(func(): get_tree().reload_current_scene())
