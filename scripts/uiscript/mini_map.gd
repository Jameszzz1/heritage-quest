extends Control
@export var player: Node2D
@export var map_center: Vector2 = Vector2(0, 0)
@export var map_size: Vector2 = Vector2(2000, 2000)
@onready var minimap_cam = $SubViewportContainer/SubViewport/Camera2D
@onready var player_marker = $PlayerMarker
@onready var frame = $Frame

var npc_marker_nodes: Dictionary = {}

var enemy_dot_pool: Array[ColorRect] = []
var enemy_dot_texture_size := 2

func _ready():
	minimap_cam.zoom = Vector2(0.3, 0.3)
	_setup_npc_marker_nodes()

func _setup_npc_marker_nodes() -> void:
	var possible_ids = {
		"bai_linay": "BaiLinayMarker",
		"ayu": "AyuMarker",
		"ameer": "AmeerMarker",
		"sandawa": "SandawaMarker",
	}
	for id in possible_ids.keys():
		var node_name: String = possible_ids[id]
		var node = get_node_or_null(node_name)
		if node != null:
			npc_marker_nodes[id] = node
			node.visible = false

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

	# ---------- NPC markers ----------
	for marker in npc_marker_nodes.values():
		marker.visible = false

	var npcs = get_tree().get_nodes_in_group("minimap_npc")
	for npc in npcs:
		if not "marker_id" in npc or npc.marker_id == "":
			continue
		if not npc_marker_nodes.has(npc.marker_id):
			continue

		var marker: TextureRect = npc_marker_nodes[npc.marker_id]
		var npc_pos = _world_to_minimap(npc.global_position)
		marker.position = npc_pos - (marker.size / 2)
		marker.visible = true

	# ---------- Enemy red dots ----------
	var enemies = get_tree().get_nodes_in_group("minimap_enemy")
	_ensure_dot_pool(enemies.size())

	for i in range(enemy_dot_pool.size()):
		var dot := enemy_dot_pool[i]
		if i < enemies.size() and is_instance_valid(enemies[i]):
			var enemy_pos = _world_to_minimap(enemies[i].global_position)
			dot.position = enemy_pos - (dot.size / 2)
			dot.visible = true
		else:
			dot.visible = false

func _ensure_dot_pool(needed_count: int) -> void:
	while enemy_dot_pool.size() < needed_count:
		var dot := ColorRect.new()
		dot.size = Vector2(enemy_dot_texture_size, enemy_dot_texture_size)
		dot.color = Color(1.0, 0.15, 0.15, 1.0)
		dot.visible = false
		add_child(dot)
		enemy_dot_pool.append(dot)
