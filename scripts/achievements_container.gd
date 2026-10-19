extends VBoxContainer
# Achievements list (scroll pataas at pababa)
# Bawat entry: pangalan ng badge (taas) -> maliit na badge (kaliwa) + description (katabi ng badge)

# ---------- MGA BADGE ----------
# id          = dapat KAPAREHO ng nasa Supabase (user_progress.unlocked_badges)
# title       = pangalan na nasa ibabaw ng badge
# description = nasa kanan ng badge
# icon        = path ng badge image
# Kapag walang laman ito, kukunin muna ang mga lumang badge sa scene.
# Kapag naglagay ka ng entry, ito na ang gagamitin.
const ACHIEVEMENTS: Array = [
	# {"id": "01_FirstDiscovery", "title": "First Discovery", "description": "Interact with the first NPC in South Cotabato", "icon": "res://assets/images/badges/first_discovery.png"},
]

# ---------- LAYOUT (puwedeng baguhin sa Inspector) ----------
@export var badge_size: Vector2 = Vector2(26, 28)
@export var badge_indent: int = 5          # gaano kalayo sa kaliwa ang badge kumpara sa pangalan
@export var badge_text_gap: int = 12       # pagitan ng badge at description
@export var entry_gap: int = 10            # pagitan ng bawat badge entry
@export var title_font_size: int = 8
@export var desc_font_size: int = 6
@export var title_color: Color = Color(1.0, 0.9, 0.3)
@export var desc_color: Color = Color.WHITE
@export_enum("Center", "Top") var desc_align: int = 0   # Center = nasa gitna ng badge, Top = nasa taas ng badge
@export var desc_width: float = 0.0        # 0 = awtomatiko (sumusunod sa laki ng scroll area)
@export var scrollbar_reserve: float = 24.0   # espasyo para sa scrollbar sa kanan
@export var ui_font: Font                  # kung wala, kukunin ang font ng lumang label

# ---------- SCROLL ----------
@export var scroll_step: int = 24          # gaano kalayo ang galaw kada ikot ng mouse wheel
@export var invert_scroll: bool = false    # i-tick kung baligtad ang scroll
@export var fit_scroll_to_screen: bool = true   # liliitin ang scroll area kung lampas sa screen
@export var screen_margin: float = 6.0

var unlocked_list: Array = []
var _font: Font = null
var _scroll: ScrollContainer = null
var _scroll_width: float = 0.0
var _desc_labels: Array[Label] = []

func _ready():
	unlocked_list = []
	_setup_scroll()
	await get_tree().process_frame   # hintayin munang ma-layout ang scroll area
	if fit_scroll_to_screen:
		_fit_scroll_to_screen()
	if _scroll != null:
		_scroll_width = _scroll.size.x   # isang beses lang kukunin para hindi nagbabago ang lapad
	_bring_back_button_to_front()
	build_list()
	update_ui_icons() # Dark muna

	await wait_for_session()
	await load_from_supabase()

# ---------------- SCROLL ----------------

func _setup_scroll():
	# Hindi dapat humaharang sa click ang mga container na ito
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", entry_gap)
	var sc = get_parent()
	if sc is ScrollContainer:
		_scroll = sc
		# Pataas at pababa lang ang scroll, walang pakaliwa at pakanan
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.follow_focus = false
		# Pinapadaan ang click sa ilalim (para gumana ang Back button).
		# Gumagana pa rin ang scrollbar, at ang mouse wheel ay hawak ng _input sa ibaba.
		_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fit_scroll_to_screen():
	if _scroll == null:
		return
	var screen = get_viewport_rect().size
	var r = _scroll.get_global_rect()
	var max_h = screen.y - r.position.y - screen_margin
	var max_w = screen.x - r.position.x - screen_margin
	if max_h > 40.0 and r.size.y > max_h:
		_scroll.size.y = max_h
	if max_w > 80.0 and r.size.x > max_w:
		_scroll.size.x = max_w

