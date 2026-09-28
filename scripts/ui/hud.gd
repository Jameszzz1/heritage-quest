extends CanvasLayer
# HUD script: handles the backpack and inventory, the journal tab,
# the death screen, toast messages, the minimap toggle, and pause.

# ---------- NODE REFERENCES ----------

@onready var backpack_button = $Backpack
@onready var backpack_popup = $BackpackPopup
@onready var close_button = $BackpackPopup/Button
@onready var grid = $BackpackPopup/TabContainer/Inventory/GridContainer
@onready var minimap = $MiniMap
@onready var settings = $Settings
@onready var pause_label = $PauseLabel

var is_paused: bool = false

# ---------- CONSTANTS ----------

# How much battery charge one battery item restores
const BATTERY_ITEM_RESTORE: float = 30.0
const BATTERY_ICON_PATH: String = "res://assets/sprites/things/battery.png"
const UI_FONT_PATH: String = "res://assets/fonts/GrapeSoda.ttf"

# ---- UI sizes ----
const SLOT_SIZE: Vector2 = Vector2(28, 30)   # Size of one inventory slot
const ICON_SIZE: int = 16                    # Size of the item icon inside a slot
const SLOT_FONT_SIZE: int = 5
const TOAST_FONT_SIZE: int = 6
const SHOW_COUNT: bool = true                # Show the item count (e.g. "x3") on the slot

# ---------- DEATH SCREEN ----------

var death_screen: ColorRect                  # Dark overlay shown when the player dies
var death_countdown_label: Label             # "Respawning in X" text

# ---------- INVENTORY / TOAST ----------

var battery_slot: Button
var battery_count_label: Label
var toast_label: Label
var toast_token: int = 0                     # Used to tell which toast is the latest
var _last_battery_count: int = 0             # Used to detect when a new battery is picked up

# ---------- JOURNAL ----------

var journal_container: Control = null


# ---------- SETUP ----------

func _ready():
	# Hide popups and labels at the start
	backpack_popup.visible = false
	minimap.visible = true
	pause_label.visible = false

	add_to_group("hud")
	# Wait until the scene tree is ready before searching for the player
	call_deferred("_find_player")

	# Connect the button signals
	backpack_button.pressed.connect(_on_backpack_pressed)
	close_button.pressed.connect(_on_close_pressed)

	setup_death_overlay()

	_last_battery_count = Global.battery_items
	setup_inventory()
	setup_toast()

	# Listen to global signals so the UI updates automatically
	Global.inventory_changed.connect(_on_inventory_changed)
	Global.journal_updated.connect(_on_journal_updated)
	setup_journal_tab()


# ---------- DEATH SEQUENCE ----------

# Creates the death overlay and countdown label (both hidden until needed)
func setup_death_overlay():
	# Full-screen black rectangle, fully transparent at the start
	death_screen = ColorRect.new()
	death_screen.color = Color(0, 0, 0, 0)
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Do not block mouse clicks
	death_screen.z_index = 4096                              # Draw on top of everything
	add_child(death_screen)

	# Countdown text shown while waiting to respawn
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

# Centers the countdown label on the screen
func _center_countdown_label():
	var viewport_size = get_viewport().get_visible_rect().size
	death_countdown_label.reset_size()  # Recalculate size based on the current text
	var label_size = death_countdown_label.size
	death_countdown_label.position = (viewport_size - label_size) / 2.0

# Fades the screen to dark, then runs a 10-second respawn countdown
func show_death_sequence() -> void:
	# Fade the overlay from transparent to 60% black over 1 second
	var tween = create_tween()
	tween.tween_property(death_screen, "color", Color(0, 0, 0, 0.6), 1.0)
	await tween.finished

	# Countdown: update the text once every second
	death_countdown_label.visible = true
	var seconds_left = 10
	while seconds_left > 0:
		death_countdown_label.text = "Respawning in " + str(seconds_left) + ""
		_center_countdown_label()
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1

	# Countdown finished: hide the label and reset the overlay
	death_countdown_label.visible = false
	death_screen.color = Color(0, 0, 0, 0)


# ---------------- INVENTORY ----------------

# Helper: creates a small text label styled for inventory slots
func _make_slot_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	var font = load(UI_FONT_PATH)
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to the slot button
	return lbl

