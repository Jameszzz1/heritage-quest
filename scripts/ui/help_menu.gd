
extends CanvasLayer

@export var grape_soda_font: Font

@onready var background: ColorRect = $Background
@onready var help_panel: Panel = $Background/HelpPanel
@onready var main_container: VBoxContainer = $Background/HelpPanel/MainContainer
@onready var title_label: Label = $Background/HelpPanel/MainContainer/Header/Title
@onready var close_button: Button = $Background/HelpPanel/MainContainer/Header/CloseButton
@onready var subtitle_label: Label = $Background/HelpPanel/MainContainer/Subtitle
@onready var scroll_container: ScrollContainer = $Background/HelpPanel/MainContainer/ScrollContainer
@onready var controls_container: VBoxContainer = $Background/HelpPanel/MainContainer/ScrollContainer/ControlsContainer


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

	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.6)
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	help_panel.custom_minimum_size = Vector2(650, 520)

	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.offset_left = 20
	main_container.offset_top = 18
	main_container.offset_right = -20
	main_container.offset_bottom = -18

	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ScrollContainer settings
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	scroll_container.custom_minimum_size = Vector2(0, 350)
	scroll_container.size = Vector2(600, 350)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll_container.clip_contents = true

	# ControlsContainer settings
	controls_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	controls_container.add_theme_constant_override("separation", 8)

	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	controls_container.mouse_filter = Control.MOUSE_FILTER_PASS

	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Scrollbar appearance
	var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()
	scrollbar.custom_minimum_size.x = 12

	var track := StyleBoxFlat.new()
	track.bg_color = Color("#333333")
	track.set_corner_radius_all(5)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#F26B38")
	grabber.set_corner_radius_all(5)

	var grabber_hover := StyleBoxFlat.new()
	grabber_hover.bg_color = Color("#D9572B")
	grabber_hover.set_corner_radius_all(5)

	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_hover)

	# Fonts
	apply_font(title_label, 22)
	apply_font(close_button, 14)
	apply_font(subtitle_label, 12)

	subtitle_label.text = "Game controls and keyboard commands"

	close_button.text = "X"
	close_button.pressed.connect(close_help)

	build_controls()

	background.visible = false


func apply_font(control: Control, font_size: int):

	if grape_soda_font:
		control.add_theme_font_override("font", grape_soda_font)

	control.add_theme_font_size_override("font_size", font_size)



func open_help():
	background.visible = true

	await get_tree().process_frame
	await get_tree().process_frame

	controls_container.reset_size()
	scroll_container.queue_sort()
	scroll_container.scroll_vertical = 0


func close_help():

	background.visible = false


func toggle_help():

	if background.visible:
		close_help()
	else:
		open_help()


func build_controls():

	for child in controls_container.get_children():
		child.queue_free()

	for section in control_sections:

		var section_title = Label.new()
		section_title.text = section["title"]

		apply_font(section_title, 15)

		section_title.add_theme_color_override(
			"font_color",
			Color("#F26B38")
		)

		controls_container.add_child(section_title)

		for control in section["controls"]:

			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var key_label = Label.new()
			key_label.text = get_action_keys(control[0])
			key_label.custom_minimum_size.x = 115
			key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

			apply_font(key_label, 13)

			var description_label = Label.new()
			description_label.text = control[1]
			description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

			apply_font(description_label, 13)

			key_label.add_theme_color_override(
				"font_color",
				Color("#F8F8F6")
			)

			description_label.add_theme_color_override(
				"font_color",
				Color("#E5E5E5")
			)

			row.add_child(key_label)
			row.add_child(description_label)

			controls_container.add_child(row)

	# Update layout after creating all controls
	controls_container.queue_sort()
	scroll_container.queue_sort()
	await get_tree().process_frame

	print("Scroll viewport height: ", scroll_container.size.y)
	print("Controls content height: ", controls_container.size.y)
	print("Scroll max value: ", scroll_container.get_v_scroll_bar().max_value)


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
