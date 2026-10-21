extends CanvasLayer
# BadgeManager (AUTOLOAD)
# Isang lugar lang para sa lahat ng badge: listahan, unlock, save sa Supabase, at pop-up.
# Gamitin kahit saan:  BadgeManager.unlock_badge("south_cotabato_historian")

signal badge_unlocked(id: String)

# ---- POPUP SETTINGS ----
const FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const SHOW_SECONDS := 3.0
const POPUP_WIDTH := 150.0      # lapad ng description (palakihin kung masikip)
const POPUP_TOP_MARGIN := 8.0
const ICON_SIZE := Vector2(28, 30)
const HEADER_FONT_SIZE := 6
const TITLE_FONT_SIZE := 8
const DESC_FONT_SIZE := 6

# ---- 14 BADGES (id ang sine-save sa Supabase: user_progress.unlocked_badges) ----
const BADGES: Array = [
	{"id": "south_cotabato_historian", "title": "South Cotabato Historian",
	 "description": "Correctly answered the T'boli cultural question and registered the lore in the Discovery Journal.",
	 "icon": "res://assets/images/badges/1.Badge_South_Cotabato_Historian.png"},
	{"id": "dreamweaver_apprentice", "title": "Dreamweaver Apprentice",
	 "description": "Completed Rhythmweaving with a 50-combo streak and 150,000 points, and got the South Cotabato Token.",
	 "icon": "res://assets/images/badges/2_Dreamweaver Apprentice.png"},
	{"id": "sarangani_archaeologist", "title": "Sarangani Archaeologist",
	 "description": "Correctly answered the Ayub Cave historical question and saved the artifact profile in the Journal.",
	 "icon": "res://assets/images/badges/3. Sarangani Archaeologist.png"},
	{"id": "keeper_of_the_anthropomorphic_jars", "title": "Keeper of the Anthropomorphic Jars",
	 "description": "Solved the Slide Puzzle in under 7 minutes and got the Sarangani Token.",
	 "icon": "res://assets/images/badges/4. Keeper of the Anthropomorphic Jars.png"},
	{"id": "sultan_kudarat_chronicler", "title": "Sultan Kudarat Chronicler",
	 "description": "Correctly answered the Islamic heritage and governance question.",
	 "icon": "res://assets/images/badges/5. Sultan Kudarat Chronicler.png"},
	{"id": "master_of_the_golden_grid", "title": "Master of the Golden Grid",
	 "description": "Scored 50,000 points in Tile-Matching within 7 minutes and got the Sultan Kudarat Token.",
	 "icon": "res://assets/images/badges/6. Master of the Golden Grid.png"},
	{"id": "highland_scholar", "title": "Highland Scholar",
	 "description": "Correctly answered the oral literature legend question and recorded the Mt. Apo lore.",
	 "icon": "res://assets/images/badges/7. Highland Scholar.png"},
	{"id": "mountain_climber_safe_descent", "title": "Mountain Climber & Safe Descent",
	 "description": "Reached the summit of Mt. Apo and finished the descent without taking damage. Got the Cotabato Province Token.",
	 "icon": "res://assets/images/badges/8. Peak Guardian & Swift Escape.png"},
	{"id": "resourceful_archivist", "title": "Resourceful Archivist",
	 "description": "Used fishing and farming to collect food resources into the Archivist Pack.",
	 "icon": "res://assets/images/badges/9.Resourceful Archivist.png"},
	{"id": "perfect_sustenance", "title": "Perfect Sustenance",
	 "description": "Restored both Health and Energy to 100% using recovery items.",
	 "icon": "res://assets/images/badges/10.Perfect Sustenance.png"},
	{"id": "apex_dodger", "title": "Apex Dodger",
	 "description": "Sprinted away from a hostile animal's attack without losing Health.",
	 "icon": "res://assets/images/badges/11. Apex Dodger.png"},
	{"id": "endurance_explorer", "title": "Endurance Explorer",
	 "description": "Kept Energy at 80% or higher for 2 minutes.",
	 "icon": "res://assets/images/badges/12.Endurance Explorer.png"},
	{"id": "chronicles_of_the_wild", "title": "Chronicles of the Wild",
	 "description": "Survived all four night scenes while tracking regional quests.",
	 "icon": "res://assets/images/badges/13. Chronicles of the Wild.png"},
	{"id": "soccsksargen_heritage_master", "title": "SOCCSKSARGEN Heritage Master",
	 "description": "Inserted all 4 regional Tokens into the Heritage Pillar and completed the Knowledge Vault.",
	 "icon": "res://assets/images/badges/14. SOCCSKSARGEN Heritage Master.png"},
]

