extends ProgressBar

@onready var damage_bar = $DamageBar
@onready var timer = $Timer
@onready var label = $Label

var health: float = 100.0 : set = _set_health

func _ready():
	add_to_group("health_bar")
	max_value = 100
	damage_bar.max_value = 100
	value = health
	damage_bar.value = health
	label.text = str(value) + " / " + str(max_value)

func _set_health(new_health):
	var previous_value = value
	health = clamp(new_health, 0, max_value)
	value = health
	label.text = str(value) + " / " + str(max_value)
	if health < previous_value:
		timer.start()
	else:
		damage_bar.value = health

func _on_timer_timeout():
	damage_bar.value = value
