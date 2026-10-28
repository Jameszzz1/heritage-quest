extends Control
# Quest Log: button sa taas kanan (sa tabi ng gear) + popup na may listahan ng quest.
# Gawa sa code, walang node na kailangang idagdag sa hud.tscn.
# UI: parchment scroll panel + parchment scroll buttons (isang design lang para consistent).

# ---- ASSETS ----
const FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const PANEL_TEXTURE_PATH := "res://assets/sprites/things/ui_quest_pop_up_panel.png"
const BUTTON_TEXTURE_PATH := "res://assets/sprites/things/ui_quest_button.png"
const SFX_OPEN_PATH := "res://assets/audio/sfx/quest_icon_pop_up.mp3"

# ---- SETTINGS ----
const TITLE_FONT_SIZE := 9
const TEXT_FONT_SIZE := 7
const BUTTON_FONT_SIZE := 6
const CLOSE_FONT_SIZE := 8

# Gawing true para makita ang pula (title) at asul (X) na kahon pang-adjust
const DEBUG_LAYOUT := false

# Volume ng sfx pag nag-open (0 = normal, -6 = mas mahina, -12 = mas mahina pa)
const SFX_VOLUME_DB := 0.0

# Laki ng buong panel (16:9 para tugma sa image)
const PANEL_SIZE := Vector2(280, 158)
# Transparency ng scroll (1.0 = solid, 0.85 = konting transparent). Hindi apektado ang text.
const PANEL_ALPHA := 0.85

# Posisyon ng title at X, sa porsyento ng MISMONG SCROLL (hindi ng buong image)
# Rect2(x, y, width, height), 0.0 - 1.0
# Para i-adjust: x = kaliwa/kanan, y = taas/baba
const TITLE_RECT := Rect2(0.406, 0.113, 0.190, 0.075)  # loob ng ribbon
const CLOSE_RECT := Rect2(0.880, 0.118, 0.033, 0.070)  # loob ng kahon sa kanan taas

# Content area (listahan + steps), sa porsyento ng buong panel
const CONTENT_RECT := Rect2(0.11, 0.29, 0.78, 0.57)

# Laki ng NPC button (5:1 ratio)
const NPC_BUTTON_SIZE := Vector2(80, 16)

# Kulay ng text (dark kasi light parchment ang background)
const COLOR_INK := Color("#3B2412")        # normal / pamagat
const COLOR_DONE_TEXT := Color("#2E6B2E")  # tapos na (dark green)
const COLOR_CURRENT_TEXT := Color("#A01818") # kasalukuyang step (dark red)
const COLOR_DONE := "#2E6B2E"
const COLOR_CURRENT := "#A01818"
const COLOR_TODO := "#3B2412"

# Tint ng button
const BUTTON_NORMAL_TINT := Color(1, 1, 1, 1)
const BUTTON_SELECTED_TINT := Color(1.0, 0.82, 0.4, 1)  # golden kapag selected

# "minigame" = pangalan ng mini game sa step na "Play ..."
# "next_scene" = scene ng susunod na province; kapag napasok na, tapos ang "Proceed"
const QUESTS: Array = [
	{"title": "Bai Linay", "names": ["Bai Linay", "Bai linay", "Linay"], "province": "south_cotabato", "minigame": "Tnalak Rhythm",
	 "next_scene": "res://scenes/provinces/sarangani/sarangani.tscn"},
	{"title": "Ayu", "names": ["Ayu"], "province": "sarangani", "minigame": "Slide Puzzle Maitum Jar",
	 "next_scene": "res://scenes/provinces/sultan_kudarat/sultankudarat.tscn"},
	{"title": "Ameer", "names": ["Ustadz Ameer", "Ameer"], "province": "sultan_kudarat", "minigame": "Sultan Tile Matching",
	 "next_scene": "res://scenes/provinces/cotabato/cotabato.tscn"},
	{"title": "Sandawa", "names": ["Apo Sandawa", "Sandawa"], "province": "cotabato_province", "minigame": "Ascent and Descent",
	 "next_scene": ""},
]

var _font: Font = null
var _panel: TextureRect
var _list_buttons: Array = []   # TextureButton
var _list_labels: Array = []    # Label sa loob ng bawat button
var _detail_title: Label
var _detail_text: RichTextLabel
var _selected: int = 0
var _sfx_open: AudioStreamPlayer = null
# Totoong sakop ng scroll sa loob ng image (0.0 - 1.0), kinukuwenta sa _ready
var _art_rect := Rect2(0, 0, 1, 1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create only the quest popup.
	_build_panel()
	_panel.visible = false

	_build_sfx()

	Global.journal_updated.connect(func(_p): _refresh())
	Global.token_claimed.connect(func(_p): _refresh())
	Global.inventory_changed.connect(_refresh)

	call_deferred("_track_current_scene")

# Itala ang scene na kinaroroonan ngayon ng player
func _track_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		Global.mark_scene_visited(scene.scene_file_path)

# ---------------- SFX ----------------

func _build_sfx() -> void:
	_sfx_open = AudioStreamPlayer.new()
	_sfx_open.name = "SfxOpen"
	_sfx_open.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_open.volume_db = SFX_VOLUME_DB
	# Gamitin ang "SFX" bus kung meron, kung wala "Master"
	_sfx_open.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	if ResourceLoader.exists(SFX_OPEN_PATH):
		_sfx_open.stream = load(SFX_OPEN_PATH)
	else:
		push_warning("Quest SFX not found: " + SFX_OPEN_PATH)
	add_child(_sfx_open)

func _play_open_sfx() -> void:
	if _sfx_open != null and _sfx_open.stream != null:
		_sfx_open.play()

# ---------------- UI BUILD ----------------

func _style_label(lbl: Control, font_size: int, color: Color = COLOR_INK) -> void:
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)

