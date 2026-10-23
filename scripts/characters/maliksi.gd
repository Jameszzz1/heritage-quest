extends CharacterBody2D

# Path papunta sa JSON file ni Maliksi
@export_file("*.json") var json_file_path: String = "res://dialogues/maliksi.json"

# References sa child nodes (Sinisiguradong tumutugma sa Node Tree mo)
@onready var area_2d: Area2D = $Area2D
@onready var interact_label: Label = $InteractLabel
@onready var dialogue_player = $DialoguePlayer

var player_in_range: bool = false
var dialogue_data: Dictionary = {}
var current_province_key: String = ""
var encounter_index: int = 0

func _ready() -> void:
	# Itago ang "Press E to Interact" label sa simula
	if interact_label:
		interact_label.visible = false
	
	# Connect ang Area2D signals sa GDScript
	if area_2d:
		area_2d.body_entered.connect(_on_area_2d_body_entered)
		area_2d.body_exited.connect(_on_area_2d_body_exited)
	
	# Basahin ang JSON at alamin ang kasalukuyang probinsya
	load_dialogue_json()
	detect_current_province()

# Babasahin at i-pa-parse ang dialogue JSON file
func load_dialogue_json() -> void:
	if FileAccess.file_exists(json_file_path):
		var file = FileAccess.open(json_file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			dialogue_data = json.data
			print("✅ Successfully loaded JSON data for Maliksi.")
		else:
			print("❌ Error parsing JSON: ", json.get_error_message())
	else:
		print("❌ JSON File not found: ", json_file_path)

# Awtomatikong kukunin ang pangalan ng active scene (e.g., south_cotabato_shortway)
func detect_current_province() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		var full_path = current_scene.scene_file_path
		var file_name = full_path.get_file().get_basename()
		
		if dialogue_data.has(file_name):
			current_province_key = file_name
			print(" Current Province Key detected: ", current_province_key)
		else:
			current_province_key = "south_cotabato_shortway"
			print("⚠️ Scene key not found in JSON. Using fallback: ", current_province_key)

# Makikinig sa pagpindot ng 'E' key kapag malapit ang player
func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and (event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E)):
		print("🔘 'E' key pressed near Maliksi!")
		trigger_conversation()

# Babasahin ang dialogue lines at ipapasa sa DialoguePlayer
func trigger_conversation() -> void:
	if current_province_key == "" or not dialogue_data.has(current_province_key):
		print("❌ No dialogue data found for key: ", current_province_key)
		return
	
	var province_dialogue = dialogue_data[current_province_key]
	var encounters = province_dialogue.get("encounters", [])
	
	if encounters.size() > 0:
		# Piliin ang kasalukuyang encounter dialogue line
		var selected_lines = encounters[encounter_index % encounters.size()]
		var speaker_name = province_dialogue.get("speaker", "Maliksi")
		
		# I-increment para sa susunod na kwento pag nag-interact ulit
		encounter_index += 1
		
		print("💬 Starting dialogue with lines: ", selected_lines)
		
		# I-check at i-trigger ang function sa DialoguePlayer node
		if dialogue_player != null:
			if dialogue_player.has_method("start_dialogue"):
				dialogue_player.start_dialogue(selected_lines, speaker_name)
			elif dialogue_player.has_method("display_dialogue"):
				dialogue_player.display_dialogue(selected_lines)
			elif dialogue_player.has_method("show_dialogue"):
				dialogue_player.show_dialogue(selected_lines)
			elif dialogue_player.has_method("start"):
				dialogue_player.start(selected_lines)
			elif dialogue_player.has_method("play"):
				dialogue_player.play(selected_lines)
			else:
				print("❌ DialoguePlayer is present, but no matching method found.")
		else:
			print("❌ DialoguePlayer node is missing!")

# Detection kapag pumasok ang Player sa range
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("player") or body.name.to_lower().contains("james") or body is CharacterBody2D:
		player_in_range = true
		print(" Player entered Maliksi's interact range.")
		if interact_label:
			interact_label.visible = true

# Detection kapag lumabas ang Player sa range
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("player") or body.name.to_lower().contains("james") or body is CharacterBody2D:
		player_in_range = false
		print(" Player left Maliksi's interact range.")
		if interact_label:
			interact_label.visible = false
