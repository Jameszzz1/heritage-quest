class_name InstructionsPopup
extends Control

# =========================================================================
#  REUSABLE PROCEDURAL INSTRUCTIONS POPUP
#  Walang kailangang image asset - lahat drawn sa code. Gamit ang
#  GrapeSoda.ttf font mo. I-configure ang content bago i-add_child, tapos
#  makinig sa "dismissed" signal para simulan ang laro.
# =========================================================================

signal dismissed

@export var popup_title: String = "INSTRUCTIONS"
@export var popup_subtitle: String = ""
@export var steps: Array = []  # Array[Dictionary]: {"icon": String, "caption": String}
@export var start_hint: String = "Pindutin ang SPACE para magsimula"

var custom_font: Font = preload("res://assets/fonts/GrapeSoda.ttf")

var _blink_time: float = 0.0
var _hint_label: Label
var _closed: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build_ui()

func _process(delta: float) -> void:
	_blink_time += delta
	if _hint_label != null:
		_hint_label.modulate.a = 0.45 + 0.55 * sin(_blink_time * 4.0)

func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if _closed:
		return
	_closed = true
	dismissed.emit()
	queue_free()

# =========================================================================
#  UI BUILD
# =========================================================================
func _build_ui() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	# ---------- DIM BACKGROUND ----------
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# ---------- MAIN PARCHMENT PANEL ----------
	var panel_w: float = min(300.0, viewport_size.x - 24.0)
	var panel_h: float = 176.0

	var panel := Panel.new()
	panel.size = Vector2(panel_w, panel_h)
	panel.position = (viewport_size - panel.size) / 2.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#ecd9ae")
	panel_style.border_color = Color("#5c3d21")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# ---------- WOOD BANNER HEADER ----------
	var banner := Panel.new()
	banner.custom_minimum_size = Vector2(0, 28)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color("#3b2a1a")
	banner_style.border_color = Color("#20140c")
	banner_style.border_width_bottom = 2
	banner_style.corner_radius_top_left = 8
	banner_style.corner_radius_top_right = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	vbox.add_child(banner)

	var title_label := Label.new()
	title_label.text = popup_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_override("font", custom_font)
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color("#f5e6c8"))
	banner.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(spacer)

	# ---------- SUBTITLE ----------
	if popup_subtitle != "":
		var subtitle := Label.new()
		subtitle.text = popup_subtitle
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_override("font", custom_font)
		subtitle.add_theme_font_size_override("font_size", 12)
		subtitle.add_theme_color_override("font_color", Color("#5c3d21"))
		vbox.add_child(subtitle)

	# ---------- STEPS ROW ----------
	var steps_row := HBoxContainer.new()
	steps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	steps_row.add_theme_constant_override("separation", 6)
	steps_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(steps_row)

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		steps_row.add_child(_build_step_box(step))
		if i < steps.size() - 1:
			steps_row.add_child(_build_arrow())

	# ---------- START HINT ----------
	_hint_label = Label.new()
	_hint_label.text = start_hint
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_override("font", custom_font)
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color("#8a1f1f"))
	vbox.add_child(_hint_label)

func _build_step_box(step: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)

	var icon := IconBox.new()
	icon.icon_type = step.get("icon", "")
	icon.icon_font = custom_font
	icon.custom_minimum_size = Vector2(52, 46)
	box.add_child(icon)

	var caption := Label.new()
	caption.text = step.get("caption", "")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	caption.custom_minimum_size = Vector2(74, 0)
	caption.add_theme_font_override("font", custom_font)
	caption.add_theme_font_size_override("font_size", 8)
	caption.add_theme_color_override("font_color", Color("#3b2a1a"))
	box.add_child(caption)

	return box

func _build_arrow() -> Control:
	var arrow := ArrowIcon.new()
	arrow.custom_minimum_size = Vector2(18, 20)
	return arrow


