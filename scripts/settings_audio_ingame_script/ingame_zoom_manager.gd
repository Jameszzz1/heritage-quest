extends Node

# Ilan ang zoom per scroll (1.15 = 15%)
const ZOOM_STEP := 1.15
# Pinakamalayo (mas maliit = mas malayo). Kung nakikita na ang labas ng map, itaas (halimbawa 0.8)
const MIN_FACTOR := 0.6
# Pinakamalapit
const MAX_FACTOR := 2.0
# Bilis ng smooth zoom
const ZOOM_SPEED := 10.0

var target_factor := 1.0
var current_factor := 1.0
var cam: Camera2D = null
var base_zoom := Vector2.ONE

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_factor = clamp(target_factor * ZOOM_STEP, MIN_FACTOR, MAX_FACTOR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_factor = clamp(target_factor / ZOOM_STEP, MIN_FACTOR, MAX_FACTOR)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			# Gitnang click = balik sa normal na zoom
			target_factor = 1.0

func _process(delta):
	var active_cam = get_viewport().get_camera_2d()
	if active_cam == null:
		cam = null
		return

	# Bagong scene / bagong camera: kunin ang original zoom niya at i-apply ang kasalukuyang zoom level
	if active_cam != cam:
		cam = active_cam
		base_zoom = cam.zoom
		if not is_equal_approx(current_factor, 1.0):
			cam.zoom = base_zoom * current_factor

	if is_equal_approx(current_factor, target_factor):
		return

	current_factor = lerp(current_factor, target_factor, clamp(ZOOM_SPEED * delta, 0.0, 1.0))
	if abs(current_factor - target_factor) < 0.001:
		current_factor = target_factor
	cam.zoom = base_zoom * current_factor
