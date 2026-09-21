extends CharacterBody2D

@export var walk_speed: float = 50.0
@export var sprint_multiplier: float = 2.0

@export var max_health: float = 100
@export var max_stamina: float = 100
@export var max_energy: float = 100
@export var max_battery: float = 100

# Flashlight tuning
@export var battery_drain_rate: float = 1.5      # per second (100 / 1.5 = ~66 sec na ilaw)
@export var flashlight_range_scale: float = 0.7  # laki/layo ng ilaw
@export var flashlight_half_angle: float = 28.0  # luwang ng cone (degrees)
@export var low_battery_threshold: float = 0.2   # 20% pababa = flicker

const HELD_ANIM_SUFFIX: String = "_flashlight"
const FLASHLIGHT_ENERGY: float = 1.0

# Pwesto ng lens ng flashlight kada direction, relative sa gitna ni James (world pixels)
# Pagkakasunod: right, down_right, down, down_left, left, up_left, up, up_right
const FLASHLIGHT_OFFSETS: Array[Vector2] = [
	Vector2(6, 4),    # right
	Vector2(5, 4),    # down_right
	Vector2(4, 4),    # down
	Vector2(-5, 4),   # down_left
	Vector2(-6, 4),   # left
	Vector2(-5, 3),   # up_left
	Vector2(5, 4),    # up (nasa kamay/balakang na)
	Vector2(5, 3),    # up_right
]

var health: float = 100
var stamina: float = 100
var energy: float = 100
var battery: float = 100

var flashlight_on: bool = false
var exhausted: bool = false
var in_night_scene: bool = false
var facing_dir: Vector2 = Vector2(0, 1)
var flicker_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flashlight: PointLight2D = $FlashLight
@onready var ambient_sight: PointLight2D = $AmbientSight

var stamina_bar = null
var health_bar = null
var energy_bar = null
var battery_bar = null
var battery_box = null   # optional na lang
var hit_sfx: AudioStreamPlayer
var death_sfx: AudioStreamPlayer
var death_screen: ColorRect
var death_layer: CanvasLayer
var death_countdown_label: Label
var is_dead: bool = false

func _ready():
	add_to_group("player")
	in_night_scene = is_night_scene()

	health = max_health
	stamina = max_stamina
	energy = max_energy
	battery = max_battery

	if Global.current_health != -1:
		health = Global.current_health
	if Global.current_stamina != -1:
		stamina = Global.current_stamina
	if Global.current_energy != -1:
		energy = Global.current_energy
	if Global.current_battery != -1:
		battery = Global.current_battery

	Global.current_health = -1
	Global.current_stamina = -1
	Global.current_energy = -1
	Global.current_battery = -1

	stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	health_bar = get_tree().get_first_node_in_group("health_bar")
	energy_bar = get_tree().get_first_node_in_group("energy_bar")
	battery_bar = _find_ui_node("battery_bar", "BatteryBar")
	battery_box = _find_ui_node("battery_box", "BatteryBox")

	if is_instance_valid(battery_bar):
		battery_bar.max_value = max_battery
	elif in_night_scene:
		print("BATTERY BAR HINDI NAHANAP! I-check ang group na 'battery_bar' o ang node name na 'BatteryBar' sa HUD.")

	setup_flashlight()
	setup_ambient_sight()
	setup_hit_sfx()
	setup_death_screen()
	update_ui()

	if Global.spawn_position != Vector2.ZERO:
		position = Global.spawn_position
		Global.spawn_position = Vector2.ZERO

func _exit_tree():
	# Burahin ang death layer pag umalis si James sa scene (para hindi mag-pile up sa root)
	if is_instance_valid(death_layer):
		death_layer.queue_free()

# Hanapin muna sa group, kung wala, hanapin sa pangalan ng node
func _find_ui_node(group_name: String, node_name: String):
	var n = get_tree().get_first_node_in_group(group_name)
	if n == null:
		n = find_child(node_name, true, false)
	return n

func setup_hit_sfx():
	hit_sfx = AudioStreamPlayer.new()
	hit_sfx.stream = load("res://assets/audio/sfx/damage.wav")
	add_child(hit_sfx)

	death_sfx = AudioStreamPlayer.new()
	death_sfx.stream = load("res://assets/audio/sfx/death.wav")
	add_child(death_sfx)

func setup_death_screen():
	death_layer = CanvasLayer.new()
	death_layer.layer = 128

	death_screen = ColorRect.new()
	death_screen.color = Color(0, 0, 0, 0)
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.add_child(death_screen)

	death_countdown_label = Label.new()
	death_countdown_label.add_theme_font_size_override("font_size", 32)
	death_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	death_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	death_countdown_label.visible = false
	death_layer.add_child(death_countdown_label)

	# Deferred ang pag-add sa root para hindi mag-"busy parent" error
	get_tree().root.add_child.call_deferred(death_layer)

