# Gahum
extends CharacterBody2D
@export var speed: float = 50.0
@export var chase_range: float = 30.0
@export var patrol_speed: float = 20.0
@export var attack_range: float = 15.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

# Tahol habang hinahabol ka: random na pagitan ng bawat tahol (segundo)
@export var bark_interval_min: float = 1.5
@export var bark_interval_max: float = 3.5
@export var sfx_volume_db: float = 0.0

@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer

var bark_sounds: Array = [
	preload("res://assets/audio/sfx/enemies_sfx/1_bark_dog.mp3"),
	preload("res://assets/audio/sfx/enemies_sfx/2_bark_dog.mp3"),
	preload("res://assets/audio/sfx/enemies_sfx/3_bark_dog.mp3")
]
var bite_sound = preload("res://assets/audio/sfx/enemies_sfx/dog_bite.mp3")

var bark_player: AudioStreamPlayer2D
var bite_player: AudioStreamPlayer2D
var bark_timer: float = 0.0
var last_bark_index: int = -1
var was_chasing: bool = false

var player: Node2D = null
var patrol_direction: Vector2 = Vector2(1, 0)
var patrol_timer: float = 0.0
var idle_timer: float = 0.0
var is_idle: bool = false
var attack_timer: float = 0.0
var enemy_id := "gahum"

# Para sa badge #11 (Apex Dodger)
var _badge_chasing: bool = false
var _chase_sprinted: bool = false
var _chase_attacked: bool = false

func _ready():
	add_to_group("minimap_enemy")
	player = get_tree().get_first_node_in_group("player")
	print("Gahum found player: ", player)
	setup_sfx()
	anim.play("idle")

# ---------------- SOUND ----------------

func setup_sfx():
	# Magkahiwalay ang player ng tahol at kagat para hindi nila pinuputol ang isa't isa
	bark_player = _make_sfx_player()
	bite_player = _make_sfx_player()

func _make_sfx_player() -> AudioStreamPlayer2D:
	var p = AudioStreamPlayer2D.new()
	p.volume_db = sfx_volume_db
	p.max_distance = 300.0   # mas malayo ang aso, mas mahina ang tunog
	if AudioServer.get_bus_index("SFX") != -1:
		p.bus = "SFX"
	add_child(p)
	return p

func play_bark():
	# Hintayin munang matapos ang kasalukuyang tahol
	if bark_player.playing:
		return

	# Random na tahol, at hindi pareho sa huli para hindi paulit-ulit
	var idx = randi() % bark_sounds.size()
	if bark_sounds.size() > 1:
		while idx == last_bark_index:
			idx = randi() % bark_sounds.size()
	last_bark_index = idx

	bark_player.stream = bark_sounds[idx]
	bark_player.pitch_scale = randf_range(0.9, 1.1)   # konting pagbabago ng boses
	bark_player.play()

func play_bite():
	bite_player.stream = bite_sound
	bite_player.pitch_scale = randf_range(0.95, 1.05)
	bite_player.play()

# ---------------- MAIN LOOP ----------------

func _physics_process(delta):
	if player == null:
		return
	attack_timer -= delta
	var distance = global_position.distance_to(player.global_position)
	if distance < attack_range:
		# Attack the player
		was_chasing = false
		_badge_chasing = true
		velocity = Vector2.ZERO
		anim.play("idle")
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			print("Dog attacked! Distance: ", distance)
			_chase_attacked = true
			# Tunog ng kagat (hindi kung patay na si James)
			if player.get("is_dead") != true:
				play_bite()
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
		anim.play("run")

		# Tatahol agad pag nagsimulang humabol, tapos paminsan-minsan habang hinahabol ka
		if not was_chasing:
			was_chasing = true
			bark_timer = 0.0
		bark_timer -= delta
		if bark_timer <= 0.0:
			play_bark()
			bark_timer = randf_range(bark_interval_min, bark_interval_max)
	else:
		# Patrol logic
		was_chasing = false
		_check_apex_dodger()
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
					patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			velocity = patrol_direction * patrol_speed
			sprite.flip_h = patrol_direction.x < 0
			anim.play("run")
	move_and_slide()

# Badge #11 (Apex Dodger): tumakbo (sprint) si James at nakatakas sa habol
# nang hindi nakagat at hindi nawalan ng Health
func _check_apex_dodger():
	if not _badge_chasing:
		return
	_badge_chasing = false
	if _chase_sprinted and not _chase_attacked and player.get("is_dead") != true:
		Global.unlock_badge("apex_dodger")
	_chase_sprinted = false
	_chase_attacked = false
