extends Control
# Quest Log: button sa taas kanan (sa tabi ng gear) + popup na may listahan ng quest.
# Gawa sa code, walang node na kailangang idagdag sa hud.tscn.

# ---- SETTINGS ----
const FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const TITLE_FONT_SIZE := 9
const TEXT_FONT_SIZE := 7
const BUTTON_FONT_SIZE := 6
const PANEL_SIZE := Vector2(270, 135)
const PANEL_BG_ALPHA := 0.75

const COLOR_DONE := "#6bd16b"
const COLOR_CURRENT := "#ffe14d"
const COLOR_TODO := "#ffffff"

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
var _panel: PanelContainer
var _list_buttons: Array = []
var _detail_title: Label
var _detail_text: RichTextLabel
var _selected: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create only the quest popup.
	_build_panel()
	_panel.visible = false

	Global.journal_updated.connect(func(_p): _refresh())
	Global.token_claimed.connect(func(_p): _refresh())
	Global.inventory_changed.connect(_refresh)

	call_deferred("_track_current_scene")

# Itala ang scene na kinaroroonan ngayon ng player
func _track_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		Global.mark_scene_visited(scene.scene_file_path)

# ---------------- UI BUILD ----------------

func _style_label(lbl: Control, font_size: int, color: Color = Color.WHITE) -> void:
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)

func _make_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "QuestPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.z_index = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, PANEL_BG_ALPHA)
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	_panel.add_child(root)

	# Header: pamagat + close
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Quest"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, TITLE_FONT_SIZE)
	header.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	_style_label(close, BUTTON_FONT_SIZE)
	close.pressed.connect(_close)
	header.add_child(close)

	# Body: kaliwa = listahan ng quest, kanan = steps
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(70, 0)
	left.add_theme_constant_override("separation", 3)
	body.add_child(left)
	for i in range(QUESTS.size()):
		var b := Button.new()
		b.text = QUESTS[i]["title"]
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_label(b, BUTTON_FONT_SIZE)
		b.pressed.connect(_select.bind(i))
		left.add_child(b)
		_list_buttons.append(b)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	body.add_child(right)

	_detail_title = Label.new()
	_style_label(_detail_title, TEXT_FONT_SIZE + 1, Color(1.0, 0.9, 0.3))
	right.add_child(_detail_title)

	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = false
	_detail_text.scroll_active = false
	_detail_text.custom_minimum_size = Vector2(150, 80)
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.add_theme_font_size_override("normal_font_size", TEXT_FONT_SIZE)
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
		var b: Button = _list_buttons[i]
		b.visible = _is_unlocked(i)
		b.text = ("[x] " if finished else "") + QUESTS[i]["title"]
		var col := Color(0.42, 0.82, 0.42) if finished else (Color(1.0, 0.9, 0.3) if i == _selected else Color.WHITE)
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", col)
		b.add_theme_color_override("font_pressed_color", col)

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
