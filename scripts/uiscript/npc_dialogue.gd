extends CharacterBody2D
# NPC script: interact prompt, dialogue ("Learn about the Culture"),
# ang 5-item quiz (Cultural Assessment), Journal unlock, at
# Mini Game na naka-LOCKED hanggang 5/5. May 2-minute cooldown kapag nag-fail.
# State flow: IDLE -> MENU -> DIALOGUE or QUIZ -> balik IDLE

# ---------- SETTINGS (editable sa Inspector) ----------

@export var npc_name: String = ""
@export var dialogue_file: String = ""      # Path ng dialogue JSON ("Learn about the Culture")
@export var minigame_scene: String = ""
@export var has_minigame: bool = false
@export var marker_id: String = ""

@export_enum("south_cotabato", "sarangani", "sultan_kudarat", "cotabato_province") var province_id: String = "south_cotabato"

@export var return_scene_path: String = ""
@export var return_spawn_pos: Vector2 = Vector2.ZERO

@export var quiz_cooldown_seconds: float = 120.0  # 2 minutos kapag nag-fail

# ---------- VARIABLES ----------

var dialogue: Array = []
var player_nearby = false
var dialogue_index = 0
var state = "IDLE"  # IDLE, MENU, DIALOGUE, QUIZ

var current_quiz_index = 0
var score = 0

@onready var area = $Area2D
@onready var label = $InteractLabel


# ---------- SETUP ----------

func _ready():
	add_to_group("minimap_npc")
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	label.visible = false
	load_dialogue()

func get_dialogue_box():
	return get_tree().get_first_node_in_group("dialogue_box")

func load_dialogue():
	if dialogue_file == "":
		return
	var file = FileAccess.open(dialogue_file, FileAccess.READ)
	if file == null:
		return
	dialogue = JSON.parse_string(file.get_as_text())


# ---------- PLAYER PROXIMITY ----------

func _on_body_entered(body):
	if body.name == "James":
		player_nearby = true
		label.visible = true

func _on_body_exited(body):
	if body.name == "James":
		player_nearby = false
		label.visible = false
		close_dialogue()


# ---------- INPUT ----------

func _input(event):
	if not player_nearby:
		return

	if event.is_action_pressed("interact") and state == "IDLE":
		start_menu()
		get_viewport().set_input_as_handled()
		return

	if state == "MENU" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			# [1] Learn about the Culture — quick study dialogue
			state = "DIALOGUE"
			dialogue_index = 0
			show_next_dialogue_line()
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_2:
			# [2] Answer 5 Questions — ang Cultural Assessment
			if Global.is_npc_completed(npc_name):
				show_toast("Na-unlock mo na ang malalim na kasaysayan rito kay " + npc_name + "!")
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

			var remaining = Global.get_quiz_cooldown_remaining(npc_name)
			if remaining > 0.0:
				show_toast("Maghintay ng " + str(int(ceil(remaining))) + "s bago muling subukan ang assessment.")
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

			state = "QUIZ"
			current_quiz_index = 0
			score = 0
			show_current_quiz_question()
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_3 and has_minigame:
			# [3] Play Mini Game — UNLOCKED lang kung 5/5 na
			if not Global.is_npc_completed(npc_name):
				show_toast("Kailangan mo munang makakuha ng perpektong 5/5 sa Cultural Assessment para ma-unlock ang Mini Game!")
				get_viewport().set_input_as_handled()
				return

			Global.return_scene = return_scene_path
			Global.return_spawn_pos = return_spawn_pos
			close_dialogue()
			LoadingScreen.change_scene(minigame_scene)
			get_viewport().set_input_as_handled()

	elif state == "DIALOGUE" and event.is_action_pressed("interact"):
		show_next_dialogue_line()
		get_viewport().set_input_as_handled()

	elif state == "QUIZ" and event is InputEventKey and event.pressed and not event.echo:
		var selected_answer = -1
		if event.keycode == KEY_A:
			selected_answer = 0
		elif event.keycode == KEY_B:
			selected_answer = 1
		elif event.keycode == KEY_C:
			selected_answer = 2

		if selected_answer != -1:
			check_answer(selected_answer)
			get_viewport().set_input_as_handled()