# Ilagay ang isang Control sa porsyento ng parent niya (0.0 - 1.0)
func _place(c: Control, r: Rect2) -> void:
	c.anchor_left = r.position.x
	c.anchor_top = r.position.y
	c.anchor_right = r.position.x + r.size.x
	c.anchor_bottom = r.position.y + r.size.y
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0

# Hanapin kung saan talaga ang scroll sa loob ng image (iwas sa transparent margin)
func _compute_art_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2(0, 0, 1, 1)
	var img: Image = tex.get_image()
	if img == null or img.is_compressed():
		return Rect2(0, 0, 1, 1)
	img = img.duplicate()
	img.resize(200, 112, Image.INTERPOLATE_NEAREST)
	var min_x := 9999
	var min_y := 9999
	var max_x := -1
	var max_y := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < 0:
		return Rect2(0, 0, 1, 1)
	var w := float(img.get_width())
	var h := float(img.get_height())
	return Rect2(min_x / w, min_y / h, (max_x - min_x + 1) / w, (max_y - min_y + 1) / h)

# I-convert ang porsyento ng scroll papunta sa porsyento ng buong panel
func _art_to_panel(r: Rect2) -> Rect2:
	return Rect2(
		_art_rect.position.x + r.position.x * _art_rect.size.x,
		_art_rect.position.y + r.position.y * _art_rect.size.y,
		r.size.x * _art_rect.size.x,
		r.size.y * _art_rect.size.y)

func _add_debug_box(parent: Control, r: Rect2, color: Color) -> void:
	var cr := ColorRect.new()
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	_place(cr, r)

func _build_panel() -> void:
	# Background = parchment scroll image (self_modulate para ang image lang ang transparent)
	_panel = TextureRect.new()
	_panel.name = "QuestPanel"
	var tex: Texture2D = null
	if ResourceLoader.exists(PANEL_TEXTURE_PATH):
		tex = load(PANEL_TEXTURE_PATH)
		_panel.texture = tex
	_art_rect = _compute_art_rect(tex)
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.stretch_mode = TextureRect.STRETCH_SCALE
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.self_modulate = Color(1, 1, 1, PANEL_ALPHA)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.z_index = 100
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var title_rect := _art_to_panel(TITLE_RECT)
	var close_rect := _art_to_panel(CLOSE_RECT)

	if DEBUG_LAYOUT:
		_add_debug_box(_panel, title_rect, Color(1, 0, 0, 0.35))
		_add_debug_box(_panel, close_rect, Color(0, 0.3, 1, 0.35))

	# ---- Title "Quest" sa gitna ng ribbon ----
	var title := Label.new()
	title.text = "Quest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(title, TITLE_FONT_SIZE)
	_panel.add_child(title)
	_place(title, title_rect)

	# ---- Close button "X" sa loob ng kahon ----
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.clip_text = false
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		close.add_theme_stylebox_override(s, empty)
	_style_label(close, CLOSE_FONT_SIZE, COLOR_CURRENT_TEXT)
	close.add_theme_color_override("font_hover_color", Color("#D02020"))
	close.add_theme_color_override("font_pressed_color", COLOR_INK)
	close.pressed.connect(_close)
	_panel.add_child(close)
	_place(close, close_rect)

	# ---- Content area (listahan + steps) ----
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)
	_place(content, CONTENT_RECT)

	# Body: kaliwa = listahan ng quest, kanan = steps
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(NPC_BUTTON_SIZE.x, 0)
	left.add_theme_constant_override("separation", 3)
	body.add_child(left)

	var btn_tex: Texture2D = null
	if ResourceLoader.exists(BUTTON_TEXTURE_PATH):
		btn_tex = load(BUTTON_TEXTURE_PATH)

	for i in range(QUESTS.size()):
		var b := TextureButton.new()
		b.texture_normal = btn_tex
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.custom_minimum_size = NPC_BUTTON_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select.bind(i))
		left.add_child(b)

		# Text sa ibabaw ng button (kasi blangko ang image)
		var lbl := Label.new()
		lbl.text = QUESTS[i]["title"]
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(lbl, BUTTON_FONT_SIZE)
		b.add_child(lbl)

		_list_buttons.append(b)
		_list_labels.append(lbl)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	body.add_child(right)

	_detail_title = Label.new()
	_style_label(_detail_title, TEXT_FONT_SIZE + 1, COLOR_INK)
	right.add_child(_detail_title)

	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = false
	_detail_text.scroll_active = false
	_detail_text.custom_minimum_size = Vector2(120, 60)
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.add_theme_font_size_override("normal_font_size", TEXT_FONT_SIZE)
	_detail_text.add_theme_color_override("default_color", COLOR_INK)
	if _font:
		_detail_text.add_theme_font_override("normal_font", _font)
	right.add_child(_detail_text)

