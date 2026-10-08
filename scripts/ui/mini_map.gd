extends Control

@export var player: Node2D

@onready var minimap_cam: Camera2D = $SubViewportContainer/SubViewport/Camera2D
@onready var minimap_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var player_marker: TextureRect = $PlayerMarker
@onready var frame: Control = $Frame

var npc_marker_nodes: Dictionary = {}

var enemy_marker_pool: Array[TextureRect] = []
var location_dot_pool: Array[TextureRect] = []

const LOCATION_DOT_SIZE: float = 8.0
const ENEMY_MARKER_SIZE: Vector2 = Vector2(10.0, 10.0)


func _ready() -> void:
	minimap_viewport.world_2d = get_viewport().world_2d
	minimap_cam.zoom = Vector2(0.2, 0.2)

	_setup_npc_marker_nodes()


# =========================================================
# NPC MARKERS
# =========================================================

func _setup_npc_marker_nodes() -> void:

	var possible_ids: Dictionary = {
		"bai_linay": "BaiLinayMarker",
		"ayu": "AyuMarker",
		"ameer": "AmeerMarker",
		"sandawa": "SandawaMarker"
	}

	for id in possible_ids.keys():

		var node_name: String = str(possible_ids[id])
		var node: Node = get_node_or_null(node_name)

		if node != null:
			npc_marker_nodes[id] = node
			node.visible = false


# =========================================================
# PROCESS
# =========================================================

func _process(_delta: float) -> void:

	if player == null:
		return

	minimap_cam.global_position = player.global_position

	var center: Vector2 = frame.position + (frame.size / 2.0)


	# =====================================================
	# PLAYER
	# =====================================================

	player_marker.position = (
		center - (player_marker.size / 2.0)
	)


	# =====================================================
	# NPCS
	# =====================================================

	for marker in npc_marker_nodes.values():
		marker.visible = false

	var npcs: Array = get_tree().get_nodes_in_group("minimap_npc")

	for npc in npcs:

		if not is_instance_valid(npc):
			continue

		if not "marker_id" in npc:
			continue

		var marker_id: String = str(npc.marker_id)

		if not npc_marker_nodes.has(marker_id):
			continue

		var marker: TextureRect = npc_marker_nodes[marker_id]

		var offset: Vector2 = (
			npc.global_position - player.global_position
		) * minimap_cam.zoom.x

		var marker_position: Vector2 = center + offset

		if _is_inside_minimap(marker_position):

			marker.position = (
				marker_position - (marker.size / 2.0)
			)

			marker.visible = true


	# =====================================================
	# ENEMIES
	# =====================================================

	var enemies: Array = get_tree().get_nodes_in_group(
		"minimap_enemy"
	)

	_ensure_enemy_marker_pool(enemies.size())

	var enemy_index: int = 0

	for enemy in enemies:

		if not is_instance_valid(enemy):
			continue

		if enemy_index >= enemy_marker_pool.size():
			break

		var marker: TextureRect = enemy_marker_pool[enemy_index]


		# ---------------------------------------------
		# Determine enemy type
		# ---------------------------------------------

		var marker_type: String = ""

		# DOG
		if enemy.is_in_group("minimap_dog"):
			marker_type = "dog"

		# SNAKE / MARAGTAS
		elif enemy.is_in_group("minimap_snake"):
			marker_type = "snake"

		# Fallback using marker_id
		elif "marker_id" in enemy:

			var id: String = str(enemy.marker_id)

			if id == "dog":
				marker_type = "dog"

			elif id == "snake":
				marker_type = "snake"


		# Unknown enemy
		if marker_type == "":
			marker.visible = false
			continue


		# ---------------------------------------------
		# DOG TEXTURE
		# ---------------------------------------------

		if marker_type == "dog":

			marker.texture = preload(
				"res://assets/sprites/characters/dog-marker.png"
			)


		# ---------------------------------------------
		# SNAKE TEXTURE
		# ---------------------------------------------

		elif marker_type == "snake":

			marker.texture = preload(
				"res://assets/sprites/characters/snake-marker.png"
			)


		# ---------------------------------------------
		# POSITION
		# ---------------------------------------------

		var enemy_offset: Vector2 = (
			enemy.global_position - player.global_position
		) * minimap_cam.zoom.x

		var enemy_position: Vector2 = center + enemy_offset


		if _is_inside_minimap(enemy_position):

			marker.position = (
				enemy_position - (marker.size / 2.0)
			)

			marker.visible = true

		else:

			marker.visible = false


		enemy_index += 1


	# Hide unused markers
	for i in range(enemy_index, enemy_marker_pool.size()):
		enemy_marker_pool[i].visible = false


	# =====================================================
	# YELLOW DESTINATION MARKERS
	# =====================================================

	var locations: Array = get_tree().get_nodes_in_group(
		"minimap_location"
	)

	_ensure_location_dot_pool(locations.size())

	var max_radius: float = min(
		frame.size.x,
		frame.size.y
	) / 2.0


	for i in range(location_dot_pool.size()):

		var dot: TextureRect = location_dot_pool[i]

		if i < locations.size():

			var location: Node = locations[i]

			if not is_instance_valid(location):

				dot.visible = false
				continue


			var relative: Vector2 = (
				location.global_position - player.global_position
			)

			var offset: Vector2 = (
				relative * minimap_cam.zoom.x
			)


			if offset.length() > max_radius:

				offset = (
					offset.normalized() * max_radius
				)


			var marker_position: Vector2 = center + offset

			dot.position = (
				marker_position - (dot.size / 2.0)
			)

			dot.visible = true

		else:

			dot.visible = false


# =========================================================
# ENEMY MARKER POOL
# =========================================================

func _ensure_enemy_marker_pool(needed_count: int) -> void:

	while enemy_marker_pool.size() < needed_count:

		var marker := TextureRect.new()

		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		marker.size = ENEMY_MARKER_SIZE

		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE

		marker.visible = false

		marker.z_index = 10

		add_child(marker)

		enemy_marker_pool.append(marker)


# =========================================================
# LOCATION MARKER POOL
# =========================================================

func _ensure_location_dot_pool(needed_count: int) -> void:

	while location_dot_pool.size() < needed_count:

		var dot := TextureRect.new()

		dot.texture = preload(
			"res://assets/sprites/things/dot.png"
		)

		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		dot.size = Vector2(
			LOCATION_DOT_SIZE,
			LOCATION_DOT_SIZE
		)

		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		dot.visible = false

		dot.z_index = 10

		add_child(dot)

		location_dot_pool.append(dot)


# =========================================================
# MINIMAP CIRCLE CHECK
# =========================================================

func _is_inside_minimap(position: Vector2) -> bool:

	var center: Vector2 = (
		frame.position + (frame.size / 2.0)
	)

	var radius: float = min(
		frame.size.x,
		frame.size.y
	) / 2.0

	return position.distance_to(center) <= radius