# Builds the battery slot (icon, name, and count) and adds it to the inventory grid
func setup_inventory():
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	# The slot itself is a button, so clicking it uses the battery
	battery_slot = Button.new()
	battery_slot.custom_minimum_size = SLOT_SIZE
	battery_slot.focus_mode = Control.FOCUS_NONE
	battery_slot.tooltip_text = ""
	battery_slot.pressed.connect(use_battery_item)

	# Vertical container that stacks the icon on top of the item name
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battery_slot.add_child(box)

	# Battery icon (only loaded if the file exists, to avoid errors)
	var icon = TextureRect.new()
	if ResourceLoader.exists(BATTERY_ICON_PATH):
		icon.texture = load(BATTERY_ICON_PATH)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	# Item name below the icon
	box.add_child(_make_slot_label("Battery"))

	# Item count ("x1") shown in the top-right corner of the slot, in yellow
	battery_count_label = _make_slot_label("x1")
	battery_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battery_count_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	battery_count_label.offset_left = 0
	battery_count_label.offset_right = -2
	battery_count_label.offset_top = 1
	battery_count_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	battery_count_label.visible = SHOW_COUNT
	battery_slot.add_child(battery_count_label)

	grid.add_child(battery_slot)
	_refresh_inventory()

# Updates the slot: hides it when there are no batteries, otherwise shows the count
func _refresh_inventory():
	if not is_instance_valid(battery_slot):
		return
	battery_slot.visible = Global.battery_items > 0
	if is_instance_valid(battery_count_label):
		battery_count_label.text = "x%d" % Global.battery_items

# Called whenever the global inventory changes
func _on_inventory_changed():
	# Show a message only if the battery count went UP (item was picked up)
	if Global.battery_items > _last_battery_count:
		_show_toast("Picked up a Battery! Press R to use.")
	_last_battery_count = Global.battery_items
	_refresh_inventory()

# Uses one battery item to recharge the player's flashlight battery
func use_battery_item():
	var james = get_tree().get_first_node_in_group("player")
	# Do nothing if the player is missing or dead
	if james == null or james.is_dead:
		return
	# Batteries only work in the night scene
	if not james.in_night_scene:
		_show_toast("Batteries can only be used in the Shortway.")
		return
	# Do not waste a battery if the charge is already (almost) full
	if james.battery >= james.max_battery - 0.5:
		_show_toast("Battery is already full.")
		return
	# Try to remove one battery from the inventory; stop if there is none
	if not Global.consume_battery():
		_show_toast("No batteries in your backpack.")
		return

	james.restore_battery(BATTERY_ITEM_RESTORE)
	_show_toast("+%d Battery" % int(BATTERY_ITEM_RESTORE))


# ---------------- JOURNAL TAB (all provinces listed) ----------------

var journal_scroll: ScrollContainer
var journal_vbox: VBoxContainer

# Finds or creates the ScrollContainer and VBoxContainer used by the Journal tab
func setup_journal_tab():
	var journal_tab_node = get_node_or_null("BackpackPopup/TabContainer/Journal")
	if journal_tab_node == null:
		return  # No Journal tab in the scene, so nothing to set up

	# Use the existing ScrollContainer if there is one, otherwise create it
	journal_scroll = journal_tab_node.get_node_or_null("ScrollContainer")
	if journal_scroll == null:
		journal_scroll = ScrollContainer.new()
		journal_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		journal_scroll.offset_left = 15
		journal_scroll.offset_top = 15
		journal_scroll.offset_right = -15
		journal_scroll.offset_bottom = -15
		journal_tab_node.add_child(journal_scroll)

	# Vertical scrolling only (no horizontal scrolling)
	journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	# Use the existing VBoxContainer if there is one, otherwise create it
	journal_vbox = journal_scroll.get_node_or_null("VBoxContainer")
	if journal_vbox == null:
		journal_vbox = VBoxContainer.new()
		journal_vbox.add_theme_constant_override("separation", 12)
		journal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journal_scroll.add_child(journal_vbox)

	journal_container = journal_vbox
	refresh_journal_display()

