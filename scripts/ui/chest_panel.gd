extends Control

const SLOT_SIZE := Vector2(28, 30)
const ICON_SIZE := 16
const SLOT_FONT_SIZE := 5
const HEADING_FONT_SIZE := 12
const TITLE_FONT_SIZE := 16
const BUTTON_FONT_SIZE := 12

const UI_FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const BATTERY_ICON := "res://assets/sprites/things/battery.png"
const FISH_ICON := "res://assets/sprites/things/item_fish.png"
const SHOVEL_ICON := "res://assets/sprites/things/shovel.png"


@onready var close_button: Button = $CloseButton
@onready var chest_grid: GridContainer = $PanelContainer/VBoxContainer/ChestGrid
@onready var chest_label: Label = $PanelContainer/VBoxContainer/HBoxContainer/ChestLabel
@onready var main_vbox: VBoxContainer = $PanelContainer/VBoxContainer

var ui_font: Font

var backpack_grid: GridContainer
var backpack_heading: Label
var chest_heading: Label

var item_data: Dictionary = {
	"battery": {
		"name": "Battery",
		"icon": BATTERY_ICON
	},
	"fish": {
		"name": "Fish",
		"icon": FISH_ICON
	},
		"shovel": {
		"name": "Shovel",
		"icon": SHOVEL_ICON
	}
}


func _ready() -> void:
	hide()

	# Load Grape Soda.
	if ResourceLoader.exists(UI_FONT_PATH):
		ui_font = load(UI_FONT_PATH) as Font

	if ui_font == null:
		push_error("Could not load Grape Soda font: " + UI_FONT_PATH)
	else:
		_apply_font(self)

	# Connect close button.
	if not close_button.pressed.is_connected(close_panel):
		close_button.pressed.connect(close_panel)

	# Configure chest grid.
	chest_grid.columns = 6
	chest_grid.add_theme_constant_override("h_separation", 3)
	chest_grid.add_theme_constant_override("v_separation", 3)

	# Create Chest heading.
	chest_heading = Label.new()
	chest_heading.name = "ChestHeading"
	chest_heading.text = "Chest"
	chest_heading.add_theme_font_size_override(
		"font_size", HEADING_FONT_SIZE
	)
	main_vbox.add_child(chest_heading)
	main_vbox.move_child(
		chest_heading,
		chest_grid.get_index()
	)

	# Create Backpack heading.
	backpack_heading = Label.new()
	backpack_heading.name = "BackpackHeading"
	backpack_heading.text = "Backpack"
	backpack_heading.add_theme_font_size_override(
		"font_size", HEADING_FONT_SIZE
	)
	main_vbox.add_child(backpack_heading)

	# Create Backpack grid.
	backpack_grid = GridContainer.new()
	backpack_grid.name = "BackpackGridContainer"
	backpack_grid.columns = 6
	backpack_grid.add_theme_constant_override("h_separation", 3)
	backpack_grid.add_theme_constant_override("v_separation", 3)
	main_vbox.add_child(backpack_grid)

	# Apply the font to dynamically created headings.
	_apply_font(chest_heading)
	_apply_font(backpack_heading)

	# Listen for inventory changes.
	if not Global.inventory_changed.is_connected(refresh_inventory):
		Global.inventory_changed.connect(refresh_inventory)

	# Add the starting shovel only if it is not already owned or stored.
	if not Global.chest_inventory.has("shovel") \
	and not Global.inventory_items.has("shovel"):
		Global.store_in_chest("shovel", 1)


	refresh_inventory()


func _exit_tree() -> void:
	if is_instance_valid(Global):
		if Global.inventory_changed.is_connected(refresh_inventory):
			Global.inventory_changed.disconnect(refresh_inventory)


# Apply Grape Soda recursively to existing controls.
func _apply_font(node: Node) -> void:
	if ui_font == null:
		return

	if node is Control:
		node.add_theme_font_override("font", ui_font)

		if node is Label:
			if node == chest_label:
				node.add_theme_font_size_override(
					"font_size", TITLE_FONT_SIZE
				)
			else:
				node.add_theme_font_size_override(
					"font_size", HEADING_FONT_SIZE
				)

		elif node is Button:
			node.add_theme_font_size_override(
				"font_size", BUTTON_FONT_SIZE
			)

	for child in node.get_children():
		_apply_font(child)


func close_panel() -> void:
	hide()


func open_panel() -> void:
	refresh_inventory()
	show()


func _get_item_name(item_id: String) -> String:
	if item_data.has(item_id):
		return str(item_data[item_id]["name"])

	return item_id.replace("_", " ").capitalize()


func _get_item_icon(item_id: String) -> String:
	if item_data.has(item_id):
		return str(item_data[item_id].get("icon", ""))

	return ""


func _make_label(
	text_value: String,
	font_size: int = SLOT_FONT_SIZE
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ui_font != null:
		label.add_theme_font_override("font", ui_font)

	return label


func _create_slot(
	item_id: String,
	amount: int,
	is_chest_item: bool
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE


	if ui_font != null:
		button.add_theme_font_override("font", ui_font)

	var contents := VBoxContainer.new()
	contents.set_anchors_preset(Control.PRESET_FULL_RECT)
	contents.alignment = BoxContainer.ALIGNMENT_CENTER
	contents.add_theme_constant_override("separation", 0)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(contents)

	# Item icon.
	var icon := TextureRect.new()
	var icon_path := _get_item_icon(item_id)

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)

	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(icon)

	# Item name.
	var item_label := _make_label(_get_item_name(item_id))
	contents.add_child(item_label)

	# Quantity.
	var count_label := _make_label("x%d" % amount)
	count_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.9, 0.3)
	)
	contents.add_child(count_label)

	# Click chest items to take one.
	if is_chest_item:
		button.pressed.connect(
			_on_chest_item_pressed.bind(item_id)
		)
	else:
		# Click backpack items to store one.
		button.pressed.connect(
			_on_backpack_item_pressed.bind(item_id)
		)

	return button


func refresh_inventory() -> void:
	if not is_node_ready():
		return

	_clear_grid(chest_grid)
	_clear_grid(backpack_grid)

	# Display items stored in the chest.
	for item_id in Global.chest_inventory.keys():
		var amount := int(Global.chest_inventory[item_id])

		if amount > 0:
			chest_grid.add_child(
				_create_slot(str(item_id), amount, true)
			)

	# Display existing battery and fish counters.
	_add_backpack_item("battery", Global.battery_items)
	_add_backpack_item("fish", Global.fish_items)

	# Display other generic backpack items.
	for item_id in Global.inventory_items.keys():
		_add_backpack_item(
			str(item_id),
			int(Global.inventory_items[item_id])
		)


func _clear_grid(target_grid: GridContainer) -> void:
	for child in target_grid.get_children():
		target_grid.remove_child(child)
		child.queue_free()


func _add_backpack_item(
	item_id: String,
	amount: int
) -> void:
	if amount <= 0:
		return

	backpack_grid.add_child(
		_create_slot(item_id, amount, false)
	)


func _on_chest_item_pressed(item_id: String) -> void:
	if Global.transfer_to_backpack(item_id, 1):
		refresh_inventory()


func _on_backpack_item_pressed(item_id: String) -> void:
	if Global.transfer_to_chest(item_id, 1):
		refresh_inventory()