var unlocked: Array = []
var _loaded := false
var _loading := false
var _row_exists := false
var _queue: Array = []
var _showing := false

var _panel: PanelContainer
var _icon: TextureRect
var _title_lbl: Label
var _desc_lbl: Label

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_popup()

# ---------------- PUBLIC ----------------

func get_badge(id: String) -> Dictionary:
	for b in BADGES:
		if b["id"] == id:
			return b
	return {}

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

# Tawagin kahit saan. Isang beses lang magpa-pop up ang bawat badge.
func unlock_badge(id: String) -> void:
	var data := get_badge(id)
	if data.is_empty():
		push_warning("BadgeManager: walang badge na may id '%s'" % id)
		return
	await _ensure_loaded()
	if unlocked.has(id):
		return
	unlocked.append(id)
	badge_unlocked.emit(id)
	_queue.append(data)
	_show_next()
	await _save()

# Para sa testing lang: buburahin lahat ng badge ng user
func debug_reset_all() -> void:
	await _ensure_loaded()
	unlocked.clear()
	await _save()

# ---------------- SUPABASE ----------------

func _user_id() -> String:
	if Supabase.auth == null or Supabase.auth._session == null:
		return ""
	if not Supabase.auth._session.has("user"):
		return ""
	return str(Supabase.auth._session["user"]["id"])

func _ensure_loaded() -> void:
	if _loaded:
		return
	if _loading:
		while _loading:
			await get_tree().process_frame
		return
	_loading = true
	_loaded = await _fetch()
	_loading = false

func _extract_rows(result) -> Array:
	if result is Array:
		return result
	if result is Dictionary and result.has("data"):
		return result["data"]
	if result is Object and "data" in result:
		return result.data
	return []

func _fetch() -> bool:
	var uid := _user_id()
	if uid == "":
		push_warning("BadgeManager: walang session, hindi makuha ang badges")
		return false
	var query = SupabaseQuery.new().from("user_progress").select(["unlocked_badges"]).eq("user_id", uid)
	var task = Supabase.database.query(query)
	var result = await task.completed
	var rows := _extract_rows(result)
	_row_exists = rows.size() > 0
	if _row_exists:
		var saved = rows[0].get("unlocked_badges", [])
		if saved is Array:
			for b in saved:
				if not unlocked.has(b):
					unlocked.append(b)
	print("BadgeManager: loaded ", unlocked)
	return true

func _save() -> void:
	var uid := _user_id()
	if uid == "":
		push_warning("BadgeManager: walang session, hindi nasave ang badge")
		return
	var query
	if _row_exists:
		query = SupabaseQuery.new().from("user_progress").update({"unlocked_badges": unlocked}).eq("user_id", uid)
	else:
		query = SupabaseQuery.new().from("user_progress").insert([{"user_id": uid, "unlocked_badges": unlocked}])
		_row_exists = true
	var task = Supabase.database.query(query)
	var result = await task.completed
	print("BadgeManager: save result -> ", result)

# ---------------- POPUP ----------------

func _build_popup() -> void:
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	sb.border_color = Color(1.0, 0.9, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var header := Label.new()
	header.text = "BADGE UNLOCKED!"
	_style(header, font, HEADER_FONT_SIZE, Color(0.6, 1.0, 0.6))
	col.add_child(header)

	_title_lbl = Label.new()
	_style(_title_lbl, font, TITLE_FONT_SIZE, Color(1.0, 0.9, 0.3))
	col.add_child(_title_lbl)

	_desc_lbl = Label.new()
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	_style(_desc_lbl, font, DESC_FONT_SIZE, Color.WHITE)
	col.add_child(_desc_lbl)

func _style(lbl: Label, font: Font, size: int, color: Color) -> void:
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_next() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	var data: Dictionary = _queue.pop_front()
	_title_lbl.text = data["title"]
	_desc_lbl.text = data["description"]
	var path: String = data["icon"]
	_icon.texture = load(path) if ResourceLoader.exists(path) else null

	_panel.visible = true
	_panel.reset_size()
	await get_tree().process_frame
	_panel.position.y = -_panel.size.y - 10.0

	var tw := create_tween()
	tw.tween_property(_panel, "position:y", POPUP_TOP_MARGIN, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(SHOW_SECONDS).timeout
	var tw2 := create_tween()
	tw2.tween_property(_panel, "position:y", -_panel.size.y - 10.0, 0.3)
	await tw2.finished

	_panel.visible = false
	_showing = false
	_show_next()
