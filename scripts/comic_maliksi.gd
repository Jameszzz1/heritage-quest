extends Control

signal finished

const PREQUEL_PAGES := [
	"res://assets/comics/maliksi_story_1.png",
	"res://assets/comics/maliksi_story_2.png",
	"res://assets/comics/maliksi_story_3.png",
]

# Si Angkol Joey ang nagkukuwento, kaya first-person ang narration.
const PREQUEL_NARRATION := [
	[
		"Si Maliksi... dati ko siyang estudyante.",
		"Napakatalino niya. Magkasama naming binuo ang Archive,",
		"ang tahanan ng mga alaala ng SOCCSKSARGEN.",
	],
	[
		"Pero habang binabasa niya ang mga talaan ng digmaan at pagkawala,",
		"unti-unting bumigat ang loob niya.",
		"Hindi ko napansin kung gaano na siya kapagod. Iyon ang pinakamalaki kong pagkakamali.",
	],
	[
		"Isang gabi, hindi na niya nakayanan.",
		"Binura niya ang isang talaan, at nabasag ang Core Relic.",
		"Naging apat na Token ito na kumalat sa buong rehiyon.",
		"Mula noon, iisa na lang ang gusto niya: burahin ang lahat ng masakit na alaala.",
	],
]

# Popup lang ito. Walang lilipatang scene maliban kung itakda mo ang next_scene.
const DEFAULT_NEXT_SCENE := ""
const DEFAULT_SPEAKER := "Angkol Joey"
const FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const FADE_TIME := 0.3
const TYPING_SPEED := 0.03

# Laki ng text bilang porsyento ng taas ng screen (sumusunod sa resolution ng game).
const NARRATION_SIZE_RATIO := 0.05
const SKIP_SIZE_RATIO := 0.032

# Itakda ang mga ito bago i-add_child kung kailangan.
# next_scene = "" ay nangangahulugang magsasara lang at mag-e-emit ng "finished".
# center_page = true: malaki at nasa gitna ang comic, walang narration sa kanan
# (para sa comic na nakalagay na ang text sa mismong image).
var pages: Array = PREQUEL_PAGES.duplicate()
var narration: Array = PREQUEL_NARRATION.duplicate(true)
var next_scene: String = DEFAULT_NEXT_SCENE
var speaker: String = DEFAULT_SPEAKER
var center_page: bool = false

var _textures: Array[Texture2D] = []
var _page_narration: Array = []
var _page_index := 0
var _part_index := 0
var _parts: Array = []
var _full_text := ""
var _char_index := 0
var _type_timer := 0.0
var _typing := false
var _waiting := false
var _busy := false
var _done := false
var _page_rect: TextureRect
var _narration_label: Label
var _speaker_label: Label
var _skip_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_load_pages()
	if _textures.is_empty():
		push_warning("ComicMaliksi: walang valid na comic page, nilaktawan.")
		call_deferred("_finish")
		return
	_show_page(0)


