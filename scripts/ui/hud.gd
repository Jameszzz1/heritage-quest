extends CanvasLayer

@onready var backpack_button = $Backpack
@onready var backpack_popup = $BackpackPopup
@onready var close_button = $BackpackPopup/Button
@onready var grid = $BackpackPopup/TabContainer/Inventory/ScrollContainer/GridContainer
@onready var minimap = $MiniMap
@onready var settings = $Settings
@onready var pause_label = $PauseLabel
@onready var quest_log_button: Button = $QuestLogButton
@onready var quest_log: Control = $QuestLog

var is_paused: bool = false

const BATTERY_ITEM_RESTORE: float = 30.0
const FISH_ITEM_RESTORE: float = 25.0

const BATTERY_ICON_PATH: String = "res://assets/sprites/things/battery.png"
const FISH_ICON_PATH: String = "res://assets/sprites/things/item_fish.png"
const SHOVEL_ICON_PATH: String = "res://assets/sprites/things/shovel.png"
const UI_FONT_PATH: String = "res://assets/fonts/GrapeSoda.ttf"

const TOKENS: Array = [
	{"id": "south_cotabato", "label": "S. Cotabato", "title": "South Cotabato Token", "path": "res://assets/images/tokens/token_southcotabato.png"},
	{"id": "sarangani", "label": "Sarangani", "title": "Sarangani Token", "path": "res://assets/images/tokens/token_sarangani.png"},
	{"id": "sultan_kudarat", "label": "S. Kudarat", "title": "Sultan Kudarat Token", "path": "res://assets/images/tokens/token_sultankudarat.png"},
	{"id": "cotabato_province", "label": "Cotabato", "title": "Cotabato Province Token", "path": "res://assets/images/tokens/token_cotabatoprovince.png"}
]

const SLOT_SIZE: Vector2 = Vector2(42, 48)
const ICON_SIZE: int = 16
const SLOT_FONT_SIZE: int = 5
const TOAST_FONT_SIZE: int = 6
const SHOW_COUNT: bool = true

const INVENTORY_COLUMNS: int = 5
const INVENTORY_SCROLL_HEIGHT: float = 100.0

var inventory_scroll: ScrollContainer
var ui_font: Font

var death_screen: ColorRect
var death_countdown_label: Label

var battery_slot: Button
var battery_count_label: Label

var fish_slot: Button
var fish_count_label: Label

var shovel_slot: Button
var shovel_count_label: Label

var token_slots: Dictionary = {}
var toast_label: Label
var toast_token: int = 0

var _last_battery_count: int = 0
var _last_fish_count: int = 0
var _last_shovel_count: int = 0

var journal_container: Control = null
var journal_scroll: ScrollContainer
var journal_vbox: VBoxContainer


func _ready() -> void:
	backpack_popup.visible = false
	minimap.visible = true
	pause_label.visible = false

	add_to_group("hud")
	call_deferred("_find_player")

	backpack_button.pressed.connect(_on_backpack_pressed)
	close_button.pressed.connect(_on_close_pressed)
	quest_log_button.pressed.connect(_on_quest_log_button_pressed)

	setup_death_overlay()

	_last_battery_count = Global.battery_items
	_last_fish_count = Global.fish_items
	_last_shovel_count = _get_shovel_count()

	setup_inventory()
	setup_tokens()
	setup_toast()

	if not Global.inventory_changed.is_connected(_on_inventory_changed):
		Global.inventory_changed.connect(_on_inventory_changed)

	if not Global.journal_updated.is_connected(_on_journal_updated):
		Global.journal_updated.connect(_on_journal_updated)

	if not Global.token_claimed.is_connected(_on_token_claimed):
		Global.token_claimed.connect(_on_token_claimed)

	setup_journal_tab()


func _exit_tree() -> void:
	if is_instance_valid(Global):
		if Global.inventory_changed.is_connected(_on_inventory_changed):
			Global.inventory_changed.disconnect(_on_inventory_changed)

		if Global.journal_updated.is_connected(_on_journal_updated):
			Global.journal_updated.disconnect(_on_journal_updated)

		if Global.token_claimed.is_connected(_on_token_claimed):
			Global.token_claimed.disconnect(_on_token_claimed)


# ---------------- DEATH OVERLAY ----------------

