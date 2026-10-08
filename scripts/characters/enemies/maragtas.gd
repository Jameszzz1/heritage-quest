extends CharacterBody2D

@export var speed: float = 50.0
@export var chase_range: float = 30.0
@export var patrol_speed: float = 20.0
@export var attack_range: float = 15.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

# Minimap identification
var marker_id: String = "snake"

var player: Node2D = null
var patrol_direction: Vector2 = Vector2(1, 0)
var patrol_timer: float = 0.0
var idle_timer: float = 0.0
var is_idle: bool = false
var attack_timer: float = 0.0


func _ready():
	# Add Maragtas to the minimap enemy groups
	add_to_group("minimap_enemy")
	add_to_group("minimap_snake")

	player = get_tree().get_first_node_in_group("player")

	print("Maragtas found player: ", player)

	anim.play("idle")


func _physics_process(delta):
	if player == null:
		return

	attack_timer -= delta

	var distance = global_position.distance_to(player.global_position)

	# =====================================================
	# ATTACK
	# =====================================================

	if distance < attack_range:

		velocity = Vector2.ZERO

		anim.play("idle")

		if attack_timer <= 0.0:

			attack_timer = attack_cooldown

			print("Maragtas attacked! Distance: ", distance)

			player.take_hit(attack_damage)


	# =====================================================
	# CHASE
	# =====================================================

	elif distance < chase_range:

		is_idle = false

		var direction = (
			player.global_position - global_position
		).normalized()

		velocity = direction * speed

		sprite.flip_h = direction.x < 0

		anim.play("run")


	# =====================================================
	# PATROL
	# =====================================================

	else:

		patrol_timer += delta

		if is_idle:

			idle_timer += delta

			velocity = Vector2.ZERO

			anim.play("idle")

			if idle_timer > 10.0:

				is_idle = false
				idle_timer = 0.0
				patrol_timer = 0.0

		else:

			if patrol_timer > 2.0:

				patrol_timer = 0.0

				if randf() < 0.4:

					is_idle = true

				else:

					patrol_direction = Vector2(
						randf_range(-1, 1),
						randf_range(-1, 1)
					).normalized()

			velocity = patrol_direction * patrol_speed

			sprite.flip_h = patrol_direction.x < 0

			anim.play("run")


	move_and_slide()