func is_night_scene() -> bool:
	var scene_path = get_tree().current_scene.scene_file_path
	return scene_path.find("shortway") != -1

# ---------------- FLASHLIGHT ----------------

func create_cone_texture(size: int = 256, half_angle_deg: float = 28.0) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size, size) / 2.0
	var half_angle: float = deg_to_rad(half_angle_deg)
	var radius: float = size / 2.0

	for x in range(size):
		for y in range(size):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			var dist: float = d.length() / radius
			if dist > 1.0:
				continue
			var ang: float = absf(d.angle())  # 0 = nakaturo sa kanan (+X)
			if ang > half_angle:
				continue
			var edge: float = 1.0 - smoothstep(half_angle * 0.5, half_angle, ang)
			var falloff: float = 1.0 - pow(dist, 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, edge * falloff))

	return ImageTexture.create_from_image(img)

# Kunin ang pwesto ng lens base sa direction na tinitingnan ni James (8 direction)
func _get_flashlight_offset() -> Vector2:
	var idx: int = posmod(roundi(facing_dir.angle() / (PI / 4.0)), 8)
	return FLASHLIGHT_OFFSETS[idx]

func setup_flashlight():
	flashlight.texture = create_cone_texture(256, flashlight_half_angle)
	flashlight.texture_scale = flashlight_range_scale
	flashlight.color = Color(1.0, 1.0, 0.92)
	flashlight.energy = FLASHLIGHT_ENERGY
	flashlight.position = _get_flashlight_offset()
	flashlight.rotation = facing_dir.angle()
	flashlight.enabled = false

func setup_ambient_sight():
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.5))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.set_offset(0, 0.0)
	gradient.set_offset(1, 1.0)

	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	gradient_texture.width = 256
	gradient_texture.height = 256

	ambient_sight.texture = gradient_texture
	ambient_sight.texture_scale = 0.15
	ambient_sight.energy = 0.7
	ambient_sight.enabled = in_night_scene

# Gagamitin ang "toggle_flashlight" kung meron na sa Input Map, kung wala pa, ang luma
func _get_toggle_action() -> String:
	if InputMap.has_action("toggle_flashlight"):
		return "toggle_flashlight"
	return "toggle_torch"

func handle_flashlight(delta):
	if not in_night_scene:
		flashlight_on = false
		flashlight.enabled = false
		return

	if Input.is_action_just_pressed(_get_toggle_action()):
		if flashlight_on:
			flashlight_on = false
		elif battery > 0:
			flashlight_on = true
			# Diretso agad sa tamang pwesto pag binuksan
			flashlight.position = _get_flashlight_offset()
			flashlight.rotation = facing_dir.angle()

	if flashlight_on:
		battery -= battery_drain_rate * delta
		if battery <= 0:
			battery = 0
			flashlight_on = false

	battery = clamp(battery, 0, max_battery)
	flashlight.enabled = flashlight_on

	if flashlight_on:
		# Sundan ang lens at direction ng lakad
		flashlight.position = flashlight.position.lerp(_get_flashlight_offset(), 15.0 * delta)
		flashlight.rotation = lerp_angle(flashlight.rotation, facing_dir.angle(), 12.0 * delta)

		# Flicker pag mahina na ang battery
		if battery <= max_battery * low_battery_threshold:
			flicker_timer -= delta
			if flicker_timer <= 0.0:
				flashlight.energy = randf_range(0.3, 1.0) * FLASHLIGHT_ENERGY
				flicker_timer = randf_range(0.05, 0.2)
		else:
			flashlight.energy = FLASHLIGHT_ENERGY

# ---------------- MAIN LOOP ----------------

func _physics_process(delta):
	if is_dead:
		return
	reconnect_ui()
	handle_movement(delta)
	handle_flashlight(delta)
	handle_energy(delta)
	handle_stamina_regen(delta)
	check_exhaustion()
	update_ui()

func reconnect_ui():
	if not is_instance_valid(stamina_bar):
		stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if not is_instance_valid(health_bar):
		health_bar = get_tree().get_first_node_in_group("health_bar")
	if not is_instance_valid(energy_bar):
		energy_bar = get_tree().get_first_node_in_group("energy_bar")
	if not is_instance_valid(battery_bar):
		battery_bar = _find_ui_node("battery_bar", "BatteryBar")
		if is_instance_valid(battery_bar):
			battery_bar.max_value = max_battery

