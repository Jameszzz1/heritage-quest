extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var progress_bar: TextureProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var label: Label = $CenterContainer/VBoxContainer/Label

var _target_scene_path: String = ""
var _is_loading: bool = false
var _glow_tween: Tween

const BAR_WIDTH := 200
const BAR_HEIGHT := 14

func _ready() -> void:
	layer = 100
	visible = false
	color_rect.color = Color(0, 0, 0, 1)
	set_process(false)
	_setup_progress_bar_style()

func _setup_progress_bar_style() -> void:
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT

	# Background track (dark pill)
	progress_bar.texture_under = _make_rounded_texture(
		BAR_WIDTH, BAR_HEIGHT,
		[Color(0.1, 0.1, 0.1, 1.0), Color(0.1, 0.1, 0.1, 1.0)]
	)

	# Gradient fill (orange -> gold -> bright yellow), rounded pill
	progress_bar.texture_progress = _make_rounded_texture(
		BAR_WIDTH, BAR_HEIGHT,
		[Color(1.0, 0.55, 0.1, 1.0), Color(1.0, 0.8, 0.2, 1.0), Color(1.0, 0.95, 0.6, 1.0)]
	)

func _make_rounded_texture(width: int, height: int, gradient_colors: Array) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius: float = height / 2.0

	var grad := Gradient.new()
	var colors := PackedColorArray(gradient_colors)
	grad.colors = colors

	for x in range(width):
		var t: float = float(x) / float(width - 1)
		var col: Color = grad.sample(t)
		for y in range(height):
			var px: float = x + 0.5
			var py: float = y + 0.5
			var inside := true

			# check left rounded corner
			if px < radius:
				var dx := radius - px
				var dy := radius - py
				if dx * dx + dy * dy > radius * radius:
					inside = false
			# check right rounded corner
			elif px > width - radius:
				var dx2 := px - (width - radius)
				var dy2 := radius - py
				if dx2 * dx2 + dy2 * dy2 > radius * radius:
					inside = false

			if inside:
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)

func _start_glow_pulse() -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_property(progress_bar, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(progress_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

func _stop_glow_pulse() -> void:
	if _glow_tween:
		_glow_tween.kill()
	progress_bar.modulate = Color(1, 1, 1, 1)

func change_scene(scene_path: String) -> void:
	if _is_loading:
		return
	_target_scene_path = scene_path
	_is_loading = true

	visible = true
	progress_bar.value = 0
	label.text = "Loading..."
	_start_glow_pulse()

	color_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.3)
	await tween.finished

	var err := ResourceLoader.load_threaded_request(_target_scene_path)
	if err != OK:
		push_error("Failed to start loading: " + _target_scene_path)
		_is_loading = false
		visible = false
		_stop_glow_pulse()
		return

	set_process(true)

func _process(_delta: float) -> void:
	if not _is_loading:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				progress_bar.value = progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100
			set_process(false)
			var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_target_scene_path)
			await get_tree().create_timer(0.15).timeout
			get_tree().change_scene_to_packed(packed_scene)

			var tween := create_tween()
			tween.tween_property(color_rect, "modulate:a", 0.0, 0.3)
			await tween.finished
			visible = false
			_is_loading = false
			_stop_glow_pulse()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load scene: " + _target_scene_path)
			set_process(false)
			visible = false
			_is_loading = false
			_stop_glow_pulse()
