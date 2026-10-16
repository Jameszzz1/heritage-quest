
extends CharacterBody2D

# NPC SYSTEM
# Cultural NPC:
# - Culture dialogue
# - 5-question quiz
# - Journal reward
# - Optional minigame
# - 2-minute cooldown after failing
#
# Guide NPC:
# - Guide/information dialogue only
# - No quiz, Journal reward, or cultural progress tracking
#
# STATE FLOW:
# IDLE -> MENU -> DIALOGUE or QUIZ -> IDLE/MENU


# ---------- SETTINGS ----------

@export var npc_name: String = ""
@export var dialogue_file: String = ""
@export var minigame_scene: String = ""
@export var has_minigame: bool = false
@export var marker_id: String = ""

@export_enum("Cultural NPC", "Guide NPC")
var npc_type: String = "Cultural NPC"

@export_enum(
	"south_cotabato",
	"sarangani",
	"sultan_kudarat",
	"cotabato_province"
)
var province_id: String = "south_cotabato"

@export var return_scene_path: String = ""
@export var return_spawn_pos: Vector2 = Vector2.ZERO

@export var quiz_cooldown_seconds: float = 120.0


# ---------- COLORS ----------

const COLOR_GREEN = "#1a9c3a"
const COLOR_RED = "#d62828"


# ---------- VARIABLES ----------

var dialogue: Array = []
var player_nearby: bool = false
var dialogue_index: int = 0
var state: String = "IDLE"

var current_quiz_index: int = 0
var score: int = 0

@onready var area: Area2D = $Area2D
@onready var label: CanvasItem = $InteractLabel


# ---------- SETUP ----------

func _ready() -> void:
	add_to_group("minimap_npc")

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	label.visible = false
	load_dialogue()


func get_dialogue_box():
	return get_tree().get_first_node_in_group("dialogue_box")


func load_dialogue() -> void:
	if dialogue_file.is_empty():
		push_warning("No dialogue file assigned to NPC: " + npc_name)
		return

	if not FileAccess.file_exists(dialogue_file):
		push_warning("Dialogue file not found: " + dialogue_file)
		return

	var file = FileAccess.open(dialogue_file, FileAccess.READ)

	if file == null:
		push_warning("Unable to open dialogue file: " + dialogue_file)
		return

	var parsed = JSON.parse_string(file.get_as_text())

	if parsed is Array:
		dialogue = parsed
	else:
		push_warning("Dialogue JSON must contain an Array: " + dialogue_file)


# ---------- PROVINCE ----------

func get_province() -> String:
	if npc_name == "Ayu":
		return "sarangani"
	elif npc_name == "Ustadz Ameer" or npc_name == "Ameer":
		return "sultan_kudarat"
	elif npc_name == "Apo Sandawa" or npc_name == "Sandawa":
		return "cotabato_province"

	return "south_cotabato"


# ---------- CULTURE TRACKING ----------

func is_culture_read() -> bool:
	if Global.is_npc_completed(npc_name):
		return true

	return Global.is_culture_read(npc_name)


func mark_culture_read() -> void:
	Global.mark_culture_read(npc_name)


func colored(text: String, color: String) -> String:
	return "[color=" + color + "]" + text + "[/color]"


func enable_bbcode(box) -> void:
	for n in box.find_children("*", "RichTextLabel", true, false):
		n.bbcode_enabled = true


# ---------- PLAYER PROXIMITY ----------