# ---------- MENU AND DIALOGUE ----------

func start_menu():
	state = "MENU"
	var box = get_dialogue_box()
	if box == null:
		return
	box.show_name(npc_name)

	var completed = Global.is_npc_completed(npc_name)
	var quiz_status = ""
	if completed:
		quiz_status = " (Natapos na - 5/5)"
	else:
		var remaining = Global.get_quiz_cooldown_remaining(npc_name)
		if remaining > 0.0:
			quiz_status = " (Maghintay: " + str(int(ceil(remaining))) + "s)"

	var text = "Mabuting araw, Archivist James. Maligayang pagdating sa ating lupain.\n\n"
	text += "[1] Pag-aralan ang Kultura\n"
	text += "[2] Sagutin ang limang tanong" + quiz_status

	if has_minigame:
		if completed:
			text += "\n[3] Maglaro ng Mini Game — UNLOCKED"
		else:
			text += "\n[3] Mini Game — LOCKED (kailangan ng 5/5 na sagot)"

	box.show_text(text)

func show_next_dialogue_line():
	var box = get_dialogue_box()
	if box == null:
		return

	if dialogue_index < dialogue.size():
		var line = dialogue[dialogue_index]
		box.show_name(line["name"])
		box.show_text(line["text"])
		dialogue_index += 1
	else:
		state = "MENU"
		start_menu()


# ---------- QUIZ ----------

func show_current_quiz_question():
	var box = get_dialogue_box()
	if box == null:
		return

	var q = get_quiz_for_npc()[current_quiz_index]
	box.show_name(npc_name)

	var progress_indicator = "[ Tanong " + str(current_quiz_index + 1) + "/5 ]\n\n"
	var text = progress_indicator + q["question"] + "\n\n" + q["options"][0] + "\n" + q["options"][1] + "\n" + q["options"][2]
	box.show_text(text)

