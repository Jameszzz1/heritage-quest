extends CanvasLayer
@onready var backpack_button = $Backpack
@onready var backpack_popup = $BackpackPopup
@onready var close_button = $BackpackPopup/Button
@onready var grid = $BackpackPopup/TabContainer/Inventory/GridContainer
@onready var minimap = $MiniMap
@onready var settings = $Settings
@onready var pause_label = $PauseLabel
var is_paused: bool = false

# Ilan ang naibabalik ng 1 battery item sa bar
const BATTERY_ITEM_RESTORE: float = 30.0
# Ilan ang naibabalik ng 1 fish item sa Energy at Health
const FISH_ITEM_RESTORE: float = 25.0

const BATTERY_ICON_PATH: String = "res://assets/sprites/things/battery.png"
const FISH_ICON_PATH: String = "res://assets/sprites/things/item_fish.png"
const UI_FONT_PATH: String = "res://assets/fonts/GrapeSoda.ttf"

# ---- Laki ng UI ----
const SLOT_SIZE: Vector2 = Vector2(28, 30)
const ICON_SIZE: int = 16
const SLOT_FONT_SIZE: int = 5
const TOAST_FONT_SIZE: int = 6
const SHOW_COUNT: bool = true

var death_screen: ColorRect
var death_countdown_label: Label

var battery_slot: Button
var battery_count_label: Label
var fish_slot: Button
var fish_count_label: Label
var toast_label: Label
var toast_token: int = 0
var _last_battery_count: int = 0
var _last_fish_count: int = 0

# Journal variables
var journal_container: Control = null
var journal_scroll: ScrollContainer
var journal_vbox: VBoxContainer

func _ready():
	backpack_popup.visible = false
	minimap.visible = true
	pause_label.visible = false
	add_to_group("hud")
	call_deferred("_find_player")
	backpack_button.pressed.connect(_on_backpack_pressed)
	close_button.pressed.connect(_on_close_pressed)
	setup_death_overlay()

	_last_battery_count = Global.battery_items
	_last_fish_count = Global.fish_items
	setup_inventory()
	setup_toast()

	Global.inventory_changed.connect(_on_inventory_changed)
	Global.journal_updated.connect(_on_journal_updated)
	setup_journal_tab()

func setup_death_overlay():
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

func _center_countdown_label():
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
		death_countdown_label.text = "Respawning in " + str(seconds_left) + ""
		_center_countdown_label()
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1

	death_countdown_label.visible = false
	death_screen.color = Color(0, 0, 0, 0)

# ---------------- INVENTORY SLOT HELPERS ----------------

func _make_slot_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	var font = load(UI_FONT_PATH)
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _build_slot(icon_path: String, label_text: String, on_press: Callable) -> Dictionary:
	var slot = Button.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.tooltip_text = ""
	if on_press.is_valid():
		slot.pressed.connect(on_press)

	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)

	var icon = TextureRect.new()
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	box.add_child(_make_slot_label(label_text))

	var count_label = _make_slot_label("x1")
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	count_label.offset_left = 0
	count_label.offset_right = -2
	count_label.offset_top = 1
	count_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	count_label.visible = SHOW_COUNT
	slot.add_child(count_label)

	return {"slot": slot, "count_label": count_label}

func setup_inventory():
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	# Battery slot
	var battery_built = _build_slot(BATTERY_ICON_PATH, "Battery", use_battery_item)
	battery_slot = battery_built["slot"]
	battery_count_label = battery_built["count_label"]
	grid.add_child(battery_slot)

	# Fish slot (click to eat → +Health +Energy)
	var fish_built = _build_slot(FISH_ICON_PATH, "Fish", use_fish_item)
	fish_slot = fish_built["slot"]
	fish_count_label = fish_built["count_label"]
	grid.add_child(fish_slot)

	_refresh_inventory()

func _refresh_inventory():
	if is_instance_valid(battery_slot):
		battery_slot.visible = Global.battery_items > 0
		if is_instance_valid(battery_count_label):
			battery_count_label.text = "x%d" % Global.battery_items

	if is_instance_valid(fish_slot):
		fish_slot.visible = Global.fish_items > 0
		if is_instance_valid(fish_count_label):
			fish_count_label.text = "x%d" % Global.fish_items

func _on_inventory_changed():
	if Global.battery_items > _last_battery_count:
		_show_toast("Picked up a Battery! Press R to use.")
	if Global.fish_items > _last_fish_count:
		_show_toast("Caught a Fish! Click sa Backpack para kainin.")

	_last_battery_count = Global.battery_items
	_last_fish_count = Global.fish_items
	_refresh_inventory()

func use_battery_item():
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

func use_fish_item():
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
	_show_toast("+%d Health  +%d Energy" % [int(FISH_ITEM_RESTORE), int(FISH_ITEM_RESTORE)])

# ---------------- JOURNAL TAB ----------------

func setup_journal_tab():
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

func refresh_journal_display():
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
		prov_title.text = "=== " + prov["name"] + " ==="
		prov_title.add_theme_font_size_override("font_size", 7)
		prov_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		if custom_font:
			prov_title.add_theme_font_override("font", custom_font)
		journal_container.add_child(prov_title)

		var entries = Global.get_journal_entries(prov["id"])

		if entries.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "[ Empty / Naka-lock — Kailangan ng 5/5 Assessment sa NPC ]"
			empty_lbl.add_theme_font_size_override("font_size", 6)
			empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			if custom_font:
				empty_lbl.add_theme_font_override("font", custom_font)
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			journal_container.add_child(empty_lbl)
		else:
			for entry in entries:
				var title_lbl = Label.new()
				title_lbl.text = "• " + entry["title"]
				title_lbl.add_theme_font_size_override("font_size", 6)
				title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
				if custom_font:
					title_lbl.add_theme_font_override("font", custom_font)
				journal_container.add_child(title_lbl)

				var desc_lbl = Label.new()
				desc_lbl.text = entry["content"]
				desc_lbl.add_theme_font_size_override("font_size", 6)
				desc_lbl.add_theme_color_override("font_color", Color.WHITE)
				if custom_font:
					desc_lbl.add_theme_font_override("font", custom_font)
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				journal_container.add_child(desc_lbl)

		var spacer = Label.new()
		spacer.text = "--------------------------------------------------"
		spacer.add_theme_font_size_override("font_size", 5)
		spacer.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		journal_container.add_child(spacer)

func _on_journal_updated(_province: String):
	refresh_journal_display()

# ---------------- TOAST ----------------

func setup_toast():
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

func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.reset_size()
	var vs = get_viewport().get_visible_rect().size
	toast_label.position = Vector2((vs.x - toast_label.size.x) / 2.0, vs.y * 0.8)

	toast_token += 1
	var my_token = toast_token
	await get_tree().create_timer(1.8).timeout
	if my_token == toast_token and is_instance_valid(toast_label):
		toast_label.visible = false

# ---------------- PLAYER / INPUT ----------------

func _find_player():
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

func _unhandled_input(event):
	if event.is_action_pressed("toggle_map"):
		minimap.visible = !minimap.visible
	if event.is_action_pressed("pause_game"):
		is_paused = !is_paused
		get_tree().paused = is_paused
		pause_label.visible = is_paused

	if not is_paused:
		if InputMap.has_action("use_battery"):
			if event.is_action_pressed("use_battery"):
				use_battery_item()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			use_battery_item()

func _on_settings_pressed():
	settings.toggle()

func _on_backpack_pressed():
	backpack_popup.visible = !backpack_popup.visible
	if backpack_popup.visible:
		refresh_journal_display()

func _on_close_pressed():
	backpack_popup.visible = false