func _on_body_entered(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = true
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = false
		label.visible = false
		close_dialogue()


# ---------- INPUT ----------

func _input(event: InputEvent) -> void:
	if not player_nearby:
		return

	# Open NPC interaction menu.
	if event.is_action_pressed("interact") and state == "IDLE":
		start_menu()
		get_viewport().set_input_as_handled()
		return

	# Menu controls.
	if state == "MENU" and event is InputEventKey:
		if not event.pressed or event.echo:
			return

		# Option 1: Dialogue/information.
		if event.keycode == KEY_1:
			state = "DIALOGUE"
			dialogue_index = 0
			show_next_dialogue_line()

			get_viewport().set_input_as_handled()
			return

		# Guide NPCs only have the dialogue option.
		if npc_type == "Guide NPC":
			return

		# Option 2: Cultural Assessment.
		if event.keycode == KEY_2:
			if Global.is_npc_completed(npc_name):
				show_toast(
					"Na-unlock mo na ang malalim na kasaysayan rito kay "
					+ npc_name + "!"
				)
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

			if not is_culture_read():
				show_toast(
					"Basahin muna ang buong [1] Pag-aralan ang Kultura "
					+ "bago sumagot ng mga tanong!"
				)
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

			var remaining = Global.get_quiz_cooldown_remaining(npc_name)

			if remaining > 0.0:
				show_toast(
					"Maghintay ng "
					+ str(int(ceil(remaining)))
					+ "s bago muling subukan ang assessment."
				)
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

			state = "QUIZ"
			current_quiz_index = 0
			score = 0
			show_current_quiz_question()

			get_viewport().set_input_as_handled()
			return


	# OPTION 3: MINI GAME
		if event.keycode == KEY_3:
			print("========== MINIGAME DEBUG ==========")
			print("KEY 3 PRESSED")
			print("NPC: ", npc_name)
			print("NPC type: ", npc_type)
			print("Has minigame: ", has_minigame)
			print("Minigame scene: ", minigame_scene)
			print("Culture read: ", Global.is_culture_read(npc_name))
			print("NPC completed: ", Global.is_npc_completed(npc_name))

		# Guide NPCs do not have minigames
		if npc_type == "Guide NPC":
			show_toast("Walang Mini Game ang NPC na ito.")
			close_dialogue()
			get_viewport().set_input_as_handled()
			return

		# Check whether this NPC has a minigame
		if not has_minigame:
			show_toast("Walang Mini Game ang NPC na ito.")
			close_dialogue()
			get_viewport().set_input_as_handled()
			return

		# Require the player to read the cultural dialogue first
		if not Global.is_culture_read(npc_name):
			show_toast("Basahin muna ang buong [1] Pag-aralan ang Kultura bago maglaro ng Mini Game!")
			close_dialogue()
			get_viewport().set_input_as_handled()
			return

		# Require a perfect Cultural Assessment score
		if not Global.is_npc_completed(npc_name):
			show_toast("Kumpletuhin muna ang Cultural Assessment!")
			close_dialogue()
			get_viewport().set_input_as_handled()
			return

		# Validate the minigame scene path
		if minigame_scene.is_empty() or not ResourceLoader.exists(minigame_scene):
			show_toast("Hindi available ang Mini Game.")
			close_dialogue()
			get_viewport().set_input_as_handled()
			return

		# All conditions passed: open the minigame
		Global.return_scene = get_tree().current_scene.scene_file_path
		Global.return_spawn_pos = global_position

		close_dialogue()
		get_viewport().set_input_as_handled()
		LoadingScreen.change_scene(minigame_scene)
		return


	# Advance dialogue.
	elif state == "DIALOGUE" and event.is_action_pressed("interact"):
		show_next_dialogue_line()
		get_viewport().set_input_as_handled()

	# Quiz answer controls.
	elif state == "QUIZ" and event is InputEventKey:
		if not event.pressed or event.echo:
			return

		var selected_answer: int = -1

		if event.keycode == KEY_A:
			selected_answer = 0
		elif event.keycode == KEY_B:
			selected_answer = 1
		elif event.keycode == KEY_C:
			selected_answer = 2

		if selected_answer != -1:
			check_answer(selected_answer)
			get_viewport().set_input_as_handled()


# ---------- MENU ----------

func start_menu() -> void:
	state = "MENU"

	var box = get_dialogue_box()

	if box == null:
		state = "IDLE"
		return

	enable_bbcode(box)
	box.show_name(npc_name)

	# Guide NPC menu.
	if npc_type == "Guide NPC":
		var guide_text = "Mabuting araw, Archivist James!\n\n"
		guide_text += colored("[1] Humingi ng Gabay", COLOR_GREEN)
		box.show_text(guide_text)
		return

	# Cultural NPC menu.
	var completed = Global.is_npc_completed(npc_name)
	var culture_read = is_culture_read()

	var text = "Mabuting araw, Archivist James. "
	text += "Maligayang pagdating sa ating lupain.\n\n"

	# Option 1 is always green.
	text += colored("[1] Pag-aralan ang Kultura", COLOR_GREEN) + "\n"

	# Option 2 depends on cultural progress and cooldown.
	if completed:
		text += colored("[2] Sagutin ang limang tanong", COLOR_GREEN)

	elif not culture_read:
		text += colored("[2] Sagutin ang limang tanong", COLOR_RED)

	else:
		var remaining = Global.get_quiz_cooldown_remaining(npc_name)

		if remaining > 0.0:
			text += colored(
				"[2] Sagutin ang limang tanong (Maghintay: "
				+ str(int(ceil(remaining))) + "s)",
				COLOR_RED
			)
		else:
			text += colored("[2] Sagutin ang limang tanong", COLOR_GREEN)

	# Option 3 is only displayed if the NPC has a minigame.
	if has_minigame:
		if completed:
			text += "\n" + colored(
				"[3] Maglaro ng Mini Game",
				COLOR_GREEN
			)
		else:
			text += "\n" + colored("[3] Mini Game", COLOR_RED)

	box.show_text(text)


# ---------- DIALOGUE ----------

func show_next_dialogue_line() -> void:
	var box = get_dialogue_box()

	if box == null:
		close_dialogue()
		return

	if dialogue_index < dialogue.size():
		var line = dialogue[dialogue_index]

		if not line is Dictionary:
			dialogue_index += 1
			show_next_dialogue_line()
			return

		box.show_name(str(line.get("name", npc_name)))
		box.show_text(str(line.get("text", "")))

		dialogue_index += 1

	else:
		# Guide NPC: finish without cultural progress tracking.
		if npc_type == "Guide NPC":
			close_dialogue()
			return

		# Cultural NPC: mark culture as read.
		var first_time = not is_culture_read()

		mark_culture_read()

		state = "MENU"
		start_menu()

		if first_time:
			show_toast(
				"Nabasa mo na ang lahat! Pwede mo nang "
				+ "sagutin ang limang tanong."
			)


# ---------- QUIZ ----------

func show_current_quiz_question() -> void:
	var box = get_dialogue_box()

	if box == null:
		close_dialogue()
		return

	var questions = get_quiz_for_npc()

	if current_quiz_index >= questions.size():
		close_dialogue()
		return

	var q = questions[current_quiz_index]

	box.show_name(npc_name)

	var progress = "[ Tanong " + str(current_quiz_index + 1) + "/5 ]\n\n"
	var text = progress + q["question"] + "\n\n"
	text += q["options"][0] + "\n"
	text += q["options"][1] + "\n"
	text += q["options"][2]

	box.show_text(text)


func get_quiz_for_npc() -> Array:
	# AYU - SARANGANI
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
				"options": ["[A] Ginagamit sa paghahabi ng T'nalak", "[B] Simbolo ng Isulan", "[C] Pangunahing hanapbuhay ng mga coastal community"],
				"correct": 2
			},
			{
				"question": "5. Ano ang tamang paglalarawan sa 'I Love Sarangani' landmark?",
				"options": ["[A] Modernong landmark ng local pride at turismo", "[B] Sinaunang artifact mula sa Ayub Cave", "[C] Sinaunang libingan"],
				"correct": 0
			}
		]

	# USTADZ AMEER - SULTAN KUDARAT
	elif npc_name == "Ustadz Ameer" or npc_name == "Ameer":
		return [
			{
				"question": "1. Ano ang kabisera ng Sultan Kudarat?",
				"options": ["[A] Tacurong", "[B] Koronadal", "[C] Isulan"],
				"correct": 2
			},
			{
				"question": "2. Kanino ipinangalan ang probinsya ng Sultan Kudarat?",
				"options": ["[A] General Paulino Santos", "[B] Sultan Muhammad Dipatuan Kudarat ng Maguindanao", "[C] Lang Dulay"],
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
				"options": ["[A] Nagtatag ng General Santos City", "[B] Lider ng Sultanato ng Maguindanao", "[C] Manghahabi ng T'nalak"],
				"correct": 1
			}
		]

	# APO SANDAWA - COTABATO
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
				"options": ["[A] May gintong dome", "[B] May anthropomorphic jars", "[C] Tubig na bumabagsak mula sa halamang pader ng bangin"],
				"correct": 2
			}
		]

	# BAI LINAY - SOUTH COTABATO
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


