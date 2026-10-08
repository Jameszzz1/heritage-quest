extends Control


@export var player: Node2D


@onready var minimap_cam = $SubViewportContainer/SubViewport/Camera2D
@onready var minimap_viewport = $SubViewportContainer/SubViewport
@onready var player_marker = $PlayerMarker
@onready var frame = $Frame
@onready var location_label = $LocationLabel


# ============================================================
# MARKER STORAGE
# ============================================================

var npc_marker_nodes: Dictionary = {}

var enemy_dot_pool: Array[TextureRect] = []
var location_dot_pool: Array[TextureRect] = []


# ============================================================
# MARKER TEXTURES
# ============================================================

var dog_marker_texture = preload(
	"res://assets/sprites/characters/dog-marker.png"
)

var snake_marker_texture = preload(
	"res://assets/sprites/characters/snake-marker.png"
)

var yellow_location_texture = preload(
	"res://assets/sprites/things/dot.png"
)


# ============================================================
# READY
# ============================================================

func _ready():

	minimap_viewport.world_2d = get_viewport().world_2d

	minimap_cam.enabled = true
	minimap_cam.zoom = Vector2(0.2, 0.2)

	_setup_npc_marker_nodes()

	_center_player_marker()


# ============================================================
# PLAYER MARKER
# ============================================================

func _center_player_marker() -> void:

	var center = frame.position + (
		frame.size / 2.0
	)

	player_marker.position = (
		center - player_marker.size / 2.0
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

		return frame.position + (
			frame.size / 2.0
		)

	var relative = (
		world_pos - player.global_position
	)

	var center = frame.position + (
		frame.size / 2.0
	)

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

	var relative = (
		world_pos - player.global_position
	)

	var minimap_offset = (
		relative * minimap_cam.zoom.x
	)

	var center = frame.position + (
		frame.size / 2.0
	)

	var marker_pos = center + minimap_offset

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
	# PLAYER / LOCATION LABEL
	# ========================================================

	_center_player_marker()

	location_label.text = Global.current_location


	# ========================================================
	# MINIMAP CAMERA
	# ========================================================

	minimap_cam.global_position = (
		player.global_position
	)


	# ========================================================
	# PLAYER
	# ========================================================

	_center_player_marker()


	# ========================================================
	# NPC MARKERS
	# ========================================================

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

		if not npc_marker_nodes.has(
			npc.marker_id
		):

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


		marker.visible = _is_inside_minimap(
			npc.global_position
		)


	# ========================================================
	# ENEMY MARKERS
	# ========================================================

	var enemies = get_tree().get_nodes_in_group(
		"minimap_enemy"
	)


	_ensure_dot_pool(
		enemies.size()
	)


	for i in range(enemy_dot_pool.size()):

		var enemy_dot := enemy_dot_pool[i]


		if (
			i < enemies.size()
			and is_instance_valid(enemies[i])
		):

			var enemy = enemies[i]


			# =================================================
			# CHOOSE ENEMY MARKER
			# =================================================

			if "enemy_id" in enemy:

				if enemy.enemy_id == "maragtas":

					enemy_dot.texture = (
						snake_marker_texture
					)

				elif enemy.enemy_id == "gahum":

					enemy_dot.texture = (
						dog_marker_texture
					)

				else:

					enemy_dot.texture = (
						dog_marker_texture
					)

			else:

				enemy_dot.texture = (
					dog_marker_texture
				)


			# =================================================
			# POSITION
			# =================================================

			var enemy_pos = _world_to_minimap(
				enemy.global_position
			)


			enemy_dot.position = (
				enemy_pos - enemy_dot.size / 2.0
			)


			# =================================================
			# ONLY SHOW INSIDE CIRCLE
			# =================================================

			enemy_dot.visible = _is_inside_minimap(
				enemy.global_position
			)

		else:

			enemy_dot.visible = false


	# ========================================================
	# YELLOW LOCATION MARKERS
	# ========================================================

	var locations = get_tree().get_nodes_in_group(
		"minimap_location"
	)


	_ensure_location_dot_pool(
		locations.size()
	)


	var center = frame.position + (
		frame.size / 2.0
	)


	# Keep the yellow dot slightly inside the circle border
	var max_radius = (
		min(frame.size.x, frame.size.y) / 2.0
	)


	for i in range(location_dot_pool.size()):

		var dot = location_dot_pool[i]


		if i < locations.size():

			var location = locations[i]


			if not is_instance_valid(location):

				dot.visible = false

				continue


			# =================================================
			# DIRECTION FROM PLAYER TO LOCATION
			# =================================================

			var relative = (
				location.global_position
				- player.global_position
			)


			# Convert world distance to minimap distance
			var offset = (
				relative * minimap_cam.zoom.x
			)


			# =================================================
			# CLAMP TO CIRCLE BORDER
			# =================================================

			if offset.length() > max_radius:

				offset = (
					offset.normalized()
					* max_radius
				)


			# =================================================
			# FINAL MARKER POSITION
			# =================================================

			var marker_position = (
				center + offset
			)


			dot.position = (
				marker_position
				- dot.size / 2.0
			)


			dot.visible = true

		else:

			dot.visible = false


# ============================================================
# ENEMY MARKER POOL
# ============================================================

func _ensure_dot_pool(
	needed_count: int
) -> void:

	while enemy_dot_pool.size() < needed_count:

		var dot := TextureRect.new()


		dot.custom_minimum_size = Vector2(
			8,
			8
		)


		dot.size = Vector2(
			8,
			8
		)


		dot.expand_mode = (
			TextureRect.EXPAND_IGNORE_SIZE
		)


		dot.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)


		dot.texture = dog_marker_texture

		dot.visible = false

		dot.z_index = 100


		add_child(dot)

		enemy_dot_pool.append(dot)


# ============================================================
# YELLOW LOCATION MARKER POOL
# ============================================================

func _ensure_location_dot_pool(
	needed_count: int
) -> void:

	while location_dot_pool.size() < needed_count:

		var dot := TextureRect.new()


		dot.custom_minimum_size = Vector2(
			8,
			8
		)


		dot.size = Vector2(
			8,
			8
		)


		dot.expand_mode = (
			TextureRect.EXPAND_IGNORE_SIZE
		)


		dot.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)


		dot.texture = yellow_location_texture

		dot.visible = false

		dot.z_index = 100


		add_child(dot)

		location_dot_pool.append(dot)