func _build_ui() -> void:
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH) as Font

	var screen_h: float = get_viewport_rect().size.y
	var narration_size: int = maxi(8, int(screen_h * NARRATION_SIZE_RATIO))
	var speaker_size: int = maxi(8, int(narration_size * 0.8))
	var skip_size: int = maxi(6, int(screen_h * SKIP_SIZE_RATIO))

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Comic: sa kaliwa (58%) kapag may narration, buong screen kapag center_page
	_page_rect = TextureRect.new()
	_page_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_rect.anchor_right = 1.0 if center_page else 0.58
	_page_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_page_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_page_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_rect)

	# Pangalan ng nagsasalita (sa itaas ng narration)
	_speaker_label = Label.new()
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != "" and not center_page
	_speaker_label.anchor_left = 0.62
	_speaker_label.anchor_right = 0.96
	_speaker_label.anchor_top = 0.08
	_speaker_label.anchor_bottom = 0.15
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_speaker_label.add_theme_font_size_override("font_size", speaker_size)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_speaker_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_speaker_label.add_theme_constant_override("outline_size", int(speaker_size / 8.0) + 1)
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		_speaker_label.add_theme_font_override("font", font)
	add_child(_speaker_label)

	# Narration sa kanan
	_narration_label = Label.new()
	_narration_label.visible = not center_page
	_narration_label.anchor_left = 0.62
	_narration_label.anchor_right = 0.96
	_narration_label.anchor_top = 0.17
	_narration_label.anchor_bottom = 0.85
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_narration_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_narration_label.add_theme_font_size_override("font_size", narration_size)
	_narration_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_narration_label.add_theme_constant_override("outline_size", int(narration_size / 8.0) + 1)
	_narration_label.add_theme_constant_override("line_spacing", int(narration_size / 4.0))
	_narration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		_narration_label.add_theme_font_override("font", font)
	add_child(_narration_label)

	# Maliit na "Skip (Esc)" sa gitna, sa ibaba ng screen
	_skip_label = Label.new()
	_skip_label.text = "Skip (Esc)"
	_skip_label.anchor_left = 0.0
	_skip_label.anchor_right = 1.0
	_skip_label.anchor_top = 1.0
	_skip_label.anchor_bottom = 1.0
	_skip_label.offset_top = -skip_size * 2.4
	_skip_label.offset_bottom = -skip_size * 0.6
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_label.add_theme_font_size_override("font_size", skip_size)
	_skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_skip_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_skip_label.add_theme_constant_override("outline_size", int(skip_size / 8.0) + 1)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		_skip_label.add_theme_font_override("font", font)
	add_child(_skip_label)


func _load_pages() -> void:
	for i in pages.size():
		var path := str(pages[i])
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_textures.append(tex)
				if i < narration.size():
					_page_narration.append(narration[i])
				else:
					_page_narration.append([])
				continue
		push_warning("ComicMaliksi: hindi ma-load ang %s (tingnan ang import)." % path)


func _show_page(i: int) -> void:
	_page_index = i
	_busy = true
	_waiting = false
	_typing = false
	if _page_rect.texture != null:
		var t_out := create_tween().set_parallel(true)
		t_out.tween_property(_page_rect, "modulate:a", 0.0, FADE_TIME)
		t_out.tween_property(_narration_label, "modulate:a", 0.0, FADE_TIME)
		await t_out.finished
	_page_rect.texture = _textures[i]
	_page_rect.modulate.a = 0.0
	_narration_label.text = ""
	_parts = _page_narration[i]
	_part_index = 0
	var t_in := create_tween()
	t_in.tween_property(_page_rect, "modulate:a", 1.0, FADE_TIME)
	await t_in.finished
	_busy = false
	_start_part()


func _start_part() -> void:
	_narration_label.modulate.a = 1.0
	_narration_label.text = ""
	if _part_index >= _parts.size():
		# Walang narration sa page na ito: hintayin lang ang click.
		_waiting = true
		return
	_full_text = str(_parts[_part_index])
	_char_index = 0
	_type_timer = 0.0
	_typing = true


func _process(delta: float) -> void:
	if not _typing:
		return
	_type_timer += delta
	while _type_timer >= TYPING_SPEED and _typing:
		_type_timer -= TYPING_SPEED
		_char_index += 1
		_narration_label.text = _full_text.substr(0, _char_index)
		if _char_index >= _full_text.length():
			_typing = false
			_waiting = true


func _advance() -> void:
	if _done or _busy:
		return
	if _typing:
		# I-skip ang typing, ipakita agad ang buong linya
		_narration_label.text = _full_text
		_typing = false
		_waiting = true
		return
	if not _waiting:
		return
	_waiting = false
	_part_index += 1
	if _part_index < _parts.size():
		_busy = true
		var t := create_tween()
		t.tween_property(_narration_label, "modulate:a", 0.0, 0.25)
		await t.finished
		_busy = false
		_start_part()
	elif _page_index < _textures.size() - 1:
		_show_page(_page_index + 1)
	else:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	else:
		queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Unahin ang accept_event bago lumipat ng scene
		accept_event()
		_advance()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var is_skip: bool = event.keycode == KEY_ESCAPE
		var is_next: bool = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT, KEY_E]
		if not (is_skip or is_next):
			return
		# Unahin ang set_input_as_handled bago lumipat ng scene
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		if is_skip:
			_finish()
		else:
			_advance()
