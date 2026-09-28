extends CharacterBody2D
# NPC script: handles the interact prompt, the dialogue, the 5-item quiz
# (Cultural Assessment), and the journal unlock reward.
# State flow: IDLE -> MENU -> DIALOGUE or QUIZ -> back to IDLE

# ---------- SETTINGS (editable in the Inspector) ----------

@export var npc_name: String = ""
@export var dialogue_file: String = ""      # Path to the JSON file with this NPC's dialogue
@export var minigame_scene: String = ""
@export var has_minigame: bool = false
@export var marker_id: String = ""

# Which province this NPC belongs to (used to file the journal entry under the right province)
@export_enum("south_cotabato", "sarangani", "sultan_kudarat", "cotabato_province") var province_id: String = "south_cotabato"

@export var return_scene_path: String = ""
@export var return_spawn_pos: Vector2 = Vector2.ZERO

# ---------- VARIABLES ----------

var dialogue: Array = []                    # Dialogue lines loaded from the JSON file
var player_nearby = false                   # True while the player is inside the NPC's Area2D
var dialogue_index = 0                      # Which dialogue line is currently shown
var state = "IDLE"                          # IDLE, MENU, DIALOGUE, QUIZ

var current_quiz_index = 0                  # Which quiz question is currently shown
var score = 0                               # Number of correct answers so far

@onready var area = $Area2D
@onready var label = $InteractLabel


# ---------- SETUP ----------

func _ready():
	add_to_group("minimap_npc")  # So the minimap can find and show this NPC
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	label.visible = false
	load_dialogue()

# Finds the dialogue box in the HUD
func get_dialogue_box():
	return get_tree().get_first_node_in_group("dialogue_box")

# Loads the dialogue lines from the JSON file (if one is set)
func load_dialogue():
	if dialogue_file == "":
		return
	var file = FileAccess.open(dialogue_file, FileAccess.READ)
	if file == null:
		return
	dialogue = JSON.parse_string(file.get_as_text())


# ---------- PLAYER PROXIMITY ----------

# Player entered the NPC's area: show the interact label
func _on_body_entered(body):
	if body.name == "James":
		player_nearby = true
		label.visible = true

# Player left the NPC's area: hide the label and close any open dialogue
func _on_body_exited(body):
	if body.name == "James":
		player_nearby = false
		label.visible = false
		close_dialogue()


# ---------- INPUT ----------

func _input(event):
	# Ignore all input unless the player is close to the NPC
	if not player_nearby:
		return

	# Interact key while idle: open the main menu
	if event.is_action_pressed("interact") and state == "IDLE":
		start_menu()
		get_viewport().set_input_as_handled()
		return

	# MENU state: choose an option with the number keys
	if state == "MENU" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			# Option 1: listen to the story from the beginning
			state = "DIALOGUE"
			dialogue_index = 0
			show_next_dialogue_line()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			# Option 2: take the quiz (skipped if this NPC's quiz was already completed)
			if Global.is_npc_completed(npc_name):
				show_toast("Na-unlock mo na ang malalim na kasaysayan rito kay " + npc_name + "!")
				close_dialogue()
				return
			state = "QUIZ"
			current_quiz_index = 0
			score = 0
			show_current_quiz_question()
			get_viewport().set_input_as_handled()

	# DIALOGUE state: the interact key advances to the next line
	elif state == "DIALOGUE" and event.is_action_pressed("interact"):
		show_next_dialogue_line()
		get_viewport().set_input_as_handled()

	# QUIZ state: A, B, or C keys select an answer
	elif state == "QUIZ" and event is InputEventKey and event.pressed and not event.echo:
		var selected_answer = -1  # -1 means no valid answer key was pressed
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

# Shows the main menu with the two options (story or quiz)
func start_menu():
	state = "MENU"
	var box = get_dialogue_box()
	if box == null:
		return
	box.show_name(npc_name)
	# The status text tells the player whether the quiz was already completed
	var status = " (Natapos na - 5/5)" if Global.is_npc_completed(npc_name) else " (May Pagsubok)"
	box.show_text("Mabuting araw, Archivist James. Maligayang pagdating sa ating lupain.\n\n[1] Pakinggan ang Kuwento at Kasaysayan ni " + npc_name + "\n[2] Sagutin ang 5-Item Cultural Assessment" + status)

