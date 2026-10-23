extends CharacterBody2D

@export_file("*.json") var json_file_path: String = "res://dialogues/maliksi.json"

@onready var area: Area2D = $Area2D
@onready var label: Label = $InteractLabel

var player_nearby: bool = false
var dialogue_data: Dictionary = {}
var current_province_key: String = ""
var encounter_index: int = 0
var state: String = "IDLE"          # IDLE or DIALOGUE
var current_lines: Array = []
var line_index: int = 0
var current_speaker: String = "Maliksi"

func _ready() -> void:
	if label:
		label.visible = false
	
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	
	load_dialogue_json()
	detect_current_province()
	setup_night_glow()
	
	print("Maliksi ready | province key: ", current_province_key)


func setup_night_glow() -> void:
	# 1. Make the sprite slightly brighter + green tint
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(0.82, 1.05, 0.92)
	
	# 2. Remove old light if exists
	if has_node("PointLight2D"):
		get_node("PointLight2D").queue_free()
	
	# 3. Create soft circular glow texture
	var gradient = Gradient.new()
	gradient.colors = [
		Color(1, 1, 1, 1),      # center: fully white
		Color(1, 1, 1, 0)       # edge: transparent
	]
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 128
	gradient_texture.height = 128
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(0.5, 0.0)
	
	# 4. Create the light
	var light = PointLight2D.new()
	light.name = "PointLight2D"
	light.texture = gradient_texture
	light.color = Color(1.0, 1.0, 1.0, 1.0)     # soft green
	light.energy = 1.6
	light.texture_scale = 2.0
	light.position = Vector2(0, -10)
	light.z_index = 5
	light.enabled = true
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	
	add_child(light)
	print("✅ Maliksi soft glow created")


func load_dialogue_json() -> void:
	if not FileAccess.file_exists(json_file_path):
		print("❌ JSON not found: ", json_file_path)
		return
	
	var file = FileAccess.open(json_file_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		dialogue_data = parsed
		print("✅ Maliksi JSON loaded. Keys: ", dialogue_data.keys())
	else:
		print("❌ Failed to parse Maliksi JSON")


func detect_current_province() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	
	var basename = scene.scene_file_path.get_file().get_basename()
	print("Scene basename: ", basename)
	
	if dialogue_data.has(basename):
		current_province_key = basename
	else:
		current_province_key = "south_cotabato_shortway"
		print("⚠️ Key not found, using fallback: ", current_province_key)


func get_dialogue_box():
	return get_tree().get_first_node_in_group("dialogue_box")


# ---------- PROXIMITY ----------
func _on_body_entered(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = true
		if label:
			label.visible = true
		print("✅ James entered Maliksi range")


func _on_body_exited(body: Node2D) -> void:
	if body.name == "James":
		player_nearby = false
		if label:
			label.visible = false
		close_dialogue()
		print("James left Maliksi range")


# ---------- INPUT ----------
func _input(event: InputEvent) -> void:
	if not player_nearby:
		return
	
	if event.is_action_pressed("interact"):
		if state == "IDLE":
			start_conversation()
			get_viewport().set_input_as_handled()
		elif state == "DIALOGUE":
			show_next_line()
			get_viewport().set_input_as_handled()


func start_conversation() -> void:
	if current_province_key == "" or not dialogue_data.has(current_province_key):
		print("❌ No dialogue data for: ", current_province_key)
		return
	
	var province = dialogue_data[current_province_key]
	var encounters = province.get("encounters", [])
	
	if encounters.is_empty():
		print("❌ No encounters")
		return
	
	current_lines = encounters[encounter_index % encounters.size()]
	current_speaker = province.get("speaker", "Maliksi")
	encounter_index += 1
	line_index = 0
	state = "DIALOGUE"
	
	print("💬 Starting Maliksi dialogue (encounter ", encounter_index, ")")
	show_next_line()


func show_next_line() -> void:
	var box = get_dialogue_box()
	if box == null:
		print("❌ dialogue_box group not found!")
		return
	
	if line_index >= current_lines.size():
		close_dialogue()
		return
	
	var line = current_lines[line_index]
	var who: String = str(line.get("who", "maliksi"))
	var text: String = str(line.get("text", ""))
	
	# Replace {player}
	if Global.has_method("get_player_name"):
		text = text.replace("{player}", Global.get_player_name())
	elif Global.has_method("apply_player_name"):
		text = Global.apply_player_name(text)
	
	var display_name = current_speaker
	if who.to_lower() == "player" or who.to_lower() == "james":
		if Global.has_method("get_player_name"):
			display_name = Global.get_player_name()
		else:
			display_name = "Archivist"
	
	box.show_name(display_name)
	box.show_text(text)
	
	line_index += 1


func close_dialogue() -> void:
	state = "IDLE"
	line_index = 0
	current_lines = []
	
	var box = get_dialogue_box()
	if box and box.has_method("hide_box"):
		box.hide_box()
