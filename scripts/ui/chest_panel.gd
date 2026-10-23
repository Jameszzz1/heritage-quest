extends Control

const SLOT_SIZE := Vector2(42, 48)
const ICON_SIZE := 16
const SLOT_FONT_SIZE := 5
const HEADING_FONT_SIZE := 10
const TITLE_FONT_SIZE := 16
const BUTTON_FONT_SIZE := 12

const BACKPACK_COLUMNS: int = 5
const BACKPACK_SCROLL_HEIGHT: float = 100.0

# Visible height of each grid before it starts scrolling (1 row).
const SCROLL_HEIGHT := 52.0

# Gap between headings and grids inside the panel's VBox. Lower = shorter panel.
const SECTION_SEPARATION := 0

# false = scrollbar only appears when there's more than one row.
# true  = scrollbar is always visible.
const SCROLLBAR_ALWAYS_VISIBLE := false

const UI_FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const BATTERY_ICON := "res://assets/sprites/things/battery.png"
const FISH_ICON := "res://assets/sprites/things/item_fish.png"
const SHOVEL_ICON := "res://assets/sprites/things/shovel.png"
const WATERING_CAN_ICON := "res://assets/sprites/things/watering can.png"
const EGGPLANT_SEEDS_ICON := "res://assets/sprites/things/eggplant seeds.png"
const CORN_SEEDS_ICON := "res://assets/sprites/things/corn seeds.png"
const PINEAPPLE_CROWN_ICON := "res://assets/sprites/things/pineapple crown.png"

var backpack_icon: Control
var minimap: Control

# Nodes are looked up by name in _ready(), so the exact tree layout doesn't matter.
var close_button: Button
var chest_grid: GridContainer
var backpack_grid: GridContainer
var chest_label: Label  # Optional - may stay null.

var ui_font: Font

var backpack_heading: Label
var chest_heading: Label

var chest_scroll: ScrollContainer
var backpack_scroll: ScrollContainer

# DEBUG: counter for F9 test items.
var _test_item_count: int = 0

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
	},
	"watering_can": {
		"name": "Watering Can",
		"icon": WATERING_CAN_ICON
	},
	"eggplant_seeds": {
		"name": "Eggplant Seeds",
		"icon": EGGPLANT_SEEDS_ICON
	},
	"corn_seeds": {
		"name": "Corn Seeds",
		"icon": CORN_SEEDS_ICON
	},
	"pineapple_crown": {
		"name": "Pineapple Crown",
		"icon": PINEAPPLE_CROWN_ICON
	},
	"debug_item": {
		"name": "Debug Item",
		"icon": BATTERY_ICON
	}
}


func _ready() -> void:
	hide()

	# Find nodes by name, wherever they are in the tree.
	close_button = find_child("CloseButton", true, false) as Button
	chest_grid = find_child("ChestGrid", true, false) as GridContainer
	backpack_grid = find_child("BackpackGrid", true, false) as GridContainer
	chest_label = find_child("ChestLabel", true, false) as Label

	if chest_grid == null:
		push_error("chest_panel.gd: no GridContainer named 'ChestGrid' found.")
		return
	if backpack_grid == null:
		push_error("chest_panel.gd: no GridContainer named 'BackpackGrid' found.")
		return

	# Load Grape Soda font.
	if ResourceLoader.exists(UI_FONT_PATH):
		ui_font = load(UI_FONT_PATH) as Font

	if ui_font == null:
		push_error("Could not load Grape Soda font: " + UI_FONT_PATH)
	else:
		_apply_font(self)

	# Connect close button.
	if close_button == null:
		push_warning("chest_panel.gd: no Button named 'CloseButton' found.")
	elif not close_button.pressed.is_connected(close_panel):
		close_button.pressed.connect(close_panel)

	# Configure chest grid (5 columns).
	chest_grid.columns = 5
	chest_grid.add_theme_constant_override("h_separation", 3)
	chest_grid.add_theme_constant_override("v_separation", 3)

	# Configure backpack grid (5 columns).
	backpack_grid.columns = 5
	backpack_grid.add_theme_constant_override("h_separation", 3)
	backpack_grid.add_theme_constant_override("v_separation", 3)

	# Wrap each grid in a ScrollContainer so extra rows scroll instead of overflow.
	chest_scroll = _wrap_in_scroll(chest_grid, "ChestScroll")
	backpack_scroll = _wrap_in_scroll(backpack_grid, "BackpackScroll")

	# Tighten the spacing between headings and grids to make the panel shorter.
	var section_box := chest_scroll.get_parent()
	if section_box is BoxContainer:
		section_box.add_theme_constant_override("separation", SECTION_SEPARATION)

	# Create headings and insert them before each grid's scroll container.
	chest_heading = _create_heading("ChestHeading", "Chest")
	_insert_heading_before(chest_heading, chest_grid)

	backpack_heading = _create_heading("BackpackHeading", "Backpack")
	_insert_heading_before(backpack_heading, backpack_grid)

	# Listen for inventory changes.
	if not Global.inventory_changed.is_connected(refresh_inventory):
		Global.inventory_changed.connect(refresh_inventory)

	# Add starter items only if absent from both inventories.
	var starter_items: Dictionary = {
		"shovel": 1,
		"watering_can": 1,
		"eggplant_seeds": 5,
		"corn_seeds": 5,
		"pineapple_crown": 3
	}

	for item_id in starter_items:
		if not Global.chest_inventory.has(item_id) \
		and not Global.inventory_items.has(item_id):
			Global.store_in_chest(
				item_id,
				int(starter_items[item_id])
			)

	# Find player HUD elements.
	find_player_ui()

	# Display current inventory.
	refresh_inventory()


