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
var spawn_ahead = 2.0
var chart_index = 0

var chart = [
	[2.0,0],[2.54,1],[3.08,2],[3.62,3],
	[4.16,0],[4.70,2],[5.24,1],[5.78,3],
	[6.32,0],[6.86,1],[7.40,2],[7.94,3],
	[8.48,1],[9.02,0],[9.56,3],[10.10,2],
	[10.64,0],[11.18,1],[11.72,2],[12.26,3],
	[12.80,0],[13.34,2],[13.88,1],[14.42,3],
	[14.96,0],[15.50,3],[16.04,1],[16.58,2],
	[17.12,0],[17.66,1],[18.20,2],[18.74,3],
	[19.28,2],[19.82,0],[20.36,3],[20.90,1],
	[21.44,0],[21.98,1],[22.52,2],[23.06,3],
	[23.60,0],[24.14,2],[24.68,1],[25.22,3],
	[25.76,0],[26.30,1],[26.84,2],[27.38,3],
	[27.92,1],[28.46,0],[29.00,3],[29.54,2],
	[30.08,0],[30.62,1],[31.16,2],[31.70,3],
	[32.24,2],[32.78,0],[33.32,3],[33.86,1],
	[34.40,0],[34.94,1],[35.48,2],[36.02,3],
	[36.56,0],[37.10,2],[37.64,1],[38.18,3],
	[38.72,1],[39.26,0],[39.80,3],[40.34,2],
	[40.88,0],[41.42,1],[41.96,2],[42.50,3],
	[43.04,0],[43.58,2],[44.12,1],[44.66,3],
	[45.20,0],[45.74,1],[46.28,2],[46.82,3],
	[47.36,2],[47.90,0],[48.44,3],[48.98,1],
	[49.52,0],[50.06,1],[50.60,2],[51.14,3],
	[52.0,0],[52.27,1],[52.54,2],[52.81,3],
	[53.08,0],[53.35,2],[53.62,1],[53.89,3],
	[54.16,0],[54.43,1],[54.70,3],[54.97,2],
	[55.24,1],[55.51,0],[55.78,3],[56.05,2],
	[56.32,0],[56.59,1],[56.86,2],[57.13,3],
	[57.40,2],[57.67,0],[57.94,3],[58.21,1],
	[58.48,0],[58.75,1],[59.02,2],[59.29,3],
	[59.56,0],[59.83,2],[60.10,1],[60.37,3],
	[60.64,1],[60.91,0],[61.18,3],[61.45,2],
	[61.72,0],[61.99,1],[62.26,2],[62.53,3],
	[62.80,0],[63.07,2],[63.34,1],[63.61,3],
	[63.88,1],[64.15,0],[64.42,3],[64.69,2],
	[64.96,0],[65.23,1],[65.50,2],[65.77,3],
	[66.04,2],[66.31,0],[66.58,3],[66.85,1],
	[67.12,0],[67.39,1],[67.66,2],[67.93,3],
	[68.20,0],[68.47,2],[68.74,1],[69.01,3],
	[69.28,1],[69.55,0],[69.82,3],[70.09,2],
	[70.36,0],[70.63,1],[70.90,2],[71.17,3],
	[71.44,2],[71.71,0],[71.98,3],[72.25,1],
	[72.52,0],[72.79,1],[73.06,2],[73.33,3],
	[73.60,0],[73.87,2],[74.14,1],[74.41,3],
	[74.68,1],[74.95,0],[75.22,3],[75.49,2],
	[75.76,0],[76.03,1],[76.30,2],[76.57,3],
	[76.84,2],[77.11,0],[77.38,3],[77.65,1],
	[77.92,0],[78.19,1],[78.46,2],[78.73,3],
	[79.00,0],[79.27,2],[79.54,1],[79.81,3],
	[80.08,1],[80.35,0],[80.62,3],[80.89,2],
	[81.16,0],[81.43,1],[81.70,2],[81.97,3],
	[82.24,2],[82.51,0],[82.78,3],[83.05,1],
	[83.32,0],[83.59,1],[83.86,2],[84.13,3],
	[84.40,0],[84.67,2],[84.94,1],[85.22,3],
	[85.49,0],[85.76,1],[86.03,2],[86.30,3],
	[86.57,2],[86.84,0],[87.11,3],[87.38,1],
	[87.65,0],[87.92,1],[88.19,2],[88.46,3],
	[88.54,0],[89.08,1],[89.62,2],[90.16,3],
	[90.70,0],[91.24,2],[91.78,1],[92.32,3],
	[92.86,0],[93.40,1],[93.94,2],[94.48,3],
	[95.02,1],[95.56,0],[96.10,3],[96.64,2],
	[97.18,0],[97.72,1],[98.26,2],[98.80,3],
	[99.34,2],[99.88,0],[100.42,3],[100.96,1],
	[101.50,0],[102.04,1],[102.58,2],[103.12,3],
	[103.66,0],[104.20,2],[104.74,1],[105.28,3],
	[105.82,1],[106.36,0],[106.90,3],[107.44,2],
	[108.00,0],[108.54,1],[109.08,2],[109.62,3],
	[110.16,2],[110.70,0],[111.24,3],[111.78,1],
	[112.32,0],[112.86,1],[113.40,2],[113.94,3],
	[114.48,0],[115.02,2],[115.56,1],[116.10,3],
	[116.64,1],[117.18,0],[117.72,3],[118.26,2],
	[118.80,0],[119.34,1],[119.88,2],[120.42,3],
	[120.96,2],[121.50,0],[122.04,3],[122.58,1],
	[123.12,0],[123.66,1],[124.20,2],[124.74,3],
	[125.28,0],[125.82,2],[126.36,1],[126.90,3],
	[127.44,1],[127.98,0],[128.52,3],[129.06,2],
	[129.60,0],[130.14,1],[130.68,2],[131.22,3],
	[131.76,2],[132.30,0],[132.84,3],[133.38,1],
	[133.92,0],[134.46,1],[135.00,2],[135.54,3],
	[136.08,0],[136.62,2],[137.16,1],[137.70,3],
	[138.24,1],[138.78,0],[139.32,3],[139.86,2],
	[140.40,0],[140.94,1],[141.48,2],[142.02,3],
	[142.56,2],[143.10,0],[143.64,3],[144.18,1],
	[144.72,0],[145.26,1],[145.80,2],[146.34,3],
	[146.88,0],[147.42,2],[147.96,1],[148.50,3],
	[149.04,1],[149.58,0],[150.12,3],[150.66,2],
	[151.20,0],[151.74,1],[152.28,2],[152.82,3],
	[155.0,0],[155.27,1],[155.54,2],[155.81,3],
	[156.08,0],[156.35,1],[156.62,2],[156.89,3],
	[157.16,0],[157.43,2],[157.70,1],[157.97,3],
	[158.24,1],[158.51,0],[158.78,3],[159.05,2],
	[159.32,0],[159.59,1],[159.86,2],[160.13,3],
	[160.40,2],[160.67,0],[160.94,3],[161.21,1],
	[161.48,0],[161.75,1],[162.02,2],[162.29,3],
	[162.56,0],[162.83,2],[163.10,1],[163.37,3],
	[163.64,1],[163.91,0],[164.18,3],[164.45,2],
	[164.72,0],[164.99,1],[165.26,2],[165.53,3],
	[165.80,0],[166.07,2],[166.34,1],[166.61,3],
	[166.88,1],[167.15,0],[167.42,3],[167.69,2],
	[167.96,0],[168.23,1],[168.50,2],[168.77,3],
	[169.04,2],[169.31,0],[169.58,3],[169.85,1],
	[170.12,0],[170.39,1],[170.66,2],[170.93,3],
	[171.20,0],[171.47,2],[171.74,1],[172.01,3],
	[172.28,1],[172.55,0],[172.82,3],[173.09,2],
	[173.36,0],[173.63,1],[173.90,2],[174.17,3],
	[174.44,2],[174.71,0],[174.98,3],[175.25,1],
	[175.52,0],[175.79,1],[176.06,2],[176.33,3],
	[176.60,0],[176.87,2],[177.14,1],[177.41,3],
	[177.68,1],[177.95,0],[178.22,3],[178.49,2],
	[178.76,0],[179.03,1],[179.30,2],[179.57,3],
	[179.84,2],[180.11,0],[180.38,3],[180.65,1],
	[180.92,0],[181.19,1],[181.46,2],[181.73,3],
	[182.00,0],[182.27,2],[182.54,1],[182.81,3],
	[183.08,1],[183.35,0],[183.62,3],[183.89,2],
	[184.16,0],[184.43,1],[184.70,2],[184.97,3],
	[185.24,2],[185.51,0],[185.78,3],[186.05,1],
	[186.32,0],[186.59,1],[186.86,2],[187.13,3],
	[187.40,0],[187.67,2],[187.94,1],[188.21,3],
	[188.48,1],[188.75,0],[189.02,3],[189.29,2],
	[189.56,0],[189.83,1],[190.10,2],[190.37,3],
	[190.64,2],[190.91,0],[191.18,3],[191.45,1],
	[191.72,0],[191.99,1],[192.26,2],[192.53,3],
]

