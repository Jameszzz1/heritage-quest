extends VBoxContainer
# Achievements list (scroll pataas at pababa)
# Bawat entry: pangalan ng badge (taas) -> maliit na badge (kaliwa) + description (katabi ng badge)
# Ang listahan ng 14 badge ay galing sa Global.BADGES (global.gd), kaya isang lugar lang ang babaguhin.
# Ang id ng badge ay dapat KAPAREHO ng nasa Supabase (user_progress.unlocked_badges)
#
# LIT/DARK: unang kinukuha ang badges mula sa Global.unlocked_badges (local, instant),
# tapos ime-merge ang galing sa Supabase kapag may session.

# ---------- LAYOUT (puwedeng baguhin sa Inspector) ----------
@export var badge_size: Vector2 = Vector2(40, 44)   # laki ng badge (palakihin/liitan dito)
@export var badge_indent: int = 5          # gaano kalayo sa kaliwa ang badge kumpara sa pangalan
@export var badge_text_gap: int = 12       # pagitan ng badge at description
@export var entry_gap: int = 6             # pagitan ng bawat badge entry
@export var title_font_size: int = 8
@export var desc_font_size: int = 7
@export var title_color: Color = Color(1.0, 0.9, 0.3)
@export var desc_color: Color = Color.WHITE
@export_enum("Center", "Top") var desc_align: int = 0   # Center = nasa gitna ng badge, Top = nasa taas ng badge
@export var desc_width: float = 0.0        # 0 = awtomatiko (sumusunod sa laki ng scroll area)
@export var desc_max_width: float = 190.0  # hanggang saan lang ang haba ng description bago mag-wrap sa susunod na linya
@export var scrollbar_reserve: float = 24.0   # espasyo para sa scrollbar sa kanan
@export var ui_font: Font                  # kung wala, kukunin ang font ng lumang label

# ---------- SCROLL ----------
@export var scroll_step: int = 24          # gaano kalayo ang galaw kada ikot ng mouse wheel
@export var invert_scroll: bool = false    # i-tick kung baligtad ang scroll
@export var move_under_title: bool = true       # ilalagay ang listahan sa ilalim mismo ng ACHIEVEMENTS na title
@export var title_node_name: String = "ACHIEVEMENTS"   # pangalan ng title node sa scene
@export var top_gap: float = 4.0                # espasyo sa pagitan ng title at ng unang badge
@export var manual_offset_y: float = 0.0        # dagdag na galaw: negatibo = pataas, positibo = pababa
@export var fit_scroll_to_screen: bool = true   # liliitin ang scroll area kung lampas sa screen
@export var screen_margin: float = 6.0
@export var bottom_padding: float = 12.0   # dagdag na espasyo sa pinakadulo para hindi putol ang huling badge

var unlocked_list: Array = []
var _font: Font = null
var _scroll: ScrollContainer = null
var _scroll_width: float = 0.0
var _desc_labels: Array[Label] = []
var _bottom_pad: Control = null

func _ready():
	unlocked_list = []
	_setup_scroll()
	await get_tree().process_frame   # hintayin munang ma-layout ang scroll area
	_move_under_title()
	if fit_scroll_to_screen:
		_fit_scroll_to_screen()
	if _scroll != null:
		_scroll_width = _scroll.size.x   # isang beses lang kukunin para hindi nagbabago ang lapad
	_bring_back_button_to_front()
	build_list()
	await get_tree().process_frame
	_add_bottom_safety()   # sigurado na maaabot ang huling badge kahit lampas sa screen ang scroll area

	# 1) Agad: ilawan ang badges na nasa Global (local save), hindi na hihintayin ang internet
	_sync_from_global()

	# Live update kapag may bagong badge habang nakabukas ang screen
	if not Global.badge_unlocked.is_connected(_on_badge_unlocked):
		Global.badge_unlocked.connect(_on_badge_unlocked)

	# 2) Pagkatapos: i-merge ang galing sa Supabase
	await wait_for_session()
	await load_from_supabase()

func _exit_tree():
	if Global.badge_unlocked.is_connected(_on_badge_unlocked):
		Global.badge_unlocked.disconnect(_on_badge_unlocked)

func _on_badge_unlocked(_id: String) -> void:
	_sync_from_global()

func _sync_from_global() -> void:
	for b in Global.unlocked_badges:
		if not unlocked_list.has(b):
			unlocked_list.append(b)
	print("🏅 Badges mula sa Global: ", unlocked_list)
	update_ui_icons()

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

