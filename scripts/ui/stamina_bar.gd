class_name StaminaBar
extends ProgressBar

@export var max_stamina: float = 100.0
@onready var timer = $Timer
@onready var damage_bar = $DamageBar
var stamina = 0 : set = _set_stamina

func _ready():
	min_value = 0
	max_value = max_stamina
	if Global.current_stamina == -1:
		init_stamina(max_stamina)
	else:
		max_value = max_stamina
		min_value = 0
		value = Global.current_stamina
		stamina = Global.current_stamina
		damage_bar.max_value = max_stamina
		damage_bar.value = Global.current_stamina

func _set_stamina(new_stamina):
	var prev_stamina = stamina
	stamina = clamp(new_stamina, 0, max_value)
	value = stamina
	Global.current_stamina = stamina
	if stamina < prev_stamina:
		timer.start()
	else:
		if is_instance_valid(damage_bar):
			damage_bar.value = stamina

func init_stamina(_stamina):
	stamina = _stamina
	max_value = _stamina
	min_value = 0
	value = _stamina
	damage_bar.max_value = _stamina
	damage_bar.value = _stamina

func _on_timer_timeout() -> void:
	if is_instance_valid(damage_bar):
		damage_bar.value = stamina

func _on_area_2d_body_entered(_body: Node2D) -> void:
	pass
