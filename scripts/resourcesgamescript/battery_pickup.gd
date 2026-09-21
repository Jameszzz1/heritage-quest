extends Area2D

@export var amount: int = 1
@export var pickup_sfx: AudioStream
@export var glow_enabled: bool = true

@onready var sprite: Sprite2D = $Sprite2D

var collected: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

	if glow_enabled:
		_setup_glow()

	# Konting lutang-lutang para kita sa dilim
	var base_y = sprite.position.y
	var tw = create_tween().set_loops()
	tw.tween_property(sprite, "position:y", base_y - 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", base_y, 0.6).set_trans(Tween.TRANS_SINE)

func _setup_glow():
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.8))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.set_offset(0, 0.0)
	gradient.set_offset(1, 1.0)

	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128

	var glow = PointLight2D.new()
	glow.texture = tex
	glow.texture_scale = 0.25
	glow.color = Color(1.0, 0.9, 0.3)
	glow.energy = 0.8
	add_child(glow)

func _on_body_entered(body):
	if collected or not body.is_in_group("player"):
		return

	collected = true
	Global.add_battery(amount)

	if pickup_sfx:
		var p = AudioStreamPlayer.new()
		p.stream = pickup_sfx
		get_tree().root.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()

	queue_free()