func setup_death_overlay() -> void:
	death_screen = ColorRect.new()
	death_screen.color = Color(0, 0, 0, 0)
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.z_index = 4096
	add_child(death_screen)

	death_countdown_label = Label.new()
	death_countdown_label.add_theme_font_size_override("font_size", 40)
	death_countdown_label.add_theme_color_override("font_color", Color.WHITE)

	var custom_font = load(UI_FONT_PATH)
	if custom_font:
		death_countdown_label.add_theme_font_override("font", custom_font)

	death_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_countdown_label.visible = false
	death_countdown_label.z_index = 4096
	add_child(death_countdown_label)


func _center_countdown_label() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	death_countdown_label.reset_size()
	var label_size = death_countdown_label.size
	death_countdown_label.position = (viewport_size - label_size) / 2.0


func show_death_sequence() -> void:
	var tween = create_tween()
	tween.tween_property(death_screen, "color", Color(0, 0, 0, 0.6), 1.0)
	await tween.finished

	death_countdown_label.visible = true
	var seconds_left = 10

	while seconds_left > 0:
		death_countdown_label.text = "Respawning in " + str(seconds_left)
		_center_countdown_label()
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1

	death_countdown_label.visible = false
	death_screen.color = Color(0, 0, 0, 0)


# ---------------- INVENTORY SLOT HELPERS ----------------

func _make_slot_label(label_text: String) -> Label:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color.WHITE)

	var font = load(UI_FONT_PATH)
	if font:
		lbl.add_theme_font_override("font", font)

	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl



func _build_slot(
	icon_path: String,
	label_text: String,
	on_press: Callable,
	amount: int = 1
) -> Dictionary:
	var slot := Button.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.tooltip_text = ""
	
	if ResourceLoader.exists(UI_FONT_PATH):
		var font := load(UI_FONT_PATH) as Font
		if font:
			slot.add_theme_font_override("font", font)

	if on_press.is_valid():
		slot.pressed.connect(on_press)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)

	var icon := TextureRect.new()

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D

	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := _make_slot_label(label_text)
	name_label.custom_minimum_size = Vector2(38, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var count_label := _make_slot_label("x%d" % amount)
	count_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.9, 0.3)
	)
	count_label.visible = SHOW_COUNT
	box.add_child(count_label)

	return {
		"slot": slot,
		"count_label": count_label
	}


func _get_shovel_count() -> int:
	return int(Global.inventory_items.get("shovel", 0))


func setup_inventory() -> void:
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var scroll := grid.get_parent() as ScrollContainer
	if scroll:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var battery_built := _build_slot(
		BATTERY_ICON_PATH, "Battery", use_battery_item, Global.battery_items
	)
	battery_slot = battery_built["slot"]
	battery_count_label = battery_built["count_label"]
	grid.add_child(battery_slot)

	var fish_built := _build_slot(
		FISH_ICON_PATH, "Fish", use_fish_item, Global.fish_items
	)
	fish_slot = fish_built["slot"]
	fish_count_label = fish_built["count_label"]
	grid.add_child(fish_slot)

	var shovel_built := _build_slot(
		SHOVEL_ICON_PATH, "Shovel", _toggle_shovel, _get_shovel_count()
	)
	shovel_slot = shovel_built["slot"]
	shovel_count_label = shovel_built["count_label"]
	grid.add_child(shovel_slot)

	_refresh_inventory()


func _get_item_icon_path(item_id: String) -> String:
	match item_id:
		"battery":
			return BATTERY_ICON_PATH
		"fish":
			return FISH_ICON_PATH
		"shovel":
			return SHOVEL_ICON_PATH
		"watering_can":
			return "res://assets/sprites/things/watering can.png"
		"eggplant_seeds":
			return "res://assets/sprites/things/eggplant seeds.png"
		"corn_seeds":
			return "res://assets/sprites/things/corn seeds.png"
		"eggplant":
			return "res://assets/sprites/things/eggplant.png"
		"corn":
			return "res://assets/sprites/things/corn.png"
		"pineapple":
			return "res://assets/sprites/things/pineapple.png"
		"pineapple_crown":
			return "res://assets/sprites/things/pineapple crown.png"
		_:
			return BATTERY_ICON_PATH




