extends CharacterBody2D

@export var npc_name: String = ""
@export var dialogue_file: String = ""
@export var minigame_scene: String = ""
@export var has_minigame: bool = false

var dialogue: Array = []
var player_nearby = false
var dialogue_index = 0

var choice_mode = false
var dialogue_started = false

@onready var area = $Area2D
@onready var label = $InteractLabel


func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	label.visible = false

	load_dialogue()


# ----------------------------
# SAFE dialogue box getter
# ----------------------------
func get_dialogue_box():
	return get_tree().get_first_node_in_group("dialogue_box")


func load_dialogue():

	if dialogue_file == "":
		print("ERROR: No dialogue file set!")
		return

	var file = FileAccess.open(dialogue_file, FileAccess.READ)

	if file == null:
		print("ERROR: Could not open ", dialogue_file)
		return

	dialogue = JSON.parse_string(file.get_as_text())

	print("Dialogue loaded: ", dialogue.size())


func _on_body_entered(body):
	if body.name == "James":
		player_nearby = true
		label.visible = true


func _on_body_exited(body):
	if body.name == "James":
		player_nearby = false
		label.visible = false
		close_dialogue()


func _process(_delta):

	if not player_nearby:
		return

	if Input.is_action_just_pressed("interact"):

		if not dialogue_started:
			start_greeting()

		elif not choice_mode:
			show_dialogue()

	# Choice system
	if choice_mode:

		if Input.is_key_pressed(KEY_1):
			choice_mode = false
			show_dialogue()

		if Input.is_key_pressed(KEY_2) and has_minigame:
			get_tree().change_scene_to_file(minigame_scene)


# ----------------------------
# GREETING / CHOICES
# ----------------------------
func start_greeting():

	dialogue_started = true
	choice_mode = true

	var text = "Welcome, Archivist James.\n\n[1] Learn more"

	if has_minigame:
		text += "\n[2] Play Mini Game"

	var box = get_dialogue_box()

	if box == null:
		print("ERROR: dialogue_box NOT FOUND in scene!")
		return

	box.show_name(npc_name)
	box.show_text(text)


# ----------------------------
# MAIN DIALOGUE
# ----------------------------
func show_dialogue():

	var box = get_dialogue_box()

	if box == null:
		print("ERROR: dialogue_box missing in this scene!")
		return

	if dialogue_index < dialogue.size():

		var line = dialogue[dialogue_index]

		box.show_name(line["name"])
		box.show_text(line["text"])

		dialogue_index += 1

	else:
		dialogue_index = 0
		dialogue_started = false
		close_dialogue()


# ----------------------------
# CLOSE DIALOGUE
# ----------------------------
func close_dialogue():

	var box = get_dialogue_box()

	if box:
		box.hide_box()
