extends Control

@export var player: Node2D

@onready var minimap_cam = $SubViewportContainer/SubViewport/Camera2D
@onready var player_marker = $PlayerMarker
@onready var frame = $Frame

var npc_marker_nodes: Dictionary = {}

var enemy_dot_pool: Array[TextureRect] = []


func _ready():
	minimap_cam.zoom = Vector2(0.3, 0.3)

	_setup_npc_marker_nodes()

	# Put player marker in the center immediately
	_center_player_marker()


# ============================================================
# PLAYER MARKER
# ============================================================

func _center_player_marker() -> void:
	var center = frame.position + (frame.size / 2.0)

	player_marker.position = (
		center - (player_marker.size / 2.0)
	)


# ============================================================
# NPC MARKERS
# ============================================================

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


# ============================================================
# WORLD POSITION → MINIMAP POSITION
# ============================================================

func _world_to_minimap(world_pos: Vector2) -> Vector2:

	if not is_instance_valid(player):
		return frame.position + frame.size / 2.0

	# Distance between object and player
	var relative = world_pos - player.global_position

	# Center of circular minimap
	var center = frame.position + (frame.size / 2.0)

	# Convert world distance to minimap distance
	var result = center + (
		relative * minimap_cam.zoom.x
	)

	return result


# ============================================================
# CHECK IF MARKER IS INSIDE CIRCLE
# ============================================================

func _is_inside_minimap(world_pos: Vector2) -> bool:

	if not is_instance_valid(player):
		return false

	var relative = world_pos - player.global_position

	var minimap_offset = (
		relative * minimap_cam.zoom.x
	)

	var center = frame.position + (frame.size / 2.0)

	var marker_pos = center + minimap_offset

	# Circle radius
	# -8 keeps markers away from the gold border
	var radius = (
		min(frame.size.x, frame.size.y) / 2.0
	) - 8.0

	return marker_pos.distance_to(center) <= radius


# ============================================================
# MAIN UPDATE
# ============================================================

func _process(_delta):

	if not is_instance_valid(player):
		return


	# ========================================================
	# MINIMAP CAMERA
	# ========================================================

	# Camera follows player
	minimap_cam.global_position = player.global_position


	# ========================================================
	# PLAYER
	# ========================================================

	# Player always stays in the center
	_center_player_marker()


	# ========================================================
	# NPC MARKERS
	# ========================================================

	# Hide all NPC markers first
	for marker in npc_marker_nodes.values():
		marker.visible = false


	var npcs = get_tree().get_nodes_in_group(
		"minimap_npc"
	)


	for npc in npcs:

		if not is_instance_valid(npc):
			continue

		if not "marker_id" in npc:
			continue

		if npc.marker_id == "":
			continue

		if not npc_marker_nodes.has(npc.marker_id):
			continue


		var marker: TextureRect = (
			npc_marker_nodes[npc.marker_id]
		)


		var npc_pos = _world_to_minimap(
			npc.global_position
		)


		marker.position = (
			npc_pos - marker.size / 2.0
		)


		# Only show NPC if inside circle
		marker.visible = _is_inside_minimap(
			npc.global_position
		)


	# ========================================================
	# ENEMY MARKERS
	# ========================================================

	var enemies = get_tree().get_nodes_in_group(
		"minimap_enemy"
	)


	_ensure_dot_pool(enemies.size())


	for i in range(enemy_dot_pool.size()):

		var dot := enemy_dot_pool[i]


		if (
			i < enemies.size()
			and is_instance_valid(enemies[i])
		):

			var enemy_pos = _world_to_minimap(
				enemies[i].global_position
			)


			dot.position = (
				enemy_pos - dot.size / 2.0
			)


			# Only show enemy if inside circle
			dot.visible = _is_inside_minimap(
				enemies[i].global_position
			)

		else:

			dot.visible = false


# ============================================================
# ENEMY MARKER POOL
# ============================================================

func _ensure_dot_pool(needed_count: int) -> void:

	while enemy_dot_pool.size() < needed_count:

		var dot := TextureRect.new()


		# ====================================================
		# DOG MARKER SIZE
		# ====================================================

		dot.custom_minimum_size = Vector2(8, 8)
		dot.size = Vector2(8, 8)


		# ====================================================
		# PIXEL ART SETTINGS
		# ====================================================

		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		dot.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)


		# ====================================================
		# DOG MARKER IMAGE
		# ====================================================

		dot.texture = load(
			"res://assets/sprites/characters/dog-marker.png"
		)


		dot.visible = false

		add_child(dot)

		enemy_dot_pool.append(dot)