# =========================================================================
#  ICON BOX - procedural pictograms (walang kailangang image file)
# =========================================================================
class IconBox extends Control:
	var icon_type: String = ""
	var icon_font: Font

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y

		draw_rect(Rect2(Vector2.ZERO, size), Color("#fff8e8"))
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("#5c3d21"), false, 2.0)

		match icon_type:
			"move":
				_draw_key("<", Vector2(w * 0.28, h * 0.5), false)
				_draw_key(">", Vector2(w * 0.72, h * 0.5), false)
			"jump", "start":
				_draw_key("SPACE", Vector2(w * 0.5, h * 0.5), true)
			"goal_up":
				_draw_chevrons(true)
			"goal_down":
				_draw_chevrons(false)
			"hazard":
				_draw_hazard()
			"rhythm_keys":
				_draw_rhythm_keys()
			"target":
				_draw_target()
			_:
				pass

	func _draw_key(txt: String, center: Vector2, wide: bool) -> void:
		var key_w: float = size.x * (0.82 if wide else 0.36)
		var key_h: float = size.y * 0.42
		var rect := Rect2(center - Vector2(key_w, key_h) / 2.0, Vector2(key_w, key_h))
		draw_rect(rect, Color("#e8c86b"))
		draw_rect(rect, Color("#8a5a1f"), false, 1.5)
		if icon_font != null:
			var font_size := 8
			var text_size: Vector2 = icon_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var draw_pos: Vector2 = center - text_size / 2.0 + Vector2(0, text_size.y * 0.32)
			draw_string(icon_font, draw_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#3b2a1a"))

	func _draw_chevrons(up: bool) -> void:
		var cx: float = size.x / 2.0
		var base_y: float = size.y * (0.75 if up else 0.25)
		var dir: float = -1.0 if up else 1.0
		for i in range(3):
			var y: float = base_y + dir * float(i) * 9.0
			var pts := PackedVector2Array([
				Vector2(cx - 12, y),
				Vector2(cx, y + dir * 8.0),
				Vector2(cx + 12, y)
			])
			draw_polyline(pts, Color("#2f6b2f"), 2.5, true)

	func _draw_rhythm_keys() -> void:
		var labels := ["D", "F", "J", "K"]
		var count: int = labels.size()
		var spacing: float = size.x / float(count)
		var key_w: float = spacing * 0.72
		var key_h: float = size.y * 0.42
		for i in range(count):
			var cx: float = spacing * (float(i) + 0.5)
			var cy: float = size.y * 0.5
			var rect := Rect2(Vector2(cx - key_w / 2.0, cy - key_h / 2.0), Vector2(key_w, key_h))
			draw_rect(rect, Color("#e8c86b"))
			draw_rect(rect, Color("#8a5a1f"), false, 1.3)
			if icon_font != null:
				var font_size := 7
				var text_size: Vector2 = icon_font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var draw_pos: Vector2 = Vector2(cx, cy) - text_size / 2.0 + Vector2(0, text_size.y * 0.32)
				draw_string(icon_font, draw_pos, labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#3b2a1a"))

	func _draw_target() -> void:
		var center := Vector2(size.x / 2.0, size.y / 2.0)
		draw_arc(center, size.y * 0.42, 0, TAU, 32, Color("#a11f1f"), 2.5, true)
		draw_arc(center, size.y * 0.27, 0, TAU, 32, Color("#e8c86b"), 2.5, true)
		draw_circle(center, size.y * 0.10, Color("#2f6b2f"))

	func _draw_hazard() -> void:
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		var pts := PackedVector2Array([
			Vector2(cx - 14, cy + 10),
			Vector2(cx - 5, cy - 9),
			Vector2(cx + 2, cy + 1),
			Vector2(cx + 14, cy - 10)
		])
		draw_polyline(pts, Color("#5c3d21"), 3.0, true)
		draw_line(Vector2(cx - 11, cy - 11), Vector2(cx + 11, cy + 11), Color("#a11f1f"), 2.5)
		draw_line(Vector2(cx - 11, cy + 11), Vector2(cx + 11, cy - 11), Color("#a11f1f"), 2.5)


# =========================================================================
#  ARROW ICON - separator sa pagitan ng mga steps
# =========================================================================
class ArrowIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([
			Vector2(0, h * 0.32),
			Vector2(w * 0.55, h * 0.32),
			Vector2(w * 0.55, h * 0.1),
			Vector2(w, h * 0.5),
			Vector2(w * 0.55, h * 0.9),
			Vector2(w * 0.55, h * 0.68),
			Vector2(0, h * 0.68)
		])
		draw_colored_polygon(pts, Color("#c2481c"))
