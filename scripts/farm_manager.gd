
extends Node

@export var ground_layer: TileMapLayer
@export var farm_overlay: TileMapLayer

# Tilled-soil tile settings
@export var tilled_source_id: int = 5
@export var tilled_atlas_coords: Vector2i = Vector2i(3, 4)
@export var tilled_alternative_tile: int = 0


# Tracks tiles already tilled during this session
var tilled_plots: Dictionary = {}


func _ready() -> void:
	if ground_layer == null:
		push_warning("FarmManager: Assign Ground Layer in the Inspector.")

	if farm_overlay == null:
		push_warning("FarmManager: Assign FarmOverlay in the Inspector.")


func _process(_delta: float) -> void:
	# Only till when E/interact is pressed.
	if not Input.is_action_just_pressed("interact"):
		return

	var james := get_tree().get_first_node_in_group("player") as Node2D

	if james == null:
		return

	# Require the shovel to be equipped.
	if not Global.shovel_equipped:
		print("Equip your shovel first.")
		return

	# Require the shovel to exist in inventory.
	if int(Global.inventory_items.get("shovel", 0)) <= 0:
		print("You need a shovel.")
		return

	till_player_tile(james)


func till_player_tile(james: Node2D) -> void:
	if ground_layer == null:
		push_warning("FarmManager: Ground Layer is not assigned.")
		return

# Check the tile beneath James's feet.
	var feet_position: Vector2 = james.global_position + Vector2(0, 8)

	var player_local: Vector2 = ground_layer.to_local(
		feet_position
	)

	var player_cell: Vector2i = ground_layer.local_to_map(
		player_local
	)

	# Check whether a tile exists beneath James.
	var tile_data: TileData = ground_layer.get_cell_tile_data(
		player_cell
	)

	if tile_data == null:
		print("There is no ground beneath you.")
		return

	# Only allow tiles marked farmable.
	if not bool(tile_data.get_custom_data("farmable")):
		print("This tile cannot be tilled.")
		return

	# Prevent tilling the same tile twice.
	if tilled_plots.has(player_cell):
		print("This tile is already tilled.")
		return

	# Replace the tile on Ground with the tilled-soil tile.
	ground_layer.set_cell(
		player_cell,
		tilled_source_id,
		tilled_atlas_coords,
		tilled_alternative_tile
	)

	tilled_plots[player_cell] = true

	print("Tilled tile: ", player_cell)
