#Balbal
extends CharacterBody2D
@export var speed: float = 50.0
@export var chase_range: float = 30.0
@export var patrol_speed: float = 20.0
@export var attack_range: float = 15.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

# Tunog ng paniki: tutunog pag nasa loob ng sfx_range si James (hindi na kailangang sobrang lapit)
@export var sfx_range: float = 80.0
@export var sfx_interval_min: float = 2.0
@export var sfx_interval_max: float = 4.5
@export var sfx_volume_db: float = 0.0

@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

var bat_sound = preload("res://assets/audio/sfx/enemies_sfx/bat_.wav")

var screech_player: AudioStreamPlayer2D
var attack_player: AudioStreamPlayer2D
var screech_timer: float = 0.0
var in_sound_range: bool = false

var player: Node2D = null
var patrol_direction: Vector2 = Vector2(1, 0)
var patrol_timer: float = 0.0
var idle_timer: float = 0.0
var is_idle: bool = false
var attack_timer: float = 0.0
var enemy_id := "balbal"

# Para sa badge #11 (Apex Dodger)
var _badge_chasing: bool = false
var _chase_sprinted: bool = false
var _chase_attacked: bool = false

func _ready():
	add_to_group("minimap_enemy")
	player = get_tree().get_first_node_in_group("player")
	print("Balbal found player: ", player)
	print("Balbal animations: ", anim.get_animation_list())
	setup_sfx()
	play_idle()

# ---------------- ANIMATION ----------------

func play_idle():
	# Susubukan ang mga karaniwang pangalan; ang una na meron ang gagamitin
	for n in ["idle", "fly", "flap", "flutter"]:
		if anim.has_animation(n):
			anim.play(n)
			return
	anim.stop()

func play_move():
	for n in ["run", "fly", "move", "flap", "flutter", "walk"]:
		if anim.has_animation(n):
			anim.play(n)
			return

# ---------------- SOUND ----------------

func setup_sfx():
	# Magkahiwalay ang player ng tunog sa paligid at sa atake para hindi nila pinuputol ang isa't isa
	screech_player = _make_sfx_player()
	attack_player = _make_sfx_player()

func _make_sfx_player() -> AudioStreamPlayer2D:
	var p = AudioStreamPlayer2D.new()
	p.stream = bat_sound
	p.volume_db = sfx_volume_db
	p.max_distance = 300.0   # mas malayo ang paniki, mas mahina ang tunog
	if AudioServer.get_bus_index("SFX") != -1:
		p.bus = "SFX"
	add_child(p)
	return p

func update_screech(delta: float, distance: float):
	# Walang ambient na tunog kung masyadong malayo, o kung umaatake na (attack sound na ang bahala)
	if distance >= sfx_range or distance < attack_range:
		in_sound_range = false
		return

	# Pagpasok sa range, may kaunting random na delay para hindi sabay-sabay ang mga paniki
	if not in_sound_range:
		in_sound_range = true
		screech_timer = randf_range(0.0, 0.8)

	screech_timer -= delta
	if screech_timer > 0.0:
		return
	# Hintayin munang matapos ang kasalukuyang tunog
	if screech_player.playing or attack_player.playing:
		return

	screech_player.pitch_scale = randf_range(0.9, 1.15)   # konting pagbabago ng boses
	screech_player.play()
	screech_timer = randf_range(sfx_interval_min, sfx_interval_max)

func play_attack_sound():
	screech_player.stop()
	attack_player.pitch_scale = randf_range(1.1, 1.3)   # mas matinis pag umaatake
	attack_player.play()

# ---------------- MAIN LOOP ----------------

func _physics_process(delta):
	if player == null:
		return
	attack_timer -= delta
	var distance = global_position.distance_to(player.global_position)

	update_screech(delta, distance)

	if distance < attack_range:
		# Attack the player
		_badge_chasing = true
		velocity = Vector2.ZERO
		play_idle()
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			print("Bat attacked! Distance: ", distance)
			_chase_attacked = true
			# Tunog ng atake (hindi kung patay na si James)
			if player.get("is_dead") != true:
				play_attack_sound()
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