func check_answer(answer_idx: int) -> void:
	var questions = get_quiz_for_npc()

	if current_quiz_index >= questions.size():
		close_dialogue()
		return

	var q = questions[current_quiz_index]

	if answer_idx == int(q["correct"]):
		score += 1

	current_quiz_index += 1

	if current_quiz_index < questions.size():
		show_current_quiz_question()
		return

	# Quiz finished.
	if score == 5:
		Global.mark_npc_completed(npc_name)

		var journal_title = npc_name + " - Historical Archive"
		var journal_desc = get_deep_journal_content(npc_name)

		Global.add_journal_entry(
			get_province(),
			journal_title,
			journal_desc
		)

		var unlock_msg = "Perfect 5/5! Na-unlock ang Journal entry kay "
		unlock_msg += npc_name + "!"

		if has_minigame:
			unlock_msg += " Nabuksan na rin ang Mini Game."

		show_toast(unlock_msg)

	else:
		Global.set_quiz_cooldown(npc_name, quiz_cooldown_seconds)

		show_toast(
			"Score mo ay " + str(score)
			+ "/5. Kailangan ng perpektong 5/5! "
			+ "Subukan ulit pagkalipas ng 2 minuto."
		)

	close_dialogue()


# ---------- JOURNAL REWARD ----------