# Shows the next dialogue line, or returns to the menu when the lines run out
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
		# No more lines: go back to the menu
		state = "MENU"
		box.show_name(npc_name)
		box.show_text("Naibahagi ko na ang kasaysayan ng aming lahi.\n\n[1] Ulitin ang Pagpapakilala\n[2] Sagutin ang 5-Item Cultural Assessment")


# ---------- QUIZ ----------

# Shows the current quiz question and its three answer choices
func show_current_quiz_question():
	var box = get_dialogue_box()
	if box == null:
		return

	var q = get_quiz_for_npc()[current_quiz_index]

	# Only the NPC's name is shown in the header
	box.show_name(npc_name)

	# The "1/5" progress indicator is placed at the start of the question text
	# so the header stays clean and easy to read
	var progress_indicator = "[ Tanong " + str(current_quiz_index + 1) + "/5 ]\n\n"
	var text = progress_indicator + q["question"] + "\n\n" + q["options"][0] + "\n" + q["options"][1] + "\n" + q["options"][2]
	box.show_text(text)

# Returns the 5 quiz questions for this NPC
# Each question has: "question" (text), "options" (3 choices), "correct" (index of the right answer: 0 = A, 1 = B, 2 = C)
func get_quiz_for_npc() -> Array:
	if npc_name == "Ayu":
		# Sarangani (Maitum Burial Jars)
		return [
			{
				"question": "1. Saan nahukay ang mga sikat na anthropomorphic pottery sa Sarangani noong 1991?",
				"options": ["[A] Ayub Cave", "[B] Lake Sebu", "[C] Mt. Apo"],
				"correct": 0
			},
			{
				"question": "2. Ano ang orihinal at malalim na gamit ng mga clay jars na ito sa sinaunang panahon?",
				"options": ["[A] Lalagyan ng inuming tubig", "[B] Sekondaryang libingan ng mga yumao", "[C] Imbakan ng mga ani"],
				"correct": 1
			},
			{
				"question": "3. Ano ang ibig sabihin ng terminong 'anthropomorphic' sa disenyo ng mga banga?",
				"options": ["[A] May hugis at mukha ng tao", "[B] May disenyo ng halaman", "[C] May palamuting ginto"],
				"correct": 0
			},
			{
				"question": "4. Sa anong partikular na saklaw ng panahon natuklasan ang edad ng mga banga na ito?",
				"options": ["[A] 1000 AD hanggang 1500 AD", "[B] 500 BC hanggang 500 AD", "[C] Panahon ng mga Kastila"],
				"correct": 1
			},
			{
				"question": "5. Bakit kinikilala bilang pambansang kayamanan ng bansa ang mga Maitum Jars?",
				"options": ["[A] Dahil sumasalamin ito sa mataas na sining at paniniwala sa Mindanao", "[B] Dahil gawa ito sa purong kristal", "[C] Dahil dito itinatago ang mga kayamanan"],
				"correct": 0
			}
		]
	elif npc_name == "Ustadz Ameer" or npc_name == "Ameer":
		# Sultan Kudarat (Isulan Capitol)
		return [
			{
				"question": "1. Kanino inialay at ipinangalan ang arkitektura ng Isulan Capitol?",
				"options": ["[A] Sultan Kudarat", "[B] Sultan Dipatuan", "[C] Sultan Maguindanao"],
				"correct": 0
			},
			{
				"question": "2. Anong estilong pandisenyo ang nangingibabaw sa gusali ng kapitolyo?",
				"options": ["[A] Modernong minimalist", "[B] Moorish design na may gintong dome at arabesque tiles", "[C] European Gothic design"],
				"correct": 1
			},
			{
				"question": "3. Kailan naghari si Sultan Muhammad Dipatuan Kudarat sa Sultanato ng Maguindanao?",
				"options": ["[A] 1625 hanggang 1671", "[B] 1800 hanggang 1850", "[C] 1500 hanggang 1550"],
				"correct": 0
			},
			{
				"question": "4. Anong espesyal na silid o pasilidad ang matatagpuan sa loob ng kapitolyo?",
				"options": ["[A] Isang pribadong silid-aklatan", "[B] Isang nakalaang Muslim prayer room", "[C] Isang museo ng digmaan"],
				"correct": 1
			},
			{
				"question": "5. Ano ang kinakatawan ng Isulan Capitol sa kasaysayan ng rehiyon?",
				"options": ["[A] Isang buhay na bantayog ng pamana ng Islam at kasarinlan", "[B] Isang sentro ng kalakalang panlabas", "[C] Isang lumang tanggulan ng militar"],
				"correct": 0
			}
		]
	elif npc_name == "Apo Sandawa" or npc_name == "Sandawa":
		# Cotabato Province (Mt. Apo)
		return [
			{
				"question": "1. Sino ang kinikilalang tagapagtanggol o espiritu na nananahan sa Mt. Apo?",
				"options": ["[A] Apo Sandawa", "[B] Bai Linay", "[C] Ustadz Ameer"],
				"correct": 0
			},
			{
				"question": "2. Anong mga katutubong komunidad ang nag-aangkin ng sagradong ugnayan sa bundok na ito?",
				"options": ["[A] Manobo, Bagobo, at Kalagan", "[B] T'boli at B'laan", "[C] Maranao at Tausug"],
				"correct": 0
			},
			{
				"question": "3. Bakit mahalaga ang pagpapasa ng mga tradisyong pasalita sa mga kabataan?",
				"options": ["[A] Para sa pangkulturang pagpapatuloy at pag-aabante ng identidad", "[B] Para sa libangan tuwing gabi", "[C] Para sa mga paligsahan sa pag-awit"],
				"correct": 0
			},
			{
				"question": "4. Ano ang layunin ng pagdodokumento ng mga kuwento sa modernong panahon?",
				"options": ["[A] Maibahagi ito sa mga digital-native na henerasyon", "[B] Magamit sa pagtatayo ng gusali", "[C] Para sa kalakalan"],
				"correct": 0
			},
			{
				"question": "5. Bukod sa kultura, ano ang pinoprotektahan sa pamamagitan ng pangangalaga sa Mt. Apo?",
				"options": ["[A] Ang ancestral land rights at environmental stewardship", "[B] Ang mga minahan ng ginto", "[C] Ang mga kalsada sa probinsya"],
				"correct": 0
			}
		]
	else:
		# Default: Bai Linay (South Cotabato, T'nalak weaving)
		return [
			{
				"question": "1. Paano natatanggap ng mga T'boli ang mga sagradong disenyo ng T'nalak cloth?",
				"options": ["[A] Ibinubunyag ito sa pamamagitan ng mga panaginip ni Fu Dalu", "[B] Ginuguhit ito mula sa imahinasyon", "[C] Kinokopya sa lumang aklat"],
				"correct": 0
			},
			{
				"question": "2. Sino ang tinutukoy na Diyosa o Espiritu ng Abaka na nagbibigay ng disenyo?",
				"options": ["[A] Sandawa", "[B] Fu Dalu", "[C] Ameer"],
				"correct": 1
			},
			{
				"question": "3. Ano ang tawag sa espesyal na prosesong ito ng paghahabi ng mga T'boli?",
				"options": ["[A] Dreamweaving", "[B] Loom crafting", "[C] Fiber weaving"],
				"correct": 0
			},
			{
				"question": "4. Saan matatagpuan ang sentrong komunidad ng sining na ito sa South Cotabato?",
				"options": ["[A] Mt. Apo", "[B] Lake Sebu", "[C] Isulan"],
				"correct": 1
			},
			{
				"question": "5. Ano ang silbi ng tela bukod sa pagiging kasuotan?",
				"options": ["[A] Isang buhay na arkibo na nagpapanatili ng kasaysayan ng tribo", "[B] Isang palamuti sa dingding", "[C] Pantakip sa mga kagamitan"],
				"correct": 0
			}
		]