# DEBUG: press F9 while the panel is open to add a new test item to the chest.
# Once there are more than 5 item types, a second row appears and scrolling enables.
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey \
	and event.pressed \
	and not event.echo \
	and event.keycode == KEY_F9:
		_test_item_count += 1
		Global.store_in_chest("test_item_%d" % _test_item_count, 1)
		refresh_inventory()


# Wraps a grid in a vertical-only ScrollContainer (unless it's already in one).
func _wrap_in_scroll(grid: GridContainer, scroll_name: String) -> ScrollContainer:
	var scroll: ScrollContainer
	var parent_is_container := false

	if grid.get_parent() is ScrollContainer:
		scroll = grid.get_parent() as ScrollContainer
		parent_is_container = scroll.get_parent() is Container
	else:
		var parent := grid.get_parent()
		var index := grid.get_index()
		parent_is_container = parent is Container

		# Remember the grid's old position/size in case the parent is a plain Control.
		var old_position := grid.position
		var old_width := maxf(grid.size.x, grid.get_combined_minimum_size().x)

		scroll = ScrollContainer.new()
		scroll.name = scroll_name

		parent.remove_child(grid)
		parent.add_child(scroll)
		parent.move_child(scroll, index)
		scroll.add_child(grid)

		# A plain Control parent won't lay the scroll out, so size it by hand.
		if not parent_is_container:
			scroll.position = old_position
			scroll.size = Vector2(old_width, SCROLL_HEIGHT)

	scroll.clip_contents = true
	scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	if SCROLLBAR_ALWAYS_VISIBLE:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	else:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if parent_is_container:
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Don't let the parent stretch the scroll taller than SCROLL_HEIGHT.
		scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Let the grid fill the scroll width so columns lay out correctly.
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	return scroll



func _create_heading(node_name: String, text_value: String) -> Label:
	var heading := Label.new()
	heading.name = node_name
	heading.text = text_value
	heading.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)

	if ui_font != null:
		heading.add_theme_font_override("font", ui_font)

	return heading


func _insert_heading_before(heading: Label, grid: GridContainer) -> void:
	# If the grid sits inside a ScrollContainer, put the heading above the
	# scroll container (ScrollContainers only allow one child).
	var anchor: Control = grid
	if grid.get_parent() is ScrollContainer:
		anchor = grid.get_parent() as Control

	var container := anchor.get_parent()
	container.add_child(heading)
	container.move_child(heading, anchor.get_index())


func find_player_ui() -> void:
	var james = get_tree().get_first_node_in_group("player")

	if james == null:
		print("James not found in player group!")
		return

	var hud = james.find_child("HUD", true, false)

	if hud == null:
		print("HUD not found inside James!")
		return

	backpack_icon = hud.find_child("Backpack", true, false) as Control
	minimap = hud.find_child("MiniMap", true, false) as Control

	print("Backpack found: ", backpack_icon != null)
	print("MiniMap found: ", minimap != null)


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
			if chest_label != null and node == chest_label:
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

	if is_instance_valid(backpack_icon):
		backpack_icon.show()

	if is_instance_valid(minimap):
		minimap.show()


func open_panel() -> void:
	refresh_inventory()
	show()

	if is_instance_valid(backpack_icon):
		backpack_icon.hide()

	if is_instance_valid(minimap):
		minimap.hide()


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

	var item_label := _make_label(_get_item_name(item_id))
	item_label.custom_minimum_size = Vector2(40, 0)
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 5)
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

	if chest_grid == null or backpack_grid == null:
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
	print("Clicked backpack item: ", item_id)

	var success = Global.transfer_to_chest(item_id, 1)

	print("Transfer successful: ", success)
	print("Chest inventory: ", Global.chest_inventory)
	print("Backpack inventory: ", Global.inventory_items)

	# DEBUG: Add one test item to the backpack.
	if not Global.inventory_items.has("debug_item"):
		Global.inventory_items["debug_item"] = 1

	refresh_inventory()
