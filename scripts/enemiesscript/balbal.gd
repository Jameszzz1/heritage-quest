extends CharacterBody2D

@export var speed: float = 50.0
@export var chase_range: float = 30.0
@export var patrol_speed: float = 20.0
@export var attack_range: float = 15.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

# ---- SFX settings ----
# Habang hinahabol ka: random na pagitan ng bawat tunog (segundo)
@export var chase_sfx_interval_min: float = 1.0
@export var chase_sfx_interval_max: float = 2.5
# Malapit-lapit lang (hindi pa humahabol): mahina at bihira, para realistic
@export var ambient_range: float = 100.0
@export var ambient_interval_min: float = 3.0
@export var ambient_interval_max: float = 6.0
@export var ambient_volume_db: float = -8.0   # mas mahina kapag hindi pa humahabol
@export var sfx_volume_db: float = 0.0
@export var sfx_max_distance: float = 200.0   # mas malayo ang paniki, mas mahina ang tunog

@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

var bat_sound = preload("res://assets/audio/sfx/enemies_sfx/bat_.wav")
var sfx_player: AudioStreamPlayer2D
var sfx_timer: float = 0.0
var was_chasing: bool = false

var player: Node2D = null
var patrol_direction: Vector2 = Vector2(1, 0)
var patrol_timer: float = 0.0
var idle_timer: float = 0.0
var is_idle: bool = false
var attack_timer: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	print("Balbal found player: ", player)
	setup_sfx()
	anim.play("idle")

# ---------------- SOUND ----------------

func setup_sfx():
	sfx_player = AudioStreamPlayer2D.new()
	sfx_player.volume_db = sfx_volume_db
	sfx_player.max_distance = sfx_max_distance
	if AudioServer.get_bus_index("SFX") != -1:
		sfx_player.bus = "SFX"
	add_child(sfx_player)

func play_bat_sfx(volume_offset_db: float = 0.0, pitch_min: float = 0.9, pitch_max: float = 1.1):
	# Hintayin munang matapos ang kasalukuyang tunog
	if sfx_player.playing:
		return
	sfx_player.stream = bat_sound
	sfx_player.volume_db = sfx_volume_db + volume_offset_db
	sfx_player.pitch_scale = randf_range(pitch_min, pitch_max)   # konting pagbabago para hindi paulit-ulit
	sfx_player.play()

# ---------------- MAIN LOOP ----------------

func _physics_process(delta):
	if player == null:
		return

	attack_timer -= delta

	var distance = global_position.distance_to(player.global_position)

	if distance < attack_range:
		# Attack the player
		was_chasing = false
		velocity = Vector2.ZERO
		anim.play("idle")
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			print("Bat attacked! Distance: ", distance)
			# Mas matining na tunog kapag aatake (hindi kung patay na ang player)
			if player.get("is_dead") != true:
				sfx_player.stop()
				play_bat_sfx(2.0, 1.1, 1.3)
			player.take_hit(attack_damage)

	elif distance < chase_range:
		# Chase the player
		is_idle = false
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
		anim.play("run")

		# Tutunog agad pag nagsimulang humabol, tapos paminsan-minsan
		if not was_chasing:
			was_chasing = true
			sfx_timer = 0.0
		sfx_timer -= delta
		if sfx_timer <= 0.0:
			play_bat_sfx()
			sfx_timer = randf_range(chase_sfx_interval_min, chase_sfx_interval_max)

	else:
		# Patrol logic
		was_chasing = false
		patrol_timer += delta

		# Malapit lang kaunti: mahinang tunog paminsan-minsan
		if distance < ambient_range:
			sfx_timer -= delta
			if sfx_timer <= 0.0:
				play_bat_sfx(ambient_volume_db, 0.85, 1.05)
				sfx_timer = randf_range(ambient_interval_min, ambient_interval_max)

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
					patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

			velocity = patrol_direction * patrol_speed
			sprite.flip_h = patrol_direction.x < 0
			anim.play("run")

	move_and_slide()