# ---------------- OPEN / CLOSE ----------------

func _toggle() -> void:
	if _panel.visible:
		_close()
	else:
		_open()

func _open() -> void:
	_selected = _first_unfinished_quest()
	_panel.visible = true
	_play_open_sfx()
	_refresh()

func _close() -> void:
	_panel.visible = false

func _select(i: int) -> void:
	if not _is_unlocked(i):
		return
	_selected = i
	_refresh()

# ---------------- PROGRESS CHECK ----------------

func _any_true(names: Array, fn: Callable) -> bool:
	for n in names:
		if fn.call(n):
			return true
	return false

func _is_met(idx: int) -> bool:
	var names: Array = QUESTS[idx]["names"]
	return _any_true(names, func(n): return Global.is_npc_met(n) or Global.is_culture_read(n) or Global.is_npc_completed(n))

# Tapos ang "Proceed" kapag nakapasok na sa scene ng next province (o nakausap na ang next NPC)
func _has_proceeded(idx: int) -> bool:
	var next_scene: String = QUESTS[idx]["next_scene"]
	if next_scene != "" and Global.has_visited_scene(next_scene):
		return true
	if idx < QUESTS.size() - 1:
		return _is_met(idx + 1)
	return false

# [find, learn, journal, minigame, token, (proceed - wala kay Sandawa)]
func _steps_done(idx: int) -> Array:
	var q: Dictionary = QUESTS[idx]
	var names: Array = q["names"]
	var has_token: bool = Global.has_token(q["province"])
	var steps: Array = [
		_is_met(idx),
		_any_true(names, func(n): return Global.is_culture_read(n) or Global.is_npc_completed(n)),
		_any_true(names, func(n): return Global.is_npc_completed(n)),
		_any_true(names, func(n): return Global.is_minigame_passed(n)),
		has_token,
	]
	if idx < QUESTS.size() - 1:
		steps.append(has_token and _has_proceeded(idx))
	return steps

func _step_texts(idx: int) -> Array:
	var q: Dictionary = QUESTS[idx]
	var title: String = q["title"]
	var is_last: bool = idx == QUESTS.size() - 1
	var texts: Array = [
		"Find " + title,
		"Learn from " + title,
		"Answer 5/5 to collect journal",
		"Play " + str(q["minigame"]),
		"Collect the Last Token" if is_last else "Collect token",
	]
	if not is_last:
		texts.append("Proceed to the next province")
	return texts

func _first_unfinished_quest() -> int:
	for i in range(QUESTS.size()):
		if false in _steps_done(i):
			return i
	return 0

# Unlocked lang ang quest kung tapos na (pati "Proceed") ang quest bago nito
func _is_unlocked(idx: int) -> bool:
	if idx == 0:
		return true
	return not (false in _steps_done(idx - 1))

# ---------------- RENDER ----------------

func _refresh() -> void:
	if _panel == null or not _panel.visible:
		return

	if not _is_unlocked(_selected):
		_selected = _first_unfinished_quest()

	for i in range(_list_buttons.size()):
		var done: Array = _steps_done(i)
		var finished: bool = not (false in done)
		var b: TextureButton = _list_buttons[i]
		var lbl: Label = _list_labels[i]

		# Hidden hanggang ma-unlock, tapos lalabas yung same button
		b.visible = _is_unlocked(i)

		# Golden tint kapag selected
		b.modulate = BUTTON_SELECTED_TINT if i == _selected else BUTTON_NORMAL_TINT

		lbl.text = ("[x] " if finished else "") + QUESTS[i]["title"]
		var col: Color = COLOR_DONE_TEXT if finished else COLOR_INK
		lbl.add_theme_color_override("font_color", col)

	var q: Dictionary = QUESTS[_selected]
	var steps: Array = _steps_done(_selected)
	var texts: Array = _step_texts(_selected)
	var count := 0
	for s in steps:
		if s:
			count += 1
	_detail_title.text = "Quest: " + q["title"] + "  (" + str(count) + "/" + str(steps.size()) + ")"

	var found_current := false
	var out := ""
	for i in range(texts.size()):
		if steps[i]:
			out += "[color=" + COLOR_DONE + "][s]" + texts[i] + "[/s][/color]\n"
		elif not found_current:
			found_current = true
			out += "[color=" + COLOR_CURRENT + "]> " + texts[i] + "[/color]\n"
		else:
			out += "[color=" + COLOR_TODO + "]" + texts[i] + "[/color]\n"
	_detail_text.text = out


func _on_quest_log_button_pressed() -> void:
	pass # Replace with function body.