func _refresh_inventory() -> void:
	if not is_instance_valid(grid):
		return

	# Battery slot.
	if is_instance_valid(battery_slot):
		battery_slot.visible = Global.battery_items > 0
		battery_count_label.text = "x%d" % Global.battery_items

	# Fish slot.
	if is_instance_valid(fish_slot):
		fish_slot.visible = Global.fish_items > 0
		fish_count_label.text = "x%d" % Global.fish_items

	# Shovel slot.
	var shovel_count := _get_shovel_count()

	if is_instance_valid(shovel_slot):
		shovel_slot.visible = shovel_count > 0
		shovel_count_label.text = "x%d" % shovel_count

	# Remove generic item slots from the previous refresh.
	for child in grid.get_children():
		if child.has_meta("generic_inventory_item"):
			grid.remove_child(child)
			child.queue_free()

	# Display backpack items.
	for item_id in Global.inventory_items.keys():
		var id := str(item_id)
		var amount := int(Global.inventory_items[item_id])

		if amount <= 0:
			continue

		if id == "shovel":
			continue

		var item_name := id.replace("_", " ").capitalize()
		var icon_path := _get_item_icon_path(id)
		var item_action := Callable()

		# Watering can.
		if id == "watering_can":
			item_action = _toggle_watering_can

		# Plantable seeds and pineapple crown.
		elif id in [
			"eggplant_seeds",
			"corn_seeds",
			"pineapple_crown"
		]:
			item_action = _select_seed.bind(id)

		# Consumable harvested crops.
		elif id in ["eggplant", "corn", "pineapple"]:
			item_action = _consume_item.bind(id)

		# Create the inventory slot.
		var built := _build_slot(
			icon_path,
			item_name,
			item_action,
			amount
		)

		var slot: Button = built["slot"]
		slot.set_meta("generic_inventory_item", true)

		# Enable only usable items.
		slot.disabled = not (
			id in [
				"watering_can",
				"eggplant_seeds",
				"corn_seeds",
				"pineapple_crown",
				"eggplant",
				"corn",
				"pineapple"
			]
		)

		grid.add_child(slot)

	_refresh_tokens()

func _consume_item(item_id: String) -> void:
	var james = get_tree().get_first_node_in_group("player")

	if james == null:
		return

	if Global.get_backpack_item_count(item_id) <= 0:
		_show_toast("You don't have this item.")
		return

	match item_id:
		"eggplant":
			james.energy = minf(james.energy + 10.0, james.max_energy)
			_show_toast("Consumed Eggplant! +10 Energy")

		"corn":
			james.energy = minf(james.energy + 15.0, james.max_energy)
			_show_toast("Consumed Corn! +15 Energy")

		"pineapple":
			james.health = minf(james.health + 20.0, james.max_health)
			_show_toast("Consumed Pineapple! +20 Health")

		_:
			return

	Global.remove_item(item_id, 1)
	_refresh_inventory()


func _on_inventory_changed() -> void:
	if Global.battery_items > _last_battery_count:
		_show_toast("Picked up a Battery! Press R to use.")

	if Global.fish_items > _last_fish_count:
		_show_toast("Caught a Fish! Click the Backpack to eat.")

	var current_shovel_count = _get_shovel_count()
	if current_shovel_count > _last_shovel_count:
		_show_toast("Shovel added to your backpack!")

	_last_battery_count = Global.battery_items
	_last_fish_count = Global.fish_items
	_last_shovel_count = current_shovel_count

	_refresh_inventory()


# ---------------- TOKENS ----------------

func setup_tokens() -> void:
	for t in TOKENS:
		var slot = Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = t["title"]

		var box = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 1)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(box)

		var icon = TextureRect.new()
		if ResourceLoader.exists(t["path"]):
			icon.texture = load(t["path"])

		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

		box.add_child(_make_slot_label(t["label"]))
		grid.add_child(slot)
		token_slots[t["id"]] = slot

	_refresh_tokens()


func _refresh_tokens() -> void:
	for id in token_slots.keys():
		var slot = token_slots[id]
		if is_instance_valid(slot):
			slot.visible = Global.has_token(id)


func _on_token_claimed(_province: String) -> void:
	_refresh_tokens()


# ---------------- ITEM USE ----------------

