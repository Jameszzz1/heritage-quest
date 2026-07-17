extends Node
@onready var title_label = $CanvasLayer/Title
@onready var narration_label = $CanvasLayer/Narration
@onready var skip_prompt_label = $CanvasLayer/SkipPrompt

var narration_parts = [
	"In the heart of Mindanao lies SOCCSKSARGEN,",
	"a region rich in history and resilient people.",
	"But as time passes, culture begins to fade.",
	"Stories are forgotten.",
	"Traditions are lost.",
	"You are James,",
	"a Heritage Archivist.",
	"Your mission is to travel the four provinces,",
	"learn from the guardians of the past,",
	"and preserve their legacy in the Digital Knowledge Vault."
]

var part_index = 0
var narrator_text = ""
var displayed_text = ""
var char_index = 0
var typing_speed = 0.03
var timer = 0.0
var typing_done = false
var auto_delay = 1
var skip_tween: Tween = null

func _ready():
	title_label.modulate.a = 0.0
	narration_label.text = ""
	skip_prompt_label.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)
	start_typing()
	_start_skip_blink()


func start_typing():
	narrator_text = narration_parts[part_index]
	displayed_text = ""
	char_index = 0
	timer = 0.0
	typing_done = false

	narration_label.text = ""
	narration_label.modulate.a = 1.0

	set_process(true)

func _process(delta):
	if typing_done:
		timer += delta

		if timer >= auto_delay:
			timer = 0.0
			next_part()

		return

	timer += delta
	if timer >= typing_speed:
		timer = 0.0

		if char_index < narrator_text.length():
			displayed_text += narrator_text[char_index]
			narration_label.text = displayed_text
			char_index += 1
		else:
			typing_done = true
			timer = 0.0

func _start_skip_blink():
	skip_prompt_label.modulate.a = 0.0
	skip_tween = create_tween()
	skip_tween.set_loops()
	skip_tween.tween_property(skip_prompt_label, "modulate:a", 1.0, 0.8)
	skip_tween.tween_property(skip_prompt_label, "modulate:a", 0.0, 0.8)

func _stop_skip_blink():
	if skip_tween:
		skip_tween.kill()
		skip_tween = null
	skip_prompt_label.modulate.a = 0.0

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if not typing_done:
				typing_done = true
				narration_label.text = narrator_text
			else:
				next_part()

func next_part():

	var tween = create_tween()
	tween.tween_property(narration_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_go_next)

func _go_next():
	part_index += 1

	if part_index < narration_parts.size():
		start_typing()
	else:
		get_tree().change_scene_to_file("res://scenes/provinces/south_cotabato/homebase.tscn")
