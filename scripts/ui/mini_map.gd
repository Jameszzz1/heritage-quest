extends Control

@export var player: Node2D
@export var map_center: Vector2 = Vector2(0, 0)
@export var map_size: Vector2 = Vector2(2000, 2000)

@onready var minimap_cam = $SubViewportContainer/SubViewport/Camera2D
@onready var player_marker = $PlayerMarker
@onready var frame = $Frame

func _ready():
	minimap_cam.zoom = Vector2(0.3, 0.3)

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var minimap_size = frame.size
	var frame_center = frame.position + (minimap_size / 2)
	var relative_pos = (world_pos - map_center) / map_size
	var result = frame_center + (relative_pos * minimap_size)
	result.x = clamp(result.x, frame.position.x + 2, frame.position.x + minimap_size.x - 2)
	result.y = clamp(result.y, frame.position.y + 2, frame.position.y + minimap_size.y - 2)
	return result

func _process(_delta):
	if player:
		minimap_cam.global_position = player.global_position
		var marker_pos = _world_to_minimap(player.global_position)
		player_marker.position = marker_pos - (player_marker.size / 2)
	else:
		print("Player not assigned!")