func use_battery_item() -> void:
	var james = get_tree().get_first_node_in_group("player")
	if james == null or james.is_dead:
		return

	if not james.in_night_scene:
		_show_toast("Batteries can only be used in the Shortway.")
		return

	if james.battery >= james.max_battery - 0.5:
		_show_toast("Battery is already full.")
		return

	if not Global.consume_battery():
		_show_toast("No batteries in your backpack.")
		return

	james.restore_battery(BATTERY_ITEM_RESTORE)
	_show_toast("+%d Battery" % int(BATTERY_ITEM_RESTORE))


func use_fish_item() -> void:
	var james = get_tree().get_first_node_in_group("player")
	if james == null or james.is_dead:
		return

	if james.energy >= james.max_energy - 0.5 and james.health >= james.max_health - 0.5:
		_show_toast("Health and Energy are already full.")
		return

	if not Global.consume_fish():
		_show_toast("No fish in your backpack.")
		return

	james.restore_energy(FISH_ITEM_RESTORE)
	james.heal(FISH_ITEM_RESTORE)
	_show_toast("+%d Health  +%d Energy" % [
		int(FISH_ITEM_RESTORE),
		int(FISH_ITEM_RESTORE)
	])


# ---------------- JOURNAL TAB ----------------

func setup_journal_tab() -> void:
	var journal_tab_node = get_node_or_null("BackpackPopup/TabContainer/Journal")
	if journal_tab_node == null:
		return

	journal_scroll = journal_tab_node.get_node_or_null("ScrollContainer")
	if journal_scroll == null:
		journal_scroll = ScrollContainer.new()
		journal_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		journal_scroll.offset_left = 15
		journal_scroll.offset_top = 15
		journal_scroll.offset_right = -15
		journal_scroll.offset_bottom = -15
		journal_tab_node.add_child(journal_scroll)

	journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	journal_vbox = journal_scroll.get_node_or_null("VBoxContainer")
	if journal_vbox == null:
		journal_vbox = VBoxContainer.new()
		journal_vbox.add_theme_constant_override("separation", 12)
		journal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journal_scroll.add_child(journal_vbox)

	journal_container = journal_vbox
	refresh_journal_display()


func refresh_journal_display() -> void:
	if not is_instance_valid(journal_container):
		return

	for child in journal_container.get_children():
		child.queue_free()

	var custom_font = load(UI_FONT_PATH)

	var provinces = [
		{"id": "south_cotabato", "name": "South Cotabato (T'nalak Weaving - Bai Linay)"},
		{"id": "sarangani", "name": "Sarangani (Maitum Burial Jars - Ayu)"},
		{"id": "sultan_kudarat", "name": "Sultan Kudarat (Isulan Capitol - Ustadz Ameer)"},
		{"id": "cotabato_province", "name": "Cotabato Province (Mt. Apo - Apo Sandawa)"}
	]

	for prov in provinces:
		var prov_title = Label.new()
		prov_title.text = prov["name"]
		prov_title.add_theme_font_size_override("font_size", 7)
		prov_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		prov_title.autowrap_mode = TextServer.AUTOWRAP_WORD
		prov_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if custom_font:
			prov_title.add_theme_font_override("font", custom_font)

		journal_container.add_child(prov_title)

		var entries = Global.get_journal_entries(prov["id"])

		if entries.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "No entries unlocked yet."
			empty_lbl.add_theme_font_size_override("font_size", 6)
			empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			if custom_font:
				empty_lbl.add_theme_font_override("font", custom_font)

			journal_container.add_child(empty_lbl)
		else:
			for entry in entries:
				var title_lbl = Label.new()
				title_lbl.text = "- " + str(entry["title"])
				title_lbl.add_theme_font_size_override("font_size", 6)
				title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
				title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				if custom_font:
					title_lbl.add_theme_font_override("font", custom_font)

				journal_container.add_child(title_lbl)

				var desc_lbl = Label.new()
				desc_lbl.text = str(entry["content"])
				desc_lbl.add_theme_font_size_override("font_size", 6)
				desc_lbl.add_theme_color_override("font_color", Color.WHITE)
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				if custom_font:
					desc_lbl.add_theme_font_override("font", custom_font)

				journal_container.add_child(desc_lbl)

		var spacer = Label.new()
		spacer.text = "--------------------------------------------------"
		spacer.add_theme_font_size_override("font_size", 5)
		spacer.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		journal_container.add_child(spacer)


func _on_journal_updated(_province: String) -> void:
	refresh_journal_display()


# ---------------- TOAST ----------------