func get_quiz_for_npc() -> Array:
	# ---------- AYU (Sarangani) ----------
	if npc_name == "Ayu":
		return [
			{
				"question": "1. Saan nahukay ang mga Maitum anthropomorphic burial jars noong 1991?",
				"options": ["[A] General Santos City", "[B] Ayub Cave, Maitum", "[C] Lake Sebu"],
				"correct": 1
			},
			{
				"question": "2. Ano ang pangunahing gamit ng mga Maitum jars sa sinaunang panahon?",
				"options": ["[A] Lalagyan ng bigas", "[B] Imbakan ng tubig", "[C] Sekondaryang libingan ng mga yumao"],
				"correct": 2
			},
			{
				"question": "3. Ano ang ibig sabihin ng 'anthropomorphic' sa mga banga?",
				"options": ["[A] May hugis at mukha ng tao", "[B] May disenyo ng isda", "[C] Gawa sa bakal"],
				"correct": 0
			},
			{
				"question": "4. Bakit mahalaga ang mga bangkang pangisda sa Sarangani?",
				"options": ["[A] Dahil ginagamit ito sa paghahabi ng T'nalak", "[B] Dahil ito ang simbolo ng Isulan", "[C] Dahil ito ang pangunahing hanapbuhay ng mga coastal community"],
				"correct": 2
			},
			{
				"question": "5. Ano ang tamang paglalarawan sa 'I Love Sarangani' landmark?",
				"options": ["[A] Modernong landmark ng local pride at turismo", "[B] Sinaunang artifact mula sa Ayub Cave", "[C] Sinaunang libingan"],
				"correct": 0
			}
		]

	# ---------- USTADZ AMEER (Sultan Kudarat) ----------
	elif npc_name == "Ustadz Ameer" or npc_name == "Ameer":
		return [
			{
				"question": "1. Ano ang kabisera ng Sultan Kudarat?",
				"options": ["[A] Tacurong", "[B] Koronadal", "[C] Isulan"],
				"correct": 2
			},
			{
				"question": "2. Kanino ipinangalan ang probinsya ng Sultan Kudarat?",
				"options": ["[A] Kay General Paulino Santos", "[B] Kay Sultan Muhammad Dipatuan Kudarat ng Maguindanao", "[C] Kay Lang Dulay"],
				"correct": 1
			},
			{
				"question": "3. Anong disenyo ang makikita sa Isulan Capitol?",
				"options": ["[A] Moorish/Arabic-inspired na may gintong dome", "[B] Gothic na may matataas na tore", "[C] Modernong glass building"],
				"correct": 0
			},
			{
				"question": "4. Saan matatagpuan ang Pangadilan Falls?",
				"options": ["[A] Isulan", "[B] Lake Sebu", "[C] Columbio"],
				"correct": 2
			},
			{
				"question": "5. Ano ang pangunahing papel ni Sultan Muhammad Dipatuan Kudarat sa kasaysayan ng Maguindanao?",
				"options": ["[A] Siya ang nagtatag ng General Santos City", "[B] Siya ay isang lider ng Sultanato ng Maguindanao", "[C] Siya ay isang manghahabi ng T'nalak"],
				"correct": 1
			}
		]

	# ---------- APO SANDAWA (Cotabato) ----------
	elif npc_name == "Apo Sandawa" or npc_name == "Sandawa":
		return [
			{
				"question": "1. Ano ang katangian ng Bundok Apo sa buong Pilipinas?",
				"options": ["[A] Pinakamahabang ilog", "[B] Pinakamataas na bundok", "[C] Pinakamalaking lawa"],
				"correct": 1
			},
			{
				"question": "2. Ano ang papel ng Bundok Apo sa mga katutubo?",
				"options": ["[A] Pangunahing lugar ng pangingisda", "[B] Modernong commercial center", "[C] Sagradong lugar na konektado sa kanilang kultura at paniniwala"],
				"correct": 2
			},
			{
				"question": "3. Saan matatagpuan ang Tamontaka Church?",
				"options": ["[A] Cotabato City", "[B] Isulan", "[C] Maitum"],
				"correct": 0
			},
			{
				"question": "4. Saan matatagpuan ang Asik-Asik Falls?",
				"options": ["[A] Columbio, Sultan Kudarat", "[B] Alamada, Cotabato", "[C] Lake Sebu"],
				"correct": 1
			},
			{
				"question": "5. Ano ang pangunahing katangian ng Asik-Asik Falls?",
				"options": ["[A] May gintong dome", "[B] May mga anthropomorphic jars", "[C] May tubig na bumabagsak mula sa pader ng bangin na natatakpan ng halaman"],
				"correct": 2
			}
		]

	# ---------- BAI LINAY (South Cotabato) ----------
	else:
		return [
			{
				"question": "1. Anong materyal ang ginagamit ng mga T'boli sa paghahabi ng T'nalak?",
				"options": ["[A] Koton", "[B] Seda", "[C] Abaka"],
				"correct": 2
			},
			{
				"question": "2. Sino ang pinaniniwalaang espiritu ng abaka na nagbibigay ng mga disenyo sa mga Dreamweaver?",
				"options": ["[A] Apo Sandawa", "[B] Fu Dalu", "[C] Sultan Kudarat"],
				"correct": 1
			},
			{
				"question": "3. Anong award ang natanggap ni Lang Dulay noong 1998?",
				"options": ["[A] Gawad sa Manlilikha ng Bayan", "[B] National Artist Award", "[C] Ramon Magsaysay Award"],
				"correct": 0
			},
			{
				"question": "4. Anong palayaw ang kilala sa General Santos City?",
				"options": ["[A] Sugar Capital of the Philippines", "[B] Tuna Capital of the Philippines", "[C] Rice Granary of the Philippines"],
				"correct": 1
			},
			{
				"question": "5. Sino ang nanguna sa unang malaking pangkat ng mga settler na dumating sa Sarangani Bay noong 1939?",
				"options": ["[A] Sultan Kudarat", "[B] Lang Dulay", "[C] General Paulino Santos"],
				"correct": 2
			}
		]

