extends Control

@export var next_scene_path: String = "res://scenes/ui/login.tscn"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_label: Label = $SkipLabel

var _transitioning: bool = false

func _ready() -> void:
	video_player.finished.connect(_go_to_next_scene)
	
	# Blinking effect for the skip label
	var blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(skip_label, "modulate:a", 0.3, 1.0)
	blink_tween.tween_property(skip_label, "modulate:a", 1.0, 1.0)

func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventKey and event.pressed:
		_go_to_next_scene()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_next_scene()
	elif event is InputEventJoypadButton and event.pressed:
		_go_to_next_scene()

func _go_to_next_scene() -> void:
	if _transitioning:
		return
	_transitioning = true
	
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	
	get_tree().change_scene_to_file(next_scene_path)
