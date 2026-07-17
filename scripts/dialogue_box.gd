extends Node

signal answer_given

@onready var name_label = $NinePatchRect/Name
@onready var body_label = $NinePatchRect/TextBody
@onready var dialogue_box = $NinePatchRect
@onready var choices_container = $ChoicesContainer
@onready var choice_buttons = [
	$ChoicesContainer/Choice1,
	$ChoicesContainer/Choice2,
	$ChoicesContainer/Choice3
]

var correct_answer = -1
var score = 0

func _ready():
	dialogue_box.visible = false
	choices_container.visible = false

func show_name(character_name: String):
	name_label.text = character_name

func show_text(text: String):
	dialogue_box.visible = true
	choices_container.visible = false
	body_label.text = text

func hide_box():
	dialogue_box.visible = false
	choices_container.visible = false
	score = 0

func show_question(question: String, choices: Array, correct: int):
	dialogue_box.visible = true
	body_label.text = question
	correct_answer = correct
	choices_container.visible = true
	for i in range(choice_buttons.size()):
		choice_buttons[i].text = choices[i]
		if choice_buttons[i].pressed.is_connected(_on_choice_pressed):
			choice_buttons[i].pressed.disconnect(_on_choice_pressed)
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))

func _on_choice_pressed(index: int):
	if index == correct_answer:
		score += 1
		body_label.text = "Correct! Well done."
	else:
		body_label.text = "That is not right. The correct answer is: " + choice_buttons[correct_answer].text
	choices_container.visible = false
	emit_signal("answer_given")