func check_answer(answer_idx: int):
	var q = get_quiz_for_npc()[current_quiz_index]
	if answer_idx == q["correct"]:
		score += 1

	current_quiz_index += 1

	if current_quiz_index < get_quiz_for_npc().size():
		show_current_quiz_question()
	else:
		if score == 5:
			Global.mark_npc_completed(npc_name)
			var journal_title = npc_name + " - Historical Archive"
			var journal_desc = get_deep_journal_content(npc_name)
			Global.add_journal_entry(province_id, journal_title, journal_desc)

			var unlock_msg = "Perfect 5/5! Na-unlock ang Journal entry kay " + npc_name + "!"
			if has_minigame:
				unlock_msg += " Naka-unlock na rin ang Mini Game."
			show_toast(unlock_msg)
		else:
			Global.set_quiz_cooldown(npc_name, quiz_cooldown_seconds)
			show_toast("Score mo ay " + str(score) + "/5. Kailangan ng perpektong 5/5! Subukan ulit pagkalipas ng 2 minuto.")

		close_dialogue()


# ---------- JOURNAL REWARD ----------

func get_deep_journal_content(npc_display_name: String) -> String:
	if npc_display_name == "Ayu":
		return "Ang Sarangani ay kilala sa mga Maitum anthropomorphic burial jars na natuklasan sa Ayub Cave noong 1991. Ang mga banga na ito ay may hugis at mukha ng tao at ginamit bilang sekondaryang libingan ng mga yumao. Bukod dito, mahalaga rin ang mga bangkang pangisda sa hanapbuhay ng mga coastal community sa lalawigan. Ang 'I Love Sarangani' landmark naman ay isang modernong landmark na kumakatawan sa local pride at turismo ng probinsya."

	elif npc_display_name == "Ustadz Ameer" or npc_display_name == "Ameer":
		return "Ang Sultan Kudarat ay isang probinsya na ipinangalan kay Sultan Muhammad Dipatuan Kudarat, pinuno ng Sultanato ng Maguindanao noong ika-17 siglo na lumaban sa pananakop ng mga Kastila. Ang Isulan ang kabisera nito, at ang Isulan Capitol ay may Moorish/Arabic-inspired na disenyo na may gintong dome. Matatagpuan sa Columbio, isa sa mga orihinal na bayan ng probinsya, ang Pangadilan Falls."

	elif npc_display_name == "Apo Sandawa" or npc_display_name == "Sandawa":
		return "Ang Cotabato ay mayaman sa natural at cultural na mga yaman. Ang Bundok Apo, ang pinakamataas na bundok sa Pilipinas, ay itinuturing na sagradong lugar na konektado sa kultura at paniniwala ng mga katutubo. Matatagpuan sa Cotabato City ang Tamontaka Church, habang ang Asik-Asik Falls sa Alamada ay kilala sa tubig na bumabagsak mula sa pader ng bangin na natatakpan ng halaman."

	else:
		return "Ang South Cotabato ay kilala sa T'nalak weaving tradition ng mga T'boli sa Lake Sebu. Ang T'nalak ay hinahabi mula sa abaka, at ang mga disenyo nito ay pinaniniwalaang ibinubunyag sa pamamagitan ng panaginip ni Fu Dalu, ang espiritu ng abaka. Dahil dito, tinatawag na Dreamweaver ang mga manghahabi. Si Lang Dulay ay isa sa pinakakilalang Dreamweaver at ginawaran ng Gawad sa Manlilikha ng Bayan noong 1998. Ang General Santos City naman ay kilala bilang 'Tuna Capital of the Philippines,' at si General Paulino Santos ang nanguna sa unang malaking pangkat ng mga settler na dumating sa Sarangani Bay noong 1939."


# ---------- HELPERS ----------

func show_toast(msg: String):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_toast"):
		hud._show_toast(msg)

func close_dialogue():
	state = "IDLE"
	dialogue_index = 0
	current_quiz_index = 0
	var box = get_dialogue_box()
	if box:
		box.hide_box()
