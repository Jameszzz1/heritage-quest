extends CharacterBody2D

@export var walk_speed: float = 50.0
@export var sprint_multiplier: float = 2.0

@export var max_health: float = 100
@export var max_stamina: float = 100
@export var max_energy: float = 100

var health: float = 100
var stamina: float = 100
var energy: float = 100

var has_torch: bool = false
var exhausted: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var torch_light: PointLight2D = $TorchLight
@onready var ambient_sight: PointLight2D = $AmbientSight

var stamina_bar = null
var health_bar = null
var energy_bar = null
var hit_sfx: AudioStreamPlayer
var death_sfx: AudioStreamPlayer
var death_screen: ColorRect
var death_layer: CanvasLayer
var death_countdown_label: Label
var is_dead: bool = false

func _ready():
	add_to_group("player")

	health = max_health
	stamina = max_stamina
	energy = max_energy

	if Global.current_health != -1:
		health = Global.current_health
	if Global.current_stamina != -1:
		stamina = Global.current_stamina
	if Global.current_energy != -1:
		energy = Global.current_energy

	Global.current_health = -1
	Global.current_stamina = -1
	Global.current_energy = -1

	stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	health_bar = get_tree().get_first_node_in_group("health_bar")
	energy_bar = get_tree().get_first_node_in_group("energy_bar")

	setup_torch_light()
	setup_ambient_sight()
	setup_hit_sfx()
	setup_death_screen()
	update_ui()

	if Global.spawn_position != Vector2.ZERO:
		position = Global.spawn_position
		Global.spawn_position = Vector2.ZERO

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
	get_tree().root.add_child(death_layer)

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

func is_night_scene() -> bool:
	var scene_path = get_tree().current_scene.scene_file_path
	return scene_path.find("shortway") != -1

func setup_torch_light():
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
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

	torch_light.texture = gradient_texture
	torch_light.texture_scale = 0.35
	torch_light.energy = 1.0
	torch_light.enabled = false

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
	ambient_sight.enabled = is_night_scene()

func _physics_process(delta):
	if is_dead:
		return
	reconnect_ui()
	handle_movement(delta)
	handle_torch(delta)
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

func handle_movement(delta):
	var input_dir = Vector2.ZERO

	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

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
	FootstepManager.play_footstep(surface, delta, is_moving, is_sprinting)

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

func handle_torch(delta):
	if not is_night_scene():
		has_torch = false
		torch_light.enabled = false
		return

	if Input.is_action_just_pressed("toggle_torch") and energy > 2:
		has_torch = !has_torch
		torch_light.enabled = has_torch
	if has_torch:
		energy -= 2 * delta
		if energy <= 0:
			has_torch = false
			torch_light.enabled = false
			energy = 0

func check_exhaustion():
	exhausted = energy <= 0

func update_ui():
	if is_instance_valid(health_bar):
		health_bar.health = health
	if is_instance_valid(stamina_bar):
		stamina_bar.value = stamina
	if is_instance_valid(energy_bar):
		energy_bar.value = energy

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

func die():
	if is_dead:
		return
	is_dead = true
	print("Player Died - Starting death sequence")

	if death_sfx:
		death_sfx.play()

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
	Gamestate.set_tutorial_shown()
	get_tree().change_scene_to_file("res://scenes/provinces/south_cotabato/james_inside_house.tscn")

func update_animations(direction: Vector2):
	var suffix = "_torch" if has_torch else ""
	var sprint_prefix = "sprint_" if (Input.is_action_pressed("sprint") and direction != Vector2.ZERO and stamina > 0 and not exhausted) else ""

	if direction == Vector2.ZERO:
		animated_sprite.play("idle" + suffix)
		return

	if direction.y < 0 and direction.x < 0:
		animated_sprite.play(sprint_prefix + "up_left" + suffix)
	elif direction.y < 0 and direction.x > 0:
		animated_sprite.play(sprint_prefix + "up_right" + suffix)
	elif direction.y > 0 and direction.x < 0:
		animated_sprite.play(sprint_prefix + "down_left" + suffix)
	elif direction.y > 0 and direction.x > 0:
		animated_sprite.play(sprint_prefix + "down_right" + suffix)
	elif direction.y < 0:
		animated_sprite.play(sprint_prefix + "up" + suffix)
	elif direction.y > 0:
		animated_sprite.play(sprint_prefix + "down" + suffix)
	elif direction.x < 0:
		animated_sprite.play(sprint_prefix + "left" + suffix)
	elif direction.x > 0:
		animated_sprite.play(sprint_prefix + "right" + suffix)
