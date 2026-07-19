extends CharacterBody2D

# ---------- CONTROLS & PHYSICS CONFIG ----------
@export var speed: float = 150.0            # Normal/slow walking speed
@export var jump_velocity: float = -400.0   # Swabe at natural na taas ng talon
@export var gravity: float = 1100.0         # Natural at hindi parang batong pagbagsak

# ---------- AUDIO CONFIG ----------
# Naka-preload na rito ang dalawang paths sa isang Array/Listahan
var jump_grunt_sounds: Array = [
	preload("res://assets/audio/sfx/ascent_jump_effort_grunt_male.wav"),
	preload("res://assets/audio/sfx/ascent_jump_effort_grunt2_male.wav")
]
var audio_player: AudioStreamPlayer2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

signal jumped_from_platform(platform_node)

var current_floor_platform: Node = null

func _ready() -> void:
	# Gumawa tayo ng Audio Player node dynamically
	audio_player = AudioStreamPlayer2D.new()
	audio_player.volume_db = -6.0 # Tweak base sa pandinig mo
	add_child(audio_player)

func _physics_process(delta: float) -> void:
	# 1. APPLY GRAVITY
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. HANDLE JUMP INPUT & RANDOM SOUND TRIGGER
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if current_floor_platform != null:
			jumped_from_platform.emit(current_floor_platform)
		
		velocity.y = jump_velocity
		
		# Pumipili nang random sound mula sa array para i-play
		if audio_player != null and jump_grunt_sounds.size() > 0:
			var random_index = randi() % jump_grunt_sounds.size()
			audio_player.stream = jump_grunt_sounds[random_index]
			audio_player.play()

	# 3. HANDLE MOVEMENT INPUT
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

	# 4. TRACK CURRENT PLATFORM COLLISION
	current_floor_platform = null
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.5:
			current_floor_platform = collision.get_collider()

	# 5. TRIGGER ANIMATION LOGIC
	update_animation(direction)

func update_animation(direction: float) -> void:
	# --- ANIMATION MECHANICS KAPAG NASA ERE (JUMPING / FALLING) ---
	if not is_on_floor():
		if direction < 0:
			sprite.play("ascent_jump_left")
		elif direction > 0:
			sprite.play("ascent_jump_right")
		else:
			sprite.play("ascent_jump")

	# --- ANIMATION MECHANICS KAPAG NASA GROUND (GROUNDED) ---
	else:
		if direction < 0:
			sprite.play("ascent_left")
		elif direction > 0:
			sprite.play("ascent_right")
		else:
			sprite.play("ascent_idle")
