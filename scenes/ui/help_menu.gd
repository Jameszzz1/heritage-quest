
extends Control

@export var grape_soda_font: Font

@onready var close_button: Button = $Background/HelpPanel/CloseButton
@onready var title_label: Label = $Background/HelpPanel/Title
@onready var subtitle_label: Label = $Background/HelpPanel/Subtitle
@onready var scroll_container: ScrollContainer = $Background/HelpPanel/ScrollContainer
@onready var controls_container: VBoxContainer = $Background/HelpPanel/ScrollContainer/ControlsContainer


var control_sections = [
	{
		"title": "MOVEMENT",
		"controls": [
			["move_up", "Move Up"],
			["move_down", "Move Down"],
			["move_left", "Move Left"],
			["move_right", "Move Right"],
			["sprint", "Sprint"]
		]
	},
	{
		"title": "INTERACTION",
		"controls": [
			["interact", "Interact with NPCs and objects"]
		]
	},
	{
		"title": "GAME INTERFACE",
		"controls": [
			["open_backpack", "Open Backpack"],
			["open_map", "Open Map"],
			["pause", "Pause Game"]
		]
	},
	{
		"title": "SURVIVAL",
		"controls": [
			["flashlight", "Toggle Flashlight"]
		]
	}
]


func _ready():
	visible = false

	title_label.text = "GAME CONTROLS"
	subtitle_label.text = "Keyboard commands and gameplay"

	close_button.text = "X"
	close_button.pressed.connect(close_help)

	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	controls_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	build_controls()


func apply_font(control: Control, font_size: int):
	if grape_soda_font:
		control.add_theme_font_override("font", grape_soda_font)

	control.add_theme_font_size_override("font_size", font_size)


func build_controls():
	for child in controls_container.get_children():
		child.queue_free()

	for section in control_sections:
		add_section_title(section["title"])

		for control in section["controls"]:
			add_control_row(control[0], control[1])


func add_section_title(section_name: String):
	var label = Label.new()
	label.text = section_name

	apply_font(label, 16)

	label.add_theme_color_override(
		"font_color",
		Color("#F26B38")
	)

	controls_container.add_child(label)


func add_control_row(action_name: String, description: String):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_label = Label.new()
	key_label.text = get_action_keys(action_name)
	key_label.custom_minimum_size.x = 130
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	apply_font(key_label, 13)

	key_label.add_theme_color_override(
		"font_color",
		Color("#F8F8F6")
	)

	var description_label = Label.new()
	description_label.text = description
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	apply_font(description_label, 13)

	description_label.add_theme_color_override(
		"font_color",
		Color("#E5E5E5")
	)

	row.add_child(key_label)
	row.add_child(description_label)

	controls_container.add_child(row)


func get_action_keys(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "Not set"

	var keys: Array[String] = []

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			keys.append(event.as_text().replace(" (Physical)", ""))

		elif event is InputEventMouseButton:
			keys.append(event.as_text())

	if keys.is_empty():
		return "Unassigned"

	return " / ".join(keys)


func open_help():
	visible = true
	scroll_container.scroll_vertical = 0


func close_help():
	visible = false


func toggle_help():
	if visible:
		close_help()
	else:
		open_help()