# Ilalagay ang Back button sa pinakaibabaw para siya ang unang matamaan ng click
func _bring_back_button_to_front():
	var back: Node = null
	if _scroll != null and _scroll.get_parent() != null:
		back = _scroll.get_parent().find_child("Back", true, false)
	if back == null:
		var scene = get_tree().current_scene
		if scene != null:
			back = scene.find_child("Back", true, false)
	if back == null or not (back is Control):
		return
	var p = back.get_parent()
	if p != null:
		p.move_child(back, p.get_child_count() - 1)
	back.mouse_filter = Control.MOUSE_FILTER_STOP

# Mouse wheel (at touchpad): pababa = pababa ang scroll
func _input(event):
	if _scroll == null or not is_visible_in_tree():
		return

	var amount := 0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			amount = scroll_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			amount = -scroll_step
	elif event is InputEventPanGesture:
		amount = int(_scroll.size.y * event.delta.y / 8.0)

	if amount == 0:
		return
	if not _scroll.get_global_rect().has_point(get_global_mouse_position()):
		return

	if invert_scroll:
		amount = -amount
	_scroll.scroll_vertical += amount
	get_viewport().set_input_as_handled()

# ---------------- LAYOUT / BUILD ----------------

func build_list():
	var entries: Array = ACHIEVEMENTS.duplicate()
	if entries.is_empty():
		_collect_from_scene(self, entries)

	# Proteksyon: huwag burahin ang laman kung wala tayong mabuong entry
	if entries.is_empty():
		print("⚠️ Walang laman ang ACHIEVEMENTS at walang lumang badge sa scene.")
		return

	_font = ui_font
	if _font == null:
		var old_label = _find_first_label(self)
		if old_label != null:
			_font = old_label.get_theme_font("font")

	# Alisin ang lumang mga label, grid, at badge sa scene
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_desc_labels.clear()
	for e in entries:
		add_child(_make_entry(e))

	# Konting espasyo sa dulo para hindi putol ang huling badge
	var pad = Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)

	_update_desc_widths()
	if _scroll != null:
		_scroll.scroll_vertical = 0

func _make_entry(e: Dictionary) -> Control:
	var entry = VBoxContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_theme_constant_override("separation", 2)

	# Pangalan ng badge (nasa taas)
	var title_lbl = Label.new()
	title_lbl.text = str(e.get("title", e.get("id", "")))
	_style_label(title_lbl, title_font_size, title_color)
	entry.add_child(title_lbl)

	# Badge sa kaliwa (may konting indent), description sa kanan
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", badge_indent)
	entry.add_child(margin)

	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", badge_text_gap)
	margin.add_child(row)

	var vflag = Control.SIZE_SHRINK_CENTER if desc_align == 0 else Control.SIZE_SHRINK_BEGIN

	var badge = TextureRect.new()
	badge.set_meta("badge_id", str(e.get("id", "")))
	badge.texture = _get_texture(e.get("icon"))
	badge.custom_minimum_size = badge_size
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size_flags_vertical = vflag
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)

	# Fixed ang lapad ng description para hindi nagbabago ang taas ng entry habang nagsa-scroll
	var desc_lbl = Label.new()
	desc_lbl.text = str(e.get("description", ""))
	_style_label(desc_lbl, desc_font_size, desc_color)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_FILL
	desc_lbl.size_flags_vertical = vflag
	desc_lbl.custom_minimum_size = Vector2(_calc_desc_width(), 0)
	row.add_child(desc_lbl)
	_desc_labels.append(desc_lbl)

	return entry

func _calc_desc_width() -> float:
	if desc_width > 0.0:
		return desc_width
	var avail := _scroll_width if _scroll_width > 0.0 else 300.0
	# bawas: indent, badge, pagitan, scrollbar, at konting palugit
	var w = avail - badge_indent - badge_size.x - badge_text_gap - scrollbar_reserve
	return maxf(60.0, w)

func _update_desc_widths():
	var w = _calc_desc_width()
	for lbl in _desc_labels:
		if is_instance_valid(lbl):
			lbl.custom_minimum_size = Vector2(w, 0)