func handle_movement(delta):
	var input_dir = Vector2.ZERO

	# Screen-accurate: W = pataas, A = pakaliwa, S = pababa, D = pakanan
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	if input_dir != Vector2.ZERO:
		facing_dir = input_dir

	var current_speed = walk_speed
	var is_sprinting = Input.is_action_pressed("sprint")

	if exhausted:
		is_sprinting = false

	if is_sprinting and input_dir != Vector2.ZERO and stamina > 0:
		current_speed = walk_speed * sprint_multiplier
		stamina -= 20 * delta
		energy -= 3 * delta
	else:
		current_speed = walk_speed

	velocity = input_dir * current_speed
	move_and_slide()

	update_animations(input_dir)

	var is_moving = input_dir != Vector2.ZERO
	var surface = get_surface_type()

	FootstepManager.play_footstep(
		surface,
		delta,
		is_moving,
		is_sprinting
	)

func get_surface_type() -> String:
	var tilemap = get_tree().get_first_node_in_group("land_tilemap")
	if tilemap == null:
		return ""
	var tile_pos = tilemap.local_to_map(tilemap.to_local(global_position))
	var tile_data = tilemap.get_cell_tile_data(tile_pos)
	if tile_data == null:
		return ""
	return tile_data.get_custom_data("surface_type")

func handle_stamina_regen(delta):
	if velocity == Vector2.ZERO:
		var regen_rate = 15.0
		if energy <= 25:
			regen_rate = 5.0
		stamina += regen_rate * delta
	stamina = clamp(stamina, 0, max_stamina)

func handle_energy(delta):
	energy -= 0.2 * delta
	energy = clamp(energy, 0, max_energy)

func check_exhaustion():
	exhausted = energy <= 0

func update_ui():
	if is_instance_valid(health_bar):
		health_bar.health = health
	if is_instance_valid(stamina_bar):
		stamina_bar.value = stamina
	if is_instance_valid(energy_bar):
		energy_bar.value = energy

	# Battery UI: shortway lang makikita
	if is_instance_valid(battery_box):
		battery_box.visible = in_night_scene
	if is_instance_valid(battery_bar):
		battery_bar.visible = in_night_scene
		battery_bar.value = battery
		# Sync ang DamageBar (pula) para walang natitirang pula sa bar
		var dmg = battery_bar.get_node_or_null("DamageBar")
		if dmg:
			dmg.max_value = max_battery
			dmg.value = battery

func take_hit(damage: float):
	if is_dead:
		return
	health -= damage
	health = clamp(health, 0, max_health)
	update_ui()
	if hit_sfx:
		hit_sfx.play()
	if health <= 0:
		die()

func heal(amount: float):
	health += amount
	health = clamp(health, 0, max_health)

func restore_energy(amount: float):
	energy += amount
	energy = clamp(energy, 0, max_energy)

func restore_stamina(amount: float):
	stamina += amount
	stamina = clamp(stamina, 0, max_stamina)

func restore_battery(amount: float):
	battery += amount
	battery = clamp(battery, 0, max_battery)

func die():
	if is_dead:
		return
	is_dead = true
	print("Player Died - Starting death sequence")

	if death_sfx:
		death_sfx.play()

	flashlight_on = false
	flashlight.enabled = false

	set_physics_process(false)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	animated_sprite.play("death")
	await animated_sprite.animation_finished

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.show_death_sequence()
	else:
		print("HUD NOT FOUND - cannot show death screen!")
		await get_tree().create_timer(10.0).timeout

	visible = true
	Global.spawn_position = Vector2.ZERO
	Global.current_health = max_health * 0.5
	Global.current_stamina = max_stamina
	Global.current_energy = max_energy
	Global.current_battery = max_battery
	Gamestate.set_tutorial_shown()
	get_tree().change_scene_to_file("res://scenes/provinces/south_cotabato/james_inside_house.tscn")

# ---------------- ANIMATIONS ----------------

func _play_first_available(candidates: Array):
	var frames = animated_sprite.sprite_frames
	for anim in candidates:
		if frames.has_animation(anim):
			animated_sprite.play(anim)
			return

func update_animations(direction: Vector2):
	var suffix = HELD_ANIM_SUFFIX if flashlight_on else ""
	var sprint_prefix = "sprint_" if (Input.is_action_pressed("sprint") and direction != Vector2.ZERO and stamina > 0 and not exhausted) else ""

	if direction == Vector2.ZERO:
		_play_first_available(["idle" + suffix, "idle"])
		return

	var dir_name = ""
	if direction.y < 0 and direction.x < 0:
		dir_name = "up_left"
	elif direction.y < 0 and direction.x > 0:
		dir_name = "up_right"
	elif direction.y > 0 and direction.x < 0:
		dir_name = "down_left"
	elif direction.y > 0 and direction.x > 0:
		dir_name = "down_right"
	elif direction.y < 0:
		dir_name = "up"
	elif direction.y > 0:
		dir_name = "down"
	elif direction.x < 0:
		dir_name = "left"
	elif direction.x > 0:
		dir_name = "right"

	_play_first_available([
		sprint_prefix + dir_name + suffix,
		dir_name + suffix,
		sprint_prefix + dir_name,
		dir_name
	])
