extends CharacterBody2D

signal grip_changed(ratio: float)
signal step_done(quality: String)
signal fell

enum State { IDLE, HOLD, CLIMBING, FALLING }

@export var grip_time := 15.0
@export var miss_grip_penalty := 3.0
@export var climb_anim_time := 0.35

var state: State = State.IDLE
var grip := 15.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _ready() -> void:
	grip = grip_time
	_play("idle")

func _play(anim: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		push_warning("PLAYER: Walang animation na '%s'" % anim)

# side: "left" = A, "right" = D, "both" = A+D
func show_pose(side: String) -> void:
	match side:
		"left":
			_play("left_up")
		"right":
			_play("right_up")
		_:
			_play("hold")

func begin_climb() -> void:
	state = State.HOLD
	grip = grip_time
	_play("hold")                 # panimulang pose lang
	grip_changed.emit(1.0)

func resume_climb() -> void:
	# pagkatapos mahulog at bumalik sa checkpoint
	state = State.HOLD
	grip = grip_time
	_play("hold")
	grip_changed.emit(1.0)

func reset_to_idle() -> void:
	state = State.IDLE
	grip = grip_time
	_play("idle")
	grip_changed.emit(1.0)

func _process(delta: float) -> void:
	if state != State.HOLD:
		return
	grip -= delta
	grip_changed.emit(clampf(grip / grip_time, 0.0, 1.0))
	if grip <= 0.0:
		fall()

func climb(quality: String, side: String) -> void:
	if state != State.HOLD:
		return
	state = State.CLIMBING
	show_pose(side)
	await get_tree().create_timer(climb_anim_time).timeout
	if state != State.CLIMBING:
		return
	grip = grip_time
	state = State.HOLD
	# HINDI na bumabalik sa "hold": nananatili ang huling pose
	grip_changed.emit(1.0)
	step_done.emit(quality)

func slip() -> void:
	if state != State.HOLD:
		return
	grip -= miss_grip_penalty
	grip_changed.emit(clampf(grip / grip_time, 0.0, 1.0))
	if grip <= 0.0:
		fall()

func fall() -> void:
	if state == State.FALLING:
		return
	state = State.FALLING
	_play("fall")
	fell.emit()
