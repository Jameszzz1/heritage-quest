#maragtas
extends CharacterBody2D

@export var speed: float = 50.0
@export var chase_range: float = 30.0
@export var patrol_speed: float = 20.0
@export var attack_range: float = 15.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

# Sutsot: malayo-layo si James = 1_snake_hiss, malapit na = 2_snake_hiss
@export var far_hiss_range: float = 90.0
@export var near_hiss_range: float = 45.0
@export var far_hiss_interval_min: float = 3.0
@export var far_hiss_interval_max: float = 5.0
@export var near_hiss_interval_min: float = 2.0
@export var near_hiss_interval_max: float = 3.5
@export var sfx_volume_db: float = 0.0

@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

var far_hiss_sound = preload("res://assets/audio/sfx/enemies_sfx/1_snake_hiss.mp3")
var near_hiss_sound = preload("res://assets/audio/sfx/enemies_sfx/2_snake_hiss.mp3")
var attack_hiss_sound = preload("res://assets/audio/sfx/enemies_sfx/attack_snake_hiss.mp3")

var hiss_player: AudioStreamPlayer2D
var attack_player: AudioStreamPlayer2D
var hiss_timer: float = 0.0
var hiss_zone: int = 0   # 0 = walang sutsot, 1 = malayo-layo, 2 = malapit

var marker_id: String = "snake"
var enemy_id := "snake"

var player: Node2D = null
var patrol_direction: Vector2 = Vector2(1, 0)
var patrol_timer: float = 0.0
var idle_timer: float = 0.0
var is_idle: bool = false
var attack_timer: float = 0.0

# Para sa badge #11 (Apex Dodger)
var _badge_chasing: bool = false
var _chase_sprinted: bool = false
var _chase_attacked: bool = false

func _ready():
	add_to_group("minimap_enemy")
	player = get_tree().get_first_node_in_group("player")
	print("Maragtas found player: ", player)
	print("Maragtas animations: ", anim.get_animation_list())
	setup_sfx()
	play_idle()

# ---------------- ANIMATION ----------------

func play_idle():
	if anim.has_animation("idle"):
		anim.play("idle")
	else:
		anim.stop()

func play_move():
	# Susubukan ang mga karaniwang pangalan; ang una na meron ang gagamitin
	for n in ["run", "move", "slither", "walk", "crawl"]:
		if anim.has_animation(n):
			anim.play(n)
			return

# ---------------- SOUND ----------------

func setup_sfx():
	# Magkahiwalay ang player ng sutsot at atake para hindi nila pinuputol ang isa't isa
	hiss_player = _make_sfx_player()
	attack_player = _make_sfx_player()

func _make_sfx_player() -> AudioStreamPlayer2D:
	var p = AudioStreamPlayer2D.new()
	p.volume_db = sfx_volume_db
	p.max_distance = 300.0   # mas malayo ang ahas, mas mahina ang tunog
	if AudioServer.get_bus_index("SFX") != -1:
		p.bus = "SFX"
	add_child(p)
	return p

func update_hiss(delta: float, distance: float):
	var zone = 0
	if distance < attack_range:
		zone = 0   # attack sound na ang bahala dito
	elif distance < near_hiss_range:
		zone = 2
	elif distance < far_hiss_range:
		zone = 1

	# Pag lumipat ng zone (lumapit o lumayo si James), sisitsit agad
	if zone != hiss_zone:
		hiss_zone = zone
		hiss_timer = 0.0

	if hiss_zone == 0:
		return

	hiss_timer -= delta
	if hiss_timer > 0.0:
		return
	# Hintayin munang matapos ang kasalukuyang tunog
	if hiss_player.playing or attack_player.playing:
		return

	if hiss_zone == 2:
		hiss_player.stream = near_hiss_sound
		hiss_timer = randf_range(near_hiss_interval_min, near_hiss_interval_max)
	else:
		hiss_player.stream = far_hiss_sound
		hiss_timer = randf_range(far_hiss_interval_min, far_hiss_interval_max)
	hiss_player.pitch_scale = randf_range(0.95, 1.05)   # konting pagbabago ng boses
	hiss_player.play()

func play_attack_hiss():
	hiss_player.stop()
	attack_player.stream = attack_hiss_sound
	attack_player.pitch_scale = randf_range(0.95, 1.05)
	attack_player.play()

# ---------------- MAIN LOOP ----------------

func _physics_process(delta):
	if player == null:
		return
	attack_timer -= delta
	var distance = global_position.distance_to(player.global_position)

	update_hiss(delta, distance)

	if distance < attack_range:
		# Attack the player
		_badge_chasing = true
		velocity = Vector2.ZERO
		play_idle()
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			print("Snake attacked! Distance: ", distance)
			_chase_attacked = true
			# Tunog ng atake (hindi kung patay na si James)
			if player.get("is_dead") != true:
				play_attack_hiss()
			player.take_hit(attack_damage)
	elif distance < chase_range:
		# Chase the player
		is_idle = false
		_badge_chasing = true
		if player.get("sprinting_now") == true:
			_chase_sprinted = true
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
		play_move()
	else:
		# Patrol logic
		_check_apex_dodger()
		patrol_timer += delta
		if is_idle:
			idle_timer += delta
			velocity = Vector2.ZERO
			play_idle()
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
			play_move()
	move_and_slide()

# Badge #11 (Apex Dodger): tumakbo (sprint) si James at nakatakas sa habol
# nang hindi inatake at hindi nawalan ng Health
func _check_apex_dodger():
	if not _badge_chasing:
		return
	_badge_chasing = false
	if _chase_sprinted and not _chase_attacked and player.get("is_dead") != true:
		Global.unlock_badge("apex_dodger")
	_chase_sprinted = false
	_chase_attacked = false