# Rebuilds the whole journal display from the data stored in Global
func refresh_journal_display():
	if not is_instance_valid(journal_container):
		return

	# Remove the old entries before rebuilding
	for child in journal_container.get_children():
		child.queue_free()

	var custom_font = load(UI_FONT_PATH)

	# List of all four provinces (id is used to look up entries in Global)
	var provinces = [
		{"id": "south_cotabato", "name": "South Cotabato  Bai Linay"},
		{"id": "sarangani", "name": "Sarangani  Ayu"},
		{"id": "sultan_kudarat", "name": "Sultan Kudarat  Ustadz Ameer"},
		{"id": "cotabato_province", "name": "Cotabato Province  Sandawa"}
	]

	for prov in provinces:
		# Province header
		var prov_title = Label.new()
		prov_title.text = "" + prov["name"] + ""
		prov_title.add_theme_font_size_override("font_size", 7)
		prov_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		if custom_font:
			prov_title.add_theme_font_override("font", custom_font)
		journal_container.add_child(prov_title)

		# Get the journal entries for this province from Global
		# (falls back to an empty list if the function does not exist)
		var entries = Global.get_journal_entries(prov["id"]) if Global.has_method("get_journal_entries") else []

		if entries.is_empty():
			# No entries yet: show a locked message
			var empty_lbl = Label.new()
			empty_lbl.text = ""
			empty_lbl.add_theme_font_size_override("font_size", 6)
			empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			if custom_font:
				empty_lbl.add_theme_font_override("font", custom_font)
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			journal_container.add_child(empty_lbl)
		else:
			# Unlocked: show each entry's title (yellow) and content (white)
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

		# Divider line between provinces
		var spacer = Label.new()
		spacer.text = "--------------------------------------------------"
		spacer.add_theme_font_size_override("font_size", 5)
		spacer.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		journal_container.add_child(spacer)

# Called when the journal is updated (the province argument is not used here)
func _on_journal_updated(_province: String):
	refresh_journal_display()


# ---------------- TOAST (temporary on-screen messages) ----------------

# Creates the toast label (hidden until a message is shown)
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

# Shows a message near the bottom of the screen for 1.8 seconds
func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.reset_size()
	# Horizontally centered, at 80% of the screen height
	var vs = get_viewport().get_visible_rect().size
	toast_label.position = Vector2((vs.x - toast_label.size.x) / 2.0, vs.y * 0.8)

	# Token check: if a newer toast appears before this one ends,
	# the older one will not hide the newer message early
	toast_token += 1
	var my_token = toast_token
	await get_tree().create_timer(1.8).timeout
	if my_token == toast_token and is_instance_valid(toast_label):
		toast_label.visible = false


# ---------------- PLAYER / INPUT ----------------

# Finds the player and connects the HUD elements to it
func _find_player():
	var james = get_tree().get_first_node_in_group("player")
	if james:
		minimap.player = james
		# Give the player references to the HUD bars
		james.energy_bar = get_tree().get_first_node_in_group("energy_bar")
		james.battery_bar = get_tree().get_first_node_in_group("battery_bar")
		james.battery_box = get_tree().get_first_node_in_group("battery_box")
		# Only show the battery box in night scenes
		if is_instance_valid(james.battery_box):
			james.battery_box.visible = james.is_night_scene()
	else:
		print("James not found in group!")

func _unhandled_input(event):
	# Toggle the minimap
	if event.is_action_pressed("toggle_map"):
		minimap.visible = !minimap.visible

	# Toggle pause (also shows or hides the "PAUSED" label)
	if event.is_action_pressed("pause_game"):
		is_paused = !is_paused
		get_tree().paused = is_paused
		pause_label.visible = is_paused

	# Battery hotkey only works while the game is not paused
	if not is_paused:
		if InputMap.has_action("use_battery"):
			# Use the custom "use_battery" action if it exists in the Input Map
			if event.is_action_pressed("use_battery"):
				use_battery_item()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			# Fallback: use the R key if the action is not set up
			use_battery_item()

func _on_settings_pressed():
	settings.toggle()

# Open or close the backpack; refresh the journal each time it opens
func _on_backpack_pressed():
	backpack_popup.visible = !backpack_popup.visible
	if backpack_popup.visible:
		refresh_journal_display()

func _on_close_pressed():
	backpack_popup.visible = false
