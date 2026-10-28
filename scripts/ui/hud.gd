extends CanvasLayer

@onready var backpack_button = $Backpack
@onready var backpack_popup = $BackpackPopup
@onready var close_button = $BackpackPopup/Button
@onready var tabs: TabContainer = $BackpackPopup/TabContainer
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

# ---- BACKPACK UI ASSETS ----
const PANEL_INVENTORY_PATH: String = "res://assets/ui/Backpack_panel_Inventory.png"
const PANEL_JOURNAL_PATH: String = "res://assets/ui/Journal_panel.png"
const SLOT_TEXTURE_PATH: String = "res://assets/ui/Item_slot.png"
const TAB_TEXTURE_PATH: String = "res://assets/ui/Tap_Button.png"
const CLOSE_TEXTURE_PATH: String = "res://assets/ui/Close_Button.png"

# ---- BACKPACK UI SETTINGS (dito mo i-adjust kung may lihis) ----
# Laki ng bawat panel sa screen (units ng game). Taasan = mas malaki.
const INVENTORY_PANEL_SIZE: Vector2 = Vector2(250, 95)
const JOURNAL_PANEL_SIZE: Vector2 = Vector2(240, 136)
# Galaw ng buong backpack mula sa gitna ng screen (x = kanan, y = baba)
const BACKPACK_OFFSET: Vector2 = Vector2(0, 10)
# Area ng laman, sa porsyento ng MISMONG panel: Rect2(x, y, width, height)
const INVENTORY_CONTENT_RECT: Rect2 = Rect2(0.09, 0.17, 0.82, 0.68)
# Journal: nasa left page lang ang text (para hindi tumawid sa spine)
const JOURNAL_CONTENT_RECT: Rect2 = Rect2(0.10, 0.16, 0.38, 0.68)

# Tabs (Inventory / Journal) na nasa ibabaw ng panel
const TAB_SIZE: Vector2 = Vector2(56, 18)
const TAB_START_X: float = 10.0     # layo mula sa kaliwang gilid ng panel
const TAB_GAP: float = 2.0
const TAB_OVERLAP: float = 3.0      # gaano kalalim ang pasok ng tab sa panel
const TAB_FONT_SIZE: int = 6

# Close button sa kanan taas
const CLOSE_SIZE: Vector2 = Vector2(34, 16)
const CLOSE_MARGIN_RIGHT: float = 8.0
const CLOSE_FONT_SIZE: int = 6

# Tint ng tabs
const TAB_SELECTED_TINT: Color = Color(1.0, 0.85, 0.45, 1)
const TAB_UNSELECTED_TINT: Color = Color(0.75, 0.68, 0.58, 1)

# Kulay ng text (dark kasi light parchment ang background)
const COLOR_INK: Color = Color("#3B2412")
const COLOR_COUNT: Color = Color("#7A3E00")
const COLOR_JOURNAL_PROVINCE: Color = Color("#1F4A7A")
const COLOR_JOURNAL_ENTRY: Color = Color("#A01818")
const COLOR_JOURNAL_EMPTY: Color = Color("#7A6A55")
const COLOR_JOURNAL_LINE: Color = Color("#B8A27A")

const TOKENS: Array = [
	{"id": "south_cotabato", "label": "S. Cotabato", "title": "South Cotabato Token", "path": "res://assets/images/tokens/token_southcotabato.png"},
	{"id": "sarangani", "label": "Sarangani", "title": "Sarangani Token", "path": "res://assets/images/tokens/token_sarangani.png"},
	{"id": "sultan_kudarat", "label": "S. Kudarat", "title": "Sultan Kudarat Token", "path": "res://assets/images/tokens/token_sultankudarat.png"},
	{"id": "cotabato_province", "label": "Cotabato", "title": "Cotabato Province Token", "path": "res://assets/images/tokens/token_cotabatoprovince.png"}
]

const SLOT_SIZE: Vector2 = Vector2(38, 44)
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

var _slot_tex: Texture2D = null
var _panel_inventory_tex: Texture2D = null
var _panel_journal_tex: Texture2D = null

