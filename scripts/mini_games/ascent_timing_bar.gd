class_name TimingBar
extends Control

signal hit(quality: String, side: String)   # side = "left" / "right" / "both"
signal missed(side: String)

@export var bar_size := Vector2(120, 10)
@export var perfect_width := 0.16
@export var good_width := 0.36
@export var speed := 0.9
@export var speed_per_success := 0.04
@export var max_speed := 2.0
@export var randomize_zone := false
@export var both_window := 0.08          # segundo na pagitan ng A at D para ituring na A+D

var active := true
var marker := 0.0
var direction := 1
var zone_center := 0.5
var required := "left"                   # "left" (A), "right" (D), "both" (A+D)

var _buf_t := -1.0
var _buf_marker := 0.0
var _buf_left := false
var _buf_right := false


func _ready() -> void:
	_ensure_actions()
	custom_minimum_size = bar_size
	size = bar_size
	randomize()
	_next_required()
	_new_zone()

func _ensure_actions() -> void:
	_add_key("climb_left", KEY_A)
	_add_key("climb_right", KEY_D)

func _add_key(action_name: String, key: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action_name, ev)

func _next_required() -> void:
	var options := ["left", "right", "both"]
	options.erase(required)
	required = options[randi() % options.size()]


func _process(delta: float) -> void:
	if not active:
		_buf_t = -1.0
		return

	marker += direction * speed * delta
	if marker >= 1.0:
		marker = 1.0
		direction = -1
	elif marker <= 0.0:
		marker = 0.0
		direction = 1

	if _buf_t >= 0.0:
		_buf_t += delta
		if _buf_t >= both_window:
			_resolve_input()

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("climb_left"):
		get_viewport().set_input_as_handled()
		_begin_input(true, false)
	elif event.is_action_pressed("climb_right"):
		get_viewport().set_input_as_handled()
		_begin_input(false, true)

func _begin_input(l: bool, r: bool) -> void:
	if _buf_t < 0.0:
		_buf_t = 0.0
		_buf_marker = marker       # timing ay sa unang pindot
		_buf_left = false
		_buf_right = false
	_buf_left = _buf_left or l
	_buf_right = _buf_right or r
	if _buf_left and _buf_right:
		_resolve_input()

func _resolve_input() -> void:
	var used := "both"
	if _buf_left and not _buf_right:
		used = "left"
	elif _buf_right and not _buf_left:
		used = "right"
	_buf_t = -1.0
	_evaluate(used, _buf_marker)

func _evaluate(used: String, at_marker: float) -> void:
	if used != required:
		missed.emit(used)
		return
	var dist: float = abs(at_marker - zone_center)
	if dist <= perfect_width / 2.0:
		_success("perfect", used)
	elif dist <= good_width / 2.0:
		_success("good", used)
	else:
		missed.emit(used)

func _success(quality: String, used: String) -> void:
	speed = min(speed + speed_per_success, max_speed)
	_next_required()
	_new_zone()
	hit.emit(quality, used)

func _new_zone() -> void:
	if randomize_zone:
		var half := good_width / 2.0
		zone_center = randf_range(half + 0.05, 1.0 - half - 0.05)
	else:
		zone_center = 0.5

func set_active(value: bool) -> void:
	active = value
	if not value:
		_buf_t = -1.0


func _prompt_text() -> String:
	match required:
		"left":
			return "A"
		"right":
			return "D"
		_:
			return "A + D"

func _draw() -> void:
	var w := bar_size.x
	var h := bar_size.y
	var gl := (zone_center - good_width / 2.0) * w
	var gr := (zone_center + good_width / 2.0) * w
	var pl := (zone_center - perfect_width / 2.0) * w
	var pr := (zone_center + perfect_width / 2.0) * w

	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	_hatch(gl, pl, h)
	_hatch(pr, gr, h)
	draw_rect(Rect2(pl, 1, pr - pl, h - 2), Color.WHITE)
	draw_rect(Rect2(0, 0, w, h), Color.WHITE, false, 1.0)
	var mx := marker * w
	draw_line(Vector2(mx, -3), Vector2(mx, h + 3), Color.WHITE, 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(0, -5), _prompt_text(),
		HORIZONTAL_ALIGNMENT_CENTER, w, 8, Color.WHITE)

func _hatch(x0: float, x1: float, h: float) -> void:
	var x := x0
	while x < x1:
		draw_line(Vector2(x, 1), Vector2(x, h - 1), Color(1, 1, 1, 0.55), 1.0)
		x += 2.0