func _style_label(lbl: Label, fsize: int, color: Color):
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", color)
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # para gumana ang scroll gamit ang mouse wheel

func _get_texture(icon) -> Texture2D:
	if icon is Texture2D:
		return icon
	if icon is String and icon != "" and ResourceLoader.exists(icon):
		return load(icon)
	return null

func _find_first_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
		var found = _find_first_label(child)
		if found != null:
			return found
	return null

# Kukunin ang mga lumang badge sa scene (pangalan ng TextureRect = id, katabing Label = description)
func _collect_from_scene(node: Node, out: Array):
	for child in node.get_children():
		if child is TextureRect and child.texture != null:
			var badge_id = String(child.name)
			var prefix = badge_id.split("_")[0]   # hal. "01"
			var desc = ""
			for sib in node.get_children():
				if sib is Label and String(sib.name).begins_with(prefix):
					desc = sib.text.replace("\n", " ")
					break
			out.append({
				"id": badge_id,
				"title": _pretty_title(badge_id),
				"description": desc,
				"icon": child.texture
			})
		elif child.get_child_count() > 0:
			_collect_from_scene(child, out)

# "04_LakeSebuExplorer" -> "Lake Sebu Explorer"
func _pretty_title(badge_id: String) -> String:
	var t = badge_id
	var idx = t.find("_")
	if idx != -1 and t.substr(0, idx).is_valid_int():
		t = t.substr(idx + 1)
	var result = ""
	for i in t.length():
		var ch = t[i]
		if i > 0:
			var prev = t[i - 1]
			if ch != ch.to_lower() and prev != prev.to_upper():
				result += " "
		result += ch
	return result.replace("_", " ")

# ---------------- SUPABASE ----------------

func wait_for_session():
	var tries = 0
	while (Supabase.auth == null or Supabase.auth._session == null or not Supabase.auth._session.has("user")) and tries < 15:
		print("⏳ Waiting for session (Try ", tries, ")...")
		await get_tree().create_timer(0.5).timeout
		tries += 1
	
	if Supabase.auth._session == null or not Supabase.auth._session.has("user"):
		print("❌ FAILED: Session not ready.")
	else:
		print("✅ Session ready!")

func load_from_supabase():
	if Supabase.auth._session == null or not Supabase.auth._session.has("user"):
		print("❌ No valid session found.")
		return

	var user_id = Supabase.auth._session["user"]["id"]
	print("🎯 Target User ID: ", user_id)

	var query = SupabaseQuery.new().from("user_progress").select(["unlocked_badges"]).eq("user_id", user_id)
	var task = Supabase.database.query(query)
	
	# Hintayin ang task.completed signal
	var result = await task.completed

	print("--- DEBUG LOG ---")
	
	var final_data = []
	
	if result is Array:
		final_data = result
	elif result is Dictionary and result.has("data"):
		final_data = result["data"]
	elif result is Object:
		if "data" in result:
			final_data = result.data
		elif result.has_method("get_data"):
			final_data = result.get_data()

	print("EXTRACTED DATA: ", final_data)

	if final_data is Array and final_data.size() > 0:
		# Kunin ang unlocked_badges array mula sa unang row
		var badges = final_data[0].get("unlocked_badges", [])
		unlocked_list = badges if badges is Array else []
		print("✅ Badges Found: ", unlocked_list)
		update_ui_icons()
	else:
		print("❌ No row found for user or empty data.")

# ---------------- LIT / DARK ----------------

func update_ui_icons():
	recursive_apply_logic(self)

func recursive_apply_logic(node):
	for child in node.get_children():
		if child is TextureRect:
			var badge_id = str(child.get_meta("badge_id", child.name))
			if unlocked_list.has(badge_id):
				child.modulate = Color(1, 1, 1, 1) # Lit
				print("✨ Light ON: ", badge_id)
			else:
				child.modulate = Color(0.15, 0.15, 0.15, 1) # Dark
		
		if child.get_child_count() > 0:
			recursive_apply_logic(child)