func setup_toast() -> void:
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 1)

	var font = load(UI_FONT_PATH)
	if font:
		toast_label.add_theme_font_override("font", font)

	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	toast_label.z_index = 200
	add_child(toast_label)


func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_label.reset_size()

	var viewport_size = get_viewport().get_visible_rect().size
	toast_label.position = Vector2(
		(viewport_size.x - toast_label.size.x) / 2.0,
		viewport_size.y * 0.8
	)

	toast_token += 1
	var my_token = toast_token

	await get_tree().create_timer(1.8).timeout

	if my_token == toast_token and is_instance_valid(toast_label):
		toast_label.visible = false


# ---------------- PLAYER / INPUT ----------------

func _find_player() -> void:
	var james = get_tree().get_first_node_in_group("player")

	if james:
		minimap.player = james
		james.energy_bar = get_tree().get_first_node_in_group("energy_bar")
		james.battery_bar = get_tree().get_first_node_in_group("battery_bar")
		james.battery_box = get_tree().get_first_node_in_group("battery_box")

		if is_instance_valid(james.battery_box):
			james.battery_box.visible = james.is_night_scene()
	else:
		print("James not found in group!")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		minimap.visible = not minimap.visible

	if event.is_action_pressed("pause_game"):
		is_paused = not is_paused
		get_tree().paused = is_paused
		pause_label.visible = is_paused

	if not is_paused:
		if InputMap.has_action("use_battery"):
			if event.is_action_pressed("use_battery"):
				use_battery_item()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			use_battery_item()


func _on_settings_pressed() -> void:
	settings.toggle()


func _on_backpack_pressed() -> void:
	backpack_popup.visible = not backpack_popup.visible

	if backpack_popup.visible:
		refresh_journal_display()
		_refresh_tokens()
		_refresh_inventory()


func _select_seed(item_id: String) -> void:
	if Global.get_backpack_item_count(item_id) <= 0:
		_show_toast("You don't have this item.")
		return

	var james := get_tree().get_first_node_in_group("player")

	Global.selected_seed = item_id
	Global.shovel_equipped = false
	Global.watering_can_equipped = false

	if james != null:
		james.is_holding_shovel = false
		james.is_holding_watering_can = false
		james.update_held_shovel()
		james.update_held_watering_can()

	match item_id:
		"eggplant_seeds":
			_show_toast("Eggplant Seeds selected.")
		"corn_seeds":
			_show_toast("Corn Seeds selected.")
		"pineapple_crown":
			_show_toast("Pineapple Crown selected.")


func _toggle_shovel() -> void:
	if int(Global.inventory_items.get("shovel", 0)) <= 0:
		_show_toast("You don't have a shovel!")
		return

	var james = get_tree().get_first_node_in_group("player")
	if james == null:
		return

	Global.shovel_equipped = not Global.shovel_equipped

	if Global.shovel_equipped:
		# Unequip the watering can.
		Global.watering_can_equipped = false
		james.is_holding_watering_can = false
		james.update_held_watering_can()

		james.is_holding_shovel = true
		james.update_held_shovel()
		_show_toast("Shovel equipped!")
	else:
		james.is_holding_shovel = false
		james.update_held_shovel()
		_show_toast("Shovel unequipped!")



func _toggle_watering_can() -> void:
	var james = get_tree().get_first_node_in_group("player")

	if james == null:
		return

	if int(Global.inventory_items.get("watering_can", 0)) <= 0:
		_show_toast("You don't have a watering can.")
		return

	Global.watering_can_equipped = not Global.watering_can_equipped

	if Global.watering_can_equipped:
		Global.shovel_equipped = false
		james.is_holding_shovel = false
		james.is_holding_watering_can = true
	else:
		james.is_holding_watering_can = false

	james.update_held_shovel()
	james.update_held_watering_can()

	if Global.watering_can_equipped:
		_show_toast("Watering can equipped!")
	else:
		_show_toast("Watering can unequipped!")



func _on_close_pressed() -> void:
	backpack_popup.visible = false


func _on_quest_log_button_pressed() -> void:
	if is_instance_valid(quest_log):
		if quest_log.has_method("toggle"):
			quest_log.call("toggle")
		elif quest_log.has_method("_toggle"):
			quest_log.call("_toggle")
		else:
			push_warning("QuestLog has no toggle() or _toggle() method.")
