extends CharacterBody2D

@export_file("*.json") var json_file_path: String = "res://dialogues/angkol_joey.json"
@export var play_once: bool = false   # true = only talks the first time

@onready var area: Area2D = $Area2D
@onready var label: Label = $InteractLabel

var player_nearby: bool = false
var state: String = "IDLE"          # IDLE or DIALOGUE
var dialogue_lines: Array = []      # flat array of {name, text}
var line_index: int = 0
var has_talked: bool = false


func _ready() -> void:
	if label:
		label.visible = false

	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	load_dialogue_json()
	print("Angkol Joey ready | lines: ", dialogue_lines.size())


func load_dialogue_json() -> void:
	if not FileAccess.file_exists(json_file_path):
		print("❌ JSON not found: ", json_file_path)
		return

	var file = FileAccess.open(json_file_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed is Array:
		dialogue_lines = parsed
		print("✅ Angkol Joey JSON loaded: ", dialogue_lines.size(), " lines")
	else:
		print("❌ Failed to parse Angkol Joey JSON (must be an Array)")


func get_dialogue_box():
	return get_tree().get_first_node_in_group("dialogue_box")


# ---------- PROXIMITY ----------
func _on_body_entered(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = true
		if label and not (play_once and has_talked):
			label.visible = true
		print("✅ James entered Angkol Joey range")


func _on_body_exited(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = false
		if label:
			label.visible = false
		close_dialogue()
		print("James left Angkol Joey range")


# ---------- INPUT ----------
func _input(event: InputEvent) -> void:
	if not player_nearby:
		return

	if event.is_action_pressed("interact"):
		if state == "IDLE":
			if play_once and has_talked:
				return
			start_conversation()
			get_viewport().set_input_as_handled()
		elif state == "DIALOGUE":
			show_next_line()
			get_viewport().set_input_as_handled()


func start_conversation() -> void:
	if dialogue_lines.is_empty():
		print("❌ No dialogue lines loaded")
		return

	line_index = 0
	state = "DIALOGUE"
	if label:
		label.visible = false

	print("💬 Starting Angkol Joey dialogue")
	show_next_line()


func show_next_line() -> void:
	var box = get_dialogue_box()
	if box == null:
		print("❌ dialogue_box group not found!")
		return

	if line_index >= dialogue_lines.size():
		close_dialogue()
		return

	var line = dialogue_lines[line_index]
	var who: String = str(line.get("name", "Angkol Joey"))
	var text: String = str(line.get("text", ""))

	text = apply_name(text)

	var display_name = who
	if who.to_lower() == "player" or who.to_lower() == "james":
		display_name = get_player_name()

	box.show_name(display_name)
	box.show_text(text)

	line_index += 1


func close_dialogue() -> void:
	if state == "DIALOGUE":
		has_talked = true

	state = "IDLE"
	line_index = 0

	var box = get_dialogue_box()
	if box and box.has_method("hide_box"):
		box.hide_box()

	if player_nearby and label and not (play_once and has_talked):
		label.visible = true


# ---------- PLAYER NAME ----------
func get_player_name() -> String:
	if Global.has_method("get_player_name"):
		return Global.get_player_name()
	return "Archivist"


func apply_name(text: String) -> String:
	if Global.has_method("get_player_name"):
		return text.replace("{player}", Global.get_player_name())
	elif Global.has_method("apply_player_name"):
		return Global.apply_player_name(text)
	return text.replace("{player}", "Archivist")
