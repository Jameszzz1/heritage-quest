
extends Node

@export var ground_layer: TileMapLayer
@export var farm_overlay: TileMapLayer

# Tilled-soil tile in FarmOverlay's separate TileSet
@export var tilled_source_id: int = 5
@export var tilled_atlas_coords: Vector2i = Vector2i(3, 4)
@export var tilled_alternative_tile: int = 0

@export var interaction_distance: float = 32.0

var tilled_plots: Dictionary = {}


func _ready() -> void:
	if ground_layer == null:
		push_warning("FarmManager: Assign Ground Layer in the Inspector.")

	if farm_overlay == null:
		push_warning("FarmManager: Assign FarmOverlay in the Inspector.")


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("interact"):
		return

	var james := get_tree().get_first_node_in_group("player") as Node2D

	if james == null:
		return

	if not Global.shovel_equipped:
		print("Equip your shovel first.")
		return

	if int(Global.inventory_items.get("shovel", 0)) <= 0:
		print("You need a shovel.")
		return

	till_nearest_plot(james)


func till_nearest_plot(james: Node2D) -> void:
	if ground_layer == null or farm_overlay == null:
		push_warning("FarmManager: Assign Ground and FarmOverlay.")
		return

	# Convert James's position into Ground's tile coordinates.
	var player_local: Vector2 = ground_layer.to_local(
		james.global_position
	)
	var player_cell: Vector2i = ground_layer.local_to_map(
		player_local
	)

	var nearest_cell := Vector2i.ZERO
	var nearest_distance := INF
	var found_plot := false

	# Search nearby cells for farmable land.
	for x in range(-1, 2):
		for y in range(-1, 2):
			var cell: Vector2i = player_cell + Vector2i(x, y)

			var tile_data: TileData = ground_layer.get_cell_tile_data(cell)

			if tile_data == null:
				continue

			if not bool(tile_data.get_custom_data("farmable")):
				continue

			if tilled_plots.has(cell):
				continue

			# Check whether James is close enough.
			var cell_center: Vector2 = ground_layer.to_global(
				ground_layer.map_to_local(cell)
			)
			var distance: float = james.global_position.distance_to(
				cell_center
			)

			if distance > interaction_distance:
				continue

			if distance < nearest_distance:
				nearest_distance = distance
				nearest_cell = cell
				found_plot = true

	if not found_plot:
		print("No untilled farmable soil nearby.")
		return

	# Use the SAME cell coordinates on the aligned FarmOverlay.
	# Do not erase or replace the original Ground tile.
# Replace the original Ground tile with tilled soil.
	ground_layer.set_cell(
		nearest_cell,
		tilled_source_id,
		tilled_atlas_coords,
		tilled_alternative_tile
	)

	tilled_plots[nearest_cell] = true

	print("Soil tilled successfully at: ", nearest_cell)