@onready var label_score = $UI/LabelScore
@onready var label_combo = $UI/LabelCombo
@onready var label_timer = $UI/LabelTimer
@onready var label_countdown = $UI/LabelCountdown
@onready var notes_node = $Notes
@onready var audio_player = $AudioPlayer
@onready var buttons = [$HitZone/BtnD, $HitZone/BtnF, $HitZone/BtnJ, $HitZone/BtnK]

func _ready():
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

func show_instructions_popup() -> void:
	var popup := InstructionsPopup.new()
	popup.popup_title = "INSTRUCTIONS"
	popup.popup_subtitle = "T'NALAK RHYTHM: Tugtugin ang Habi"
	popup.start_hint = "Pindutin ang SPACE para magsimula"
	popup.steps = [
		{"icon": "rhythm_keys", "caption": "PINDUTIN ANG D F J K KAPAG UMABOT SA LINE ANG NOTE"},
		{"icon": "target", "caption": "MAKAMIT ANG TARGET NA SCORE AT COMBO"}
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
	song_time += delta
	spawn_notes()
	move_notes(delta)
	update_ui()
	if not audio_player.playing and game_started:
		end_game()

func spawn_notes():
	while chart_index < chart.size():
		var note_time = chart[chart_index][0]
		var lane = chart[chart_index][1]
		if song_time >= note_time - spawn_ahead:
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

func move_notes(delta):
	for note in notes_node.get_children():
		note.position.y += note_speed * delta
		if note.position.y > 300:
			note.queue_free()
			miss()

func _input(event):
	if not game_started or game_ended:
		return
	if event is InputEventKey and not event.echo:
		for i in range(4):
			if event.keycode == lane_keys[i]:
				if event.pressed:
					buttons[i].texture_normal = btn_pressed[i]
					check_hit(i)
				else:
					buttons[i].texture_normal = btn_idle[i]

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
	var time_left = max(0, 193.0 - song_time)
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
