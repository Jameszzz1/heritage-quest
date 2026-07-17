extends CanvasLayer

@onready var panel = $NinePatchRect
@onready var title_label = $NinePatchRect/Title
@onready var body_label = $NinePatchRect/Body
@onready var prompt_label = $NinePatchRect/Prompt

var steps = [
	{
		"title": "Basic Controls",
		"body": "Use WASD to move James around the plaza."
	},
	{
		"title": "Interaction",
		"body": "Approach the Heritage Pillar and press E to interact with it"
	},
	{
		"title": "Survival Mechanic",
		"body": "James is getting hungry. Head to the pier and complete the Fishing Mini-game to restore his energy."
	}
]

var current_step = 0
var is_active = false
var prompt_tween: Tween = null

func _ready():
	if Gamestate.tutorial_shown:
		panel.visible = false
		set_process_input(false)
		return

	Gamestate.set_tutorial_shown()
	panel.modulate.a = 0.0
	panel.self_modulate = Color(1, 1, 1, 0.9)
	show_step(current_step)

func show_step(index: int):
	is_active = true
	panel.visible = true
	title_label.text = steps[index]["title"]
	body_label.text = steps[index]["body"]
	prompt_label.text = "Press Enter to continue"
	prompt_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_callback(_start_prompt_blink)

func _start_prompt_blink():
	prompt_tween = create_tween()
	prompt_tween.set_loops()
	prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.8)
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.8)

func _stop_prompt_blink():
	if prompt_tween:
		prompt_tween.kill()
		prompt_tween = null
	prompt_label.modulate.a = 0.0

func _input(event):
	if not is_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			next_step()

func next_step():
	_stop_prompt_blink()
	is_active = false
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_go_next)

func _go_next():
	current_step += 1
	if current_step < steps.size():
		show_step(current_step)
	else:
		panel.visible = false
		set_process_input(false)
