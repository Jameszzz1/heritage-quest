extends TextureProgressBar

@onready var damage_bar = $DamageBar
@onready var timer = $Timer

var health = 100.0
var max_health = 100.0

func _ready():
	max_value = max_health
	value = health
	damage_bar.max_value = max_health
	damage_bar.value = health

func take_damage(amount: float):
	health = clamp(health - amount, 0, max_health)
	value = health
	timer.start(1.0)  # delay before damage bar follows

func heal(amount: float):
	health = clamp(health + amount, 0, max_health)
	value = health
	damage_bar.value = health  # instant update on heal

func _on_timer_timeout():
	damage_bar.value = health  # damage bar catches up