func get_deep_journal_content(npc_display_name: String) -> String:
	if npc_display_name == "Ayu":
		return "Ang Sarangani ay kilala sa mga Maitum anthropomorphic burial jars na natuklasan sa Ayub Cave noong 1991. Ang mga banga na ito ay may hugis at mukha ng tao at ginamit bilang sekondaryang libingan ng mga yumao. Mahalaga rin ang mga bangkang pangisda sa hanapbuhay ng mga coastal community. Ang 'I Love Sarangani' landmark ay kumakatawan sa local pride at turismo ng probinsya."

	elif npc_display_name == "Ustadz Ameer" or npc_display_name == "Ameer":
		return "Ang Sultan Kudarat ay ipinangalan kay Sultan Muhammad Dipatuan Kudarat, pinuno ng Sultanato ng Maguindanao noong ika-17 siglo. Ang Isulan ang kabisera nito, at ang Isulan Capitol ay may Moorish/Arabic-inspired na disenyo na may gintong dome. Matatagpuan sa Columbio ang Pangadilan Falls."

	elif npc_display_name == "Apo Sandawa" or npc_display_name == "Sandawa":
		return "Ang Cotabato ay mayaman sa natural at cultural na mga yaman. Ang Bundok Apo, ang pinakamataas na bundok sa Pilipinas, ay itinuturing na sagradong lugar na konektado sa kultura at paniniwala ng mga katutubo. Matatagpuan sa Cotabato City ang Tamontaka Church, habang ang Asik-Asik Falls sa Alamada ay kilala sa tubig na bumabagsak mula sa pader ng bangin na natatakpan ng halaman."

	return "Ang South Cotabato ay kilala sa T'nalak weaving tradition ng mga T'boli sa Lake Sebu. Ang T'nalak ay hinahabi mula sa abaka, at ang mga disenyo nito ay pinaniniwalaang ibinubunyag sa pamamagitan ng panaginip ni Fu Dalu, ang espiritu ng abaka. Si Lang Dulay ay isa sa pinakakilalang Dreamweaver at ginawaran ng Gawad sa Manlilikha ng Bayan noong 1998. Ang General Santos City ay kilala bilang 'Tuna Capital of the Philippines,' at si General Paulino Santos ang nanguna sa unang malaking pangkat ng mga settler na dumating sa Sarangani Bay noong 1939."


# ---------- HELPERS ----------

func show_toast(msg: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")

	if hud == null:
		print("TOAST ERROR: No node found in group 'hud'.")
		return

	if not hud.has_method("_show_toast"):
		print("TOAST ERROR: HUD has no _show_toast() method.")
		return

	print("TOAST MESSAGE: ", msg)
	hud._show_toast(msg)


func close_dialogue() -> void:
	state = "IDLE"
	dialogue_index = 0
	current_quiz_index = 0

	var box = get_dialogue_box()

	if box:
		box.hide_box()
