extends CharacterBody2D

var entries: Array = []
var player_nearby = false
var entry_index = 0
var is_waiting = false

@onready var area = $Area2D
@onready var label = $InteractLabel
@onready var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	label.visible = false

	var file = FileAccess.open("res://dialogues/dula_questions.json", FileAccess.READ)
	if file == null:
		print("ERROR: Could not open dula_questions.json")
		return
	entries = JSON.parse_string(file.get_as_text())
	print("Loaded: ", entries.size(), " entries")

func _on_body_entered(body):
	if body.name == "James":
		player_nearby = true
		label.visible = true

func _on_body_exited(body):
	if body.name == "James":
		player_nearby = false
		label.visible = false
		close_quiz()

func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("interact"):
		if is_waiting:
			is_waiting = false
			entry_index += 1
			show_entry()
		elif entry_index == 0:
			show_entry()

func show_entry():
	if dialogue_box == null:
		print("ERROR: dialogue_box not found!")
		return

	if entry_index >= entries.size():
		show_final_score()
		return

	var entry = entries[entry_index]

	if entry["type"] == "dialogue":
		# just show text, wait for E to continue
		dialogue_box.show_name(entry["name"])
		dialogue_box.show_text(entry["text"])
		is_waiting = true

	elif entry["type"] == "question":
		# show question with choices
		dialogue_box.show_name(entry["name"])
		dialogue_box.show_question(entry["question"], entry["choices"], entry["correct"])
		# wait for answer
		if not dialogue_box.answer_given.is_connected(_on_answer_given):
			dialogue_box.answer_given.connect(_on_answer_given)

func _on_answer_given():
	if dialogue_box.answer_given.is_connected(_on_answer_given):
		dialogue_box.answer_given.disconnect(_on_answer_given)
	is_waiting = true  # press E to continue to next entry

func show_final_score():
	var total = 0
	for e in entries:
		if e["type"] == "question":
			total += 1
	var score = dialogue_box.score
	dialogue_box.show_name("Dula")
	dialogue_box.show_text("You answered " + str(score) + " out of " + str(total) + " correctly. " + get_feedback(score, total))
	entry_index = 0
	dialogue_box.score = 0

func get_feedback(score: int, total: int) -> String:
	if score == total:
		return "Perfect! You truly listened well, James."
	elif score >= total / 2:
		return "Not bad! But there is still more to learn."
	else:
		return "You should listen more carefully next time."

func close_quiz():
	if dialogue_box == null:
		return
	dialogue_box.hide_box()
	entry_index = 0
	is_waiting = false