# Itinataas ang scroll area para nasa ilalim mismo ng title ang unang badge
func _move_under_title() -> void:
	if _scroll == null or not move_under_title:
		return
	var parent = _scroll.get_parent()
	if parent == null:
		return
	var title = parent.find_child(title_node_name, true, false)
	if title == null or not (title is Control):
		print("⚠️ Hindi makita ang title node '", title_node_name, "', hindi mailipat pataas.")
		return
	var gs: Vector2 = _scroll.get_global_transform().get_scale()
	var title_bottom: float = (title as Control).get_global_rect().end.y
	var target_y: float = title_bottom + top_gap * gs.y + manual_offset_y
	_scroll.global_position.y = target_y
	print("⬆️ Nailipat ang listahan sa y = ", target_y)

func _fit_scroll_to_screen():
	if _scroll == null:
		return
	var screen = get_viewport_rect().size
	var gs: Vector2 = _scroll.get_global_transform().get_scale()   # kung naka-scale ang parent
	var r = _scroll.get_global_rect()
	var max_h = (screen.y - r.position.y - screen_margin) / maxf(gs.y, 0.01)
	var max_w = (screen.x - r.position.x - screen_margin) / maxf(gs.x, 0.01)
	if max_h > 40.0 and _scroll.size.y > max_h:
		_scroll.size.y = max_h
	if max_w > 80.0 and _scroll.size.x > max_w:
		_scroll.size.x = max_w

# Kung lampas pa rin sa screen ang ilalim ng scroll area, dinadagdagan ang espasyo sa dulo
# ng listahan para ma-scroll pa ito pataas at lumabas ang huling badge.
func _add_bottom_safety() -> void:
	if _scroll == null or _bottom_pad == null:
		return
	var screen = get_viewport_rect().size
	var gs: Vector2 = _scroll.get_global_transform().get_scale()
	var bottom_global = _scroll.get_global_rect().position.y + _scroll.size.y * gs.y
	var overflow = bottom_global - (screen.y - screen_margin)
	var extra := 0.0
	if overflow > 0.0:
		extra = overflow / maxf(gs.y, 0.01)
	_bottom_pad.custom_minimum_size = Vector2(0, bottom_padding + extra)
	print("📐 Scroll bottom overflow: ", overflow, " | extra pad: ", extra)

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
	# Ang listahan ng badge ay galing sa Global (global.gd)
	var entries: Array = Global.BADGES.duplicate(true)

	# Proteksyon: huwag burahin ang laman kung wala tayong mabuong entry
	if entries.is_empty():
		print("⚠️ Walang laman ang Global.BADGES.")
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
	_bottom_pad = Control.new()
	_bottom_pad.custom_minimum_size = Vector2(0, bottom_padding)
	_bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom_pad)

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
	desc_lbl.text = str(e.get("short", e.get("description", "")))   # isang sentence lang dito
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
	w = minf(w, desc_max_width)
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

# ---------------- SUPABASE ----------------

func _has_session() -> bool:
	return Supabase.auth != null and Supabase.auth._session != null and Supabase.auth._session.has("user")

# Kukunin ang user id: una sa Global (galing login), kung wala, sa Supabase session
func _get_user_id() -> String:
	if Global.cloud_user_id != "":
		return Global.cloud_user_id
	if _has_session():
		return str(Supabase.auth._session["user"]["id"])
	return ""

func wait_for_session():
	# Kung kilala na ang user id mula sa login, hindi na kailangang maghintay
	if Global.cloud_user_id != "":
		return
	var tries = 0
	while not _has_session() and tries < 15:
		print("⏳ Waiting for session (Try ", tries, ")...")
		await get_tree().create_timer(0.5).timeout
		tries += 1

	if not _has_session():
		print("❌ FAILED: Session not ready.")
	else:
		print("✅ Session ready!")

func load_from_supabase():
	var user_id := _get_user_id()
	if user_id == "":
		print("❌ No valid user id found (naka-login ka ba?).")
		return
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
		# Kunin ang unlocked_badges array mula sa unang row at i-merge sa mayroon na
		var badges = final_data[0].get("unlocked_badges", [])
		if badges is Array:
			for b in badges:
				if not unlocked_list.has(b):
					unlocked_list.append(b)
		print("✅ Badges Found: ", unlocked_list)
		update_ui_icons()
	else:
		print("❌ No row found for user or empty data. (Gagamitin ang local badges: ", unlocked_list, ")")

# ---------------- LIT / DARK ----------------

func update_ui_icons():
	recursive_apply_logic(self)

func recursive_apply_logic(node):
	for child in node.get_children():
		if child is TextureRect:
			var badge_id = str(child.get_meta("badge_id", child.name))
			if unlocked_list.has(badge_id):
				child.modulate = Color(1, 1, 1, 1) # Lit
			else:
				child.modulate = Color(0.15, 0.15, 0.15, 1) # Dark

		if child.get_child_count() > 0:
			recursive_apply_logic(child)
