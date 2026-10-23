extends Node2D

@export var chest_panel: Control

@onready var interaction_range: Area2D = $InteractionRange
@onready var interaction_label: Label = $InteractionLabel

var player_nearby: bool = false
var chest_open: bool = false


func _ready() -> void:
	interaction_label.hide()

	if is_instance_valid(chest_panel):
		chest_panel.hide()

	# Use the InteractionRange signals.
	if not interaction_range.body_entered.is_connected(
		_on_interaction_range_body_entered
	):
		interaction_range.body_entered.connect(
			_on_interaction_range_body_entered
		)

	if not interaction_range.body_exited.is_connected(
		_on_interaction_range_body_exited
	):
		interaction_range.body_exited.connect(
			_on_interaction_range_body_exited
		)


func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		if is_instance_valid(chest_panel) and chest_panel.visible:
			close_chest()
		else:
			open_chest()

	if chest_open and Input.is_action_just_pressed("ui_cancel"):
		close_chest()


func _on_interaction_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		interaction_label.show()


func _on_interaction_range_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		interaction_label.hide()
		close_chest()


func open_chest() -> void:
	if not player_nearby:
		return

	if not is_instance_valid(chest_panel):
		push_warning("ChestPanel is not assigned in the Inspector.")
		return

	chest_open = true

	if chest_panel.has_method("open_panel"):
		chest_panel.call("open_panel")
	else:
		chest_panel.show()


func close_chest() -> void:
	chest_open = false

	if is_instance_valid(chest_panel):
		if chest_panel.has_method("close_panel"):
			chest_panel.call("close_panel")
		else:
			chest_panel.hide()