var _skin: TextureRect = null
var _tab_buttons: Array = []
var _art_pos: Vector2 = Vector2.ZERO
var _art_size: Vector2 = Vector2(250, 95)


func _ready() -> void:
	backpack_popup.visible = false
	minimap.visible = true
	pause_label.visible = false

	add_to_group("hud")
	call_deferred("_find_player")

	# May check muna kung connected na (iwas "already connected" error)
	if not backpack_button.pressed.is_connected(_on_backpack_pressed):
		backpack_button.pressed.connect(_on_backpack_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not quest_log_button.pressed.is_connected(_on_quest_log_button_pressed):
		quest_log_button.pressed.connect(_on_quest_log_button_pressed)

	# Load + crop ng textures bago gumawa ng slots
	_slot_tex = _crop_to_art(_load_tex(SLOT_TEXTURE_PATH))
	_panel_inventory_tex = _crop_to_art(_load_tex(PANEL_INVENTORY_PATH))
	_panel_journal_tex = _crop_to_art(_load_tex(PANEL_JOURNAL_PATH))

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
	_apply_backpack_ui()


func _exit_tree() -> void:
	if is_instance_valid(Global):
		if Global.inventory_changed.is_connected(_on_inventory_changed):
			Global.inventory_changed.disconnect(_on_inventory_changed)

		if Global.journal_updated.is_connected(_on_journal_updated):
			Global.journal_updated.disconnect(_on_journal_updated)

		if Global.token_claimed.is_connected(_on_token_claimed):
			Global.token_claimed.disconnect(_on_token_claimed)


# ---------------- BACKPACK UI SKIN ----------------

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("UI texture not found: " + path)
	return null


# Gupitin ang transparent margin ng image, yung mismong drawing lang ang matitira
func _crop_to_art(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_compressed():
		return tex

	var w: int = img.get_width()
	var h: int = img.get_height()
	var small: Image = img.duplicate()
	var ratio: float = minf(1.0, 256.0 / float(maxi(w, h)))
	if ratio < 1.0:
		small.resize(maxi(1, int(w * ratio)), maxi(1, int(h * ratio)), Image.INTERPOLATE_NEAREST)

	var sw: int = small.get_width()
	var sh: int = small.get_height()
	var min_x: int = 99999
	var min_y: int = 99999
	var max_x: int = -1
	var max_y: int = -1
	for y in range(sh):
		for x in range(sw):
			if small.get_pixel(x, y).a > 0.5:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return tex

	var fx: float = float(w) / float(sw)
	var fy: float = float(h) / float(sh)
	var x0: int = maxi(0, int(floor((min_x - 1) * fx)))
	var y0: int = maxi(0, int(floor((min_y - 1) * fy)))
	var x1: int = mini(w, int(ceil((max_x + 2) * fx)))
	var y1: int = mini(h, int(ceil((max_y + 2) * fy)))

	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(x0, y0, x1 - x0, y1 - y0)
	return at


# StyleBoxTexture na buong image ang ini-stretch (walang hati)
func _make_full_box(tex: Texture2D, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	return sb


# Lagyan ng slot image ang isang item button
func _style_slot_button(slot: Button) -> void:
	if _slot_tex == null:
		return
	slot.add_theme_stylebox_override("normal", _make_full_box(_slot_tex))
	slot.add_theme_stylebox_override("hover", _make_full_box(_slot_tex, Color(1.1, 1.05, 0.9, 1)))
	slot.add_theme_stylebox_override("pressed", _make_full_box(_slot_tex, Color(0.85, 0.8, 0.7, 1)))
	slot.add_theme_stylebox_override("disabled", _make_full_box(_slot_tex, Color(0.8, 0.78, 0.74, 1)))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# Porsyento ng panel -> totoong posisyon/laki sa screen
func _art_to_screen(r: Rect2) -> Rect2:
	return Rect2(
		_art_pos + Vector2(r.position.x * _art_size.x, r.position.y * _art_size.y),
		Vector2(r.size.x * _art_size.x, r.size.y * _art_size.y))


func _apply_backpack_ui() -> void:
	# Pixel art: huwag i-blur
	backpack_popup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 1) Tanggalin ang lumang plain na background ng BackpackPopup
	if backpack_popup is Panel or backpack_popup is PanelContainer:
		backpack_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	elif backpack_popup is ColorRect:
		backpack_popup.color = Color(0, 0, 0, 0)

	# Gawing buong screen ang popup (para ako ang magpoposisyon ng laman). Hindi ito haharang sa clicks.
	backpack_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backpack_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 2) Background ng panel (nasa pinakailalim)
	_skin = TextureRect.new()
	_skin.name = "BackpackSkin"
	_skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skin.stretch_mode = TextureRect.STRETCH_SCALE
	_skin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backpack_popup.add_child(_skin)
	backpack_popup.move_child(_skin, 0)

	# 3) Itago ang default na tab bar at panel ng TabContainer
	tabs.tabs_visible = false
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# 4) Sariling tab buttons
	var tab_tex := _crop_to_art(_load_tex(TAB_TEXTURE_PATH))
	var tab_names: Array = ["Inventory", "Journal"]
	var font: Font = null
	if ResourceLoader.exists(UI_FONT_PATH):
		font = load(UI_FONT_PATH) as Font

	for i in range(tab_names.size()):
		var tb := TextureButton.new()
		tb.texture_normal = tab_tex
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.focus_mode = Control.FOCUS_NONE
		tb.size = TAB_SIZE
		tb.custom_minimum_size = TAB_SIZE
		tb.pressed.connect(_select_backpack_tab.bind(i))
		backpack_popup.add_child(tb)

		var lbl := Label.new()
		lbl.text = tab_names[i]
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
		lbl.add_theme_color_override("font_color", COLOR_INK)
		if font:
			lbl.add_theme_font_override("font", font)
		tb.add_child(lbl)

		_tab_buttons.append(tb)

	# 5) Close button (buong image, walang hati)
	var close_tex := _crop_to_art(_load_tex(CLOSE_TEXTURE_PATH))
	if close_tex != null:
		close_button.add_theme_stylebox_override("normal", _make_full_box(close_tex))
		close_button.add_theme_stylebox_override("hover", _make_full_box(close_tex, Color(1.1, 1.05, 0.9, 1)))
		close_button.add_theme_stylebox_override("pressed", _make_full_box(close_tex, Color(0.85, 0.8, 0.7, 1)))
		close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.add_theme_font_size_override("font_size", CLOSE_FONT_SIZE)
	close_button.add_theme_color_override("font_color", COLOR_INK)
	close_button.add_theme_color_override("font_hover_color", COLOR_JOURNAL_ENTRY)
	close_button.add_theme_color_override("font_pressed_color", COLOR_INK)
	if font:
		close_button.add_theme_font_override("font", font)
	close_button.focus_mode = Control.FOCUS_NONE
	# Dapat nasa ibabaw ng panel at tabs
	backpack_popup.move_child(close_button, backpack_popup.get_child_count() - 1)

	# 6) Palit ng panel kapag nagpalit ng tab
	if not tabs.tab_changed.is_connected(_on_tab_changed):
		tabs.tab_changed.connect(_on_tab_changed)
	_on_tab_changed(tabs.current_tab)

	# 7) I-style ang mga slot na nagawa na
	for child in grid.get_children():
		if child is Button:
			_style_slot_button(child)


func _select_backpack_tab(i: int) -> void:
	tabs.current_tab = i
	_on_tab_changed(i)


func _on_tab_changed(index: int) -> void:
	_layout_backpack(index)
	for i in range(_tab_buttons.size()):
		var tb: TextureButton = _tab_buttons[i]
		tb.modulate = TAB_SELECTED_TINT if i == index else TAB_UNSELECTED_TINT


# Ayusin ang posisyon ng panel, tabs, laman at close button
func _layout_backpack(index: int) -> void:
	if _skin == null:
		return

	var tex: Texture2D = _panel_journal_tex if index == 1 else _panel_inventory_tex
	if tex == null:
		return
	_skin.texture = tex

	var panel_size: Vector2 = JOURNAL_PANEL_SIZE if index == 1 else INVENTORY_PANEL_SIZE
	var content_rect: Rect2 = JOURNAL_CONTENT_RECT if index == 1 else INVENTORY_CONTENT_RECT

	var vp := get_viewport().get_visible_rect().size
	_art_size = panel_size
	_art_pos = (vp - panel_size) / 2.0 + BACKPACK_OFFSET

	# Panel image
	_skin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_skin.position = _art_pos
	_skin.size = panel_size

	# Laman (slots / journal)
	var content := _art_to_screen(content_rect)
	tabs.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tabs.position = content.position
	tabs.size = content.size

	# Tabs sa ibabaw ng panel
	for i in range(_tab_buttons.size()):
		var tb: TextureButton = _tab_buttons[i]
		tb.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tb.size = TAB_SIZE
		tb.position = Vector2(
			_art_pos.x + TAB_START_X + i * (TAB_SIZE.x + TAB_GAP),
			_art_pos.y - TAB_SIZE.y + TAB_OVERLAP)

	# Close button sa kanan taas
	close_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	close_button.size = CLOSE_SIZE
	close_button.position = Vector2(
		_art_pos.x + _art_size.x - CLOSE_SIZE.x - CLOSE_MARGIN_RIGHT,
		_art_pos.y - CLOSE_SIZE.y + TAB_OVERLAP)


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
	lbl.add_theme_color_override("font_color", COLOR_INK)

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
	_style_slot_button(slot)

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
	name_label.custom_minimum_size = Vector2(SLOT_SIZE.x - 6, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var count_label := _make_slot_label("x%d" % amount)
	count_label.add_theme_color_override("font_color", COLOR_COUNT)
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
		_style_slot_button(slot)

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
		journal_scroll.offset_left = 0
		journal_scroll.offset_top = 0
		journal_scroll.offset_right = 0
		journal_scroll.offset_bottom = 0
		journal_tab_node.add_child(journal_scroll)

	journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	journal_vbox = journal_scroll.get_node_or_null("VBoxContainer")
	if journal_vbox == null:
		journal_vbox = VBoxContainer.new()
		journal_vbox.add_theme_constant_override("separation", 6)
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
		prov_title.add_theme_color_override("font_color", COLOR_JOURNAL_PROVINCE)
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
			empty_lbl.add_theme_color_override("font_color", COLOR_JOURNAL_EMPTY)
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
				title_lbl.add_theme_color_override("font_color", COLOR_JOURNAL_ENTRY)
				title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				if custom_font:
					title_lbl.add_theme_font_override("font", custom_font)

				journal_container.add_child(title_lbl)

				var desc_lbl = Label.new()
				desc_lbl.text = str(entry["content"])
				desc_lbl.add_theme_font_size_override("font_size", 6)
				desc_lbl.add_theme_color_override("font_color", COLOR_INK)
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				if custom_font:
					desc_lbl.add_theme_font_override("font", custom_font)

				journal_container.add_child(desc_lbl)

		var spacer = Label.new()
		spacer.text = "------------------------------"
		spacer.add_theme_font_size_override("font_size", 5)
		spacer.add_theme_color_override("font_color", COLOR_JOURNAL_LINE)
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
	MusicManager.play_button_sfx()
	settings.toggle()


func _on_backpack_pressed() -> void:
	backpack_popup.visible = not backpack_popup.visible

	if backpack_popup.visible:
		_layout_backpack(tabs.current_tab)
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


# Quest icon: bubuksan/isasara ang quest popup.
# Ang sfx (quest_icon_pop_up.mp3) ay nasa quest_log.gd na, kaya walang MusicManager sfx dito.
func _on_quest_log_button_pressed() -> void:
	if is_instance_valid(quest_log):
		if quest_log.has_method("toggle"):
			quest_log.call("toggle")
		elif quest_log.has_method("_toggle"):
			quest_log.call("_toggle")
		else:
			push_warning("QuestLog has no toggle() or _toggle() method.")
			
## dipatapos