# Checks the selected answer, then moves to the next question or ends the quiz
func check_answer(answer_idx: int):
	var q = get_quiz_for_npc()[current_quiz_index]
	if answer_idx == q["correct"]:
		score += 1

	current_quiz_index += 1

	if current_quiz_index < get_quiz_for_npc().size():
		# More questions left: show the next one
		show_current_quiz_question()
	else:
		# Quiz finished: only a perfect 5/5 unlocks the journal entry
		if score == 5:
			Global.mark_npc_completed(npc_name)
			var journal_title = npc_name + " - Historical Archive"
			var journal_desc = get_deep_journal_content(npc_name)
			Global.add_journal_entry(province_id, journal_title, journal_desc)

			show_toast("Perfect 5/5! Na-unlock ang malalim na Journal entry kay " + npc_name + "!")
		else:
			show_toast("Score mo ay " + str(score) + "/5. Kailangan ng perpektong 5/5 para ma-unlock ang Journal!")

		close_dialogue()


# ---------- JOURNAL REWARD ----------

# Returns the in-depth journal entry (5+ sentences) for this NPC, based on the
# team's RRL/RRS research. This is the reward for getting a perfect score.
func get_deep_journal_content(name: String) -> String:
	if name == "Ayu":
		return "Ang mga Maitum Anthropomorphic Burial Jars na natuklasan sa Ayub Cave sa Sarangani Province ay kinikilala bilang isa sa pinakamahalagang tuklas pangkasaysayan sa Timog-Silangang Asya. Ang mga banga na ito, na may petsang mula 500 BC hanggang 500 AD, ay may natatanging mukha at anyong tao na sumasagisag sa kaluluwa ng mga yumao. Nagsilbi silang sekondaryang libingan para sa mga sinaunang pamayanan sa rehiyon. Ipinapakita nito ang mataas na antas ng sining, kasanayan, at espirituwal na paniniwala ng ating mga ninuno. Kaya naman nararapat lamang silang ituring bilang mga pambansang kayamanan ng Pilipinas."
	elif name == "Ustadz Ameer" or name == "Ameer":
		return "Ang Isulan Capitol sa Sultan Kudarat ay isang maringal na sagisag ng pamana ng Islam, kultura, at kasarinlan sa Mindanao. Ang arkitektura nito ay nagtatampok ng mga elementong Moorish tulad ng ginintuang dome, mga arko, at arabesque tile patterns. Pinaparangalan nito ang pamana ni Sultan Muhammad Dipatuan Kudarat na naghari mula 1625 hanggang 1671 at matapang na lumaban sa mga mananakop na Kastila. Nagtataglay din ito ng nakalaang Muslim prayer room para sa pananampalataya. Ang gusaling ito ay nagsisilbing buhay na patunay ng makasaysayang ugat at dangal ng mga mamamayan."
	elif name == "Apo Sandawa" or name == "Sandawa":
		return "Sa Cotabato Province, ang Bundok Apo ay pinangangalagaan dahil sa malalim nitong ugnayan sa mga katutubong Manobo, Bagobo, at Kalagan. Nakasalig dito ang alamat ni Apo Sandawa bilang sagradong tagapagtanggol ng kalikasan at ancestral lands. Mahalagang panatilihin ang mga tradisyong pasalita upang maipasa ang kultura sa mga kabataang henerasyon. Ang aktibong pagdodokumento ng mga pamayanang ito ay nagpapatibay ng ating pangkulturang identidad. Sa huli, ang pangangalaga sa bundok na ito ay patunay ng ating malasakit sa kalikasan at karapatan ng mga katutubo."
	else:
		# Default: Bai Linay (South Cotabato)
		return "Ang tradisyon ng paghahabi ng T'nalak ng mga T'boli sa Lake Sebu, South Cotabato, ay isa sa pinakasagradong sining sa bansa. Ang telang ito ay mula sa abaca fiber kung saan ang mga disenyo ay hindi kathang-isip kundi ipinapakita sa panaginip ni Fu Dalu, ang Diyosa ng Abaka. Ang prosesong ito na tinatawag na dreamweaving ay gumagawa sa bawat telang natatangi at walang katulad. Bilang isang komunidad, ang sining na ito ay nagsisilbing buhay na arkibo ng kanilang kasaysayan. Ipinapasa nito ang identidad at mga kuwento ng mga ninuno mula sa isang henerasyon patungo sa susunod."


# ---------- HELPERS ----------

# Shows a toast message through the HUD (only if the HUD supports it)
func show_toast(msg: String):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_toast"):
		hud._show_toast(msg)

# Resets the NPC state and hides the dialogue box
func close_dialogue():
	state = "IDLE"
	dialogue_index = 0
	current_quiz_index = 0
	var box = get_dialogue_box()
	if box:
		box.hide_box()
