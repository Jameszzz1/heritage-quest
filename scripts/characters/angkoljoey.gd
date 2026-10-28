extends CharacterBody2D

const COMIC_PATH := "res://scenes/ui/comic_maliksi.tscn"
const STORY_META := "maliksi_story_seen"

@export_file("*.json") var json_file_path: String = "res://dialogues/angkol_joey.json"
@export var play_once: bool = false   # true = only talks the first time

@onready var area: Area2D = $Area2D
@onready var label: Label = $InteractLabel

var player_nearby: bool = false
var state: String = "IDLE"          # IDLE or DIALOGUE
var dialogue_lines: Array = []      # flat array of {name, text, event?}
var line_index: int = 0
var has_talked: bool = false
var _pending_event: String = ""     # event na tatakbo sa susunod na interact


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
		print("✅ Angkol Joey JSON loaded (", json_file_path, "): ", dialogue_lines.size(), " lines")
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
			get_viewport().set_input_as_handled()
			start_conversation()
		elif state == "DIALOGUE":
			get_viewport().set_input_as_handled()
			show_next_line()


func start_conversation() -> void:
	if dialogue_lines.is_empty():
		print("❌ No dialogue lines loaded")
		return

	line_index = 0
	_pending_event = ""
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

	# May event na naiwan mula sa naunang linya (hal. comic): patakbuhin muna
	if _pending_event != "":
		var ev := _pending_event
		_pending_event = ""
		await _run_event(ev)
		if state != "DIALOGUE":
			return

	if line_index >= dialogue_lines.size():
		close_dialogue()
		return

	var line = dialogue_lines[line_index]
	var who: String = str(line.get("name", "Angkol Joey"))
	var text: String = apply_name(str(line.get("text", "")))

	var display_name = who
	if who.to_lower() == "player" or who.to_lower() == "james":
		display_name = get_player_name()

	box.show_name(display_name)
	box.show_text(text)

	# Kapag may "event" ang linyang ito, tatakbo ito sa susunod na interact
	if line.has("event"):
		_pending_event = str(line["event"])
		print("🎬 Pending event: ", _pending_event)

	line_index += 1


# ---------- EVENTS ----------
func _run_event(event_name: String) -> void:
	print("🎬 Running event: ", event_name)
	match event_name:
		"maliksi_comic":
			await _play_maliksi_comic()
		_:
			print("⚠️ Unknown event: ", event_name)


func _play_maliksi_comic() -> void:
	# Isang beses lang bawat session (itatago pa sa save kapag nakita ko ang global.gd)
	if Global.has_meta(STORY_META):
		print("ℹ️ Maliksi comic already seen this session")
		return

	if not ResourceLoader.exists(COMIC_PATH):
		print("❌ Comic scene not found: ", COMIC_PATH)
		return

	Global.set_meta(STORY_META, true)

	var box = get_dialogue_box()
	if box and box.has_method("hide_box"):
		box.hide_box()

	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(layer)

	var comic = load(COMIC_PATH).instantiate()
	comic.next_scene = ""   # popup mode: magsasara lang, hindi lilipat ng scene
	layer.add_child(comic)

	get_tree().paused = true
	await comic.finished
	get_tree().paused = false
	layer.queue_free()


func close_dialogue() -> void:
	if state == "DIALOGUE":
		has_talked = true

	state = "IDLE"
	line_index = 0
	_pending_event = ""

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
