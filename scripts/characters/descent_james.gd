extends CharacterBody2D

# ---------- PARACHUTE DESCENT CONFIG ----------
@export var fall_speed: float = 120.0        # Constant downward fall speed (parachute = controlled, hindi mabilis)
@export var steer_speed: float = 180.0       # Horizontal speed kapag A/D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- CUTSCENE / GAME-OVER CONTROL LOCK ---
var control_enabled: bool = true

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled

func play_hit_animation() -> void:
	sprite.play("descent_hit")

func _physics_process(delta: float) -> void:
	if not control_enabled:
		velocity.y = fall_speed
		velocity.x = move_toward(velocity.x, 0, steer_speed)
		move_and_slide()
		return

	# 1. CONSTANT DOWNWARD FALL (parachute effect — hindi tumataas, steady lang pababa)
	velocity.y = fall_speed

	# 2. HORIZONTAL STEERING (A/D o Left/Right)
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * steer_speed
	else:
		velocity.x = move_toward(velocity.x, 0, steer_speed)

	move_and_slide()

	# 3. ANIMATION
	update_animation(direction)

func update_animation(direction: float) -> void:
	if direction < 0:
		sprite.play("descent_left")
	elif direction > 0:
		sprite.play("descent_right")
	else:
		sprite.play("descent_idle")
