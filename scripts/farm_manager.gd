
extends Node

@export var ground_layer: TileMapLayer

# Crop growth time after watering, in seconds.
@export var growth_time_seconds: float = 60.0

# Tilled soil
@export var tilled_source_id: int = 5
@export var tilled_atlas_coords: Vector2i = Vector2i(3, 4)
@export var tilled_alternative_tile: int = 0

# Eggplant tiles
@export var eggplant_source_id: int = 5
@export var eggplant_atlas_coords: Vector2i = Vector2i(5, 4)
@export var eggplant_watered_coords: Vector2i = Vector2i(5, 6)
@export var eggplant_ready_coords: Vector2i = Vector2i(7, 6)
@export var eggplant_alternative_tile: int = 0

# Corn tiles
@export var corn_source_id: int = 5
@export var corn_atlas_coords: Vector2i = Vector2i(5, 5)
@export var corn_watered_coords: Vector2i = Vector2i(5, 7)
@export var corn_ready_coords: Vector2i = Vector2i(7, 7)
@export var corn_alternative_tile: int = 0

# Pineapple tiles
@export var pineapple_source_id: int = 5
@export var pineapple_atlas_coords: Vector2i = Vector2i(6, 4)
@export var pineapple_watered_coords: Vector2i = Vector2i(6, 6)
@export var pineapple_ready_coords: Vector2i = Vector2i(8, 6)
@export var pineapple_alternative_tile: int = 0

# Cell coordinates -> state:
# "tilled", "eggplant_seeds", "corn_seeds",
# "pineapple_crown", or their "_watered"/"_ready" versions.
var plot_states: Dictionary = {}

# Cell coordinates -> remaining growth time in seconds.
var growth_timers: Dictionary = {}


func _ready() -> void:
	if ground_layer == null:
		push_warning("FarmManager: Assign Ground Layer in the Inspector.")


func _process(delta: float) -> void:
	_update_crop_growth(delta)

	if Input.is_action_just_pressed("interact"):
		_handle_interaction()


func _handle_interaction() -> void:
	if ground_layer == null:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var cell := _get_player_cell(player)
	var state := _get_plot_state(cell)

	# Harvest mature crops first.
	if state.ends_with("_ready"):
		harvest_crop(cell, state)
		return

	# Water planted crops.
	if state in ["eggplant_seeds", "corn_seeds", "pineapple_crown"]:
		if not Global.watering_can_equipped:
			print("Equip your watering can first.")
			return

		if int(Global.inventory_items.get("watering_can", 0)) <= 0:
			print("You need a watering can.")
			return

		water_crop(cell, state)
		return

	# A watered crop is already growing.
	if state.ends_with("_watered"):
		print("Your crop is growing. Please wait.")
		return

	# Plant on tilled soil.
	if state == "tilled":
		plant_crop(cell)
		return

	# Otherwise, till new ground using the shovel.
	if not Global.shovel_equipped:
		print("Equip your shovel first.")
		return

	if int(Global.inventory_items.get("shovel", 0)) <= 0:
		print("You need a shovel.")
		return

	till_player_tile(cell)


func _get_player_cell(player: Node2D) -> Vector2i:
	var feet_position: Vector2 = player.global_position + Vector2(0, 8)
	var local_position: Vector2 = ground_layer.to_local(feet_position)
	return ground_layer.local_to_map(local_position)


func _get_plot_state(cell: Vector2i) -> String:
	if plot_states.has(cell):
		return str(plot_states[cell])

	# Recover state from the actual Ground tile when possible.
	var source_id := ground_layer.get_cell_source_id(cell)
	var atlas := ground_layer.get_cell_atlas_coords(cell)

	if source_id == -1:
		return ""

	if source_id == tilled_source_id and atlas == tilled_atlas_coords:
		return "tilled"

	if source_id == eggplant_source_id:
		if atlas == eggplant_atlas_coords:
			return "eggplant_seeds"
		if atlas == eggplant_watered_coords:
			return "eggplant_seeds_watered"
		if atlas == eggplant_ready_coords:
			return "eggplant_seeds_ready"

	if source_id == corn_source_id:
		if atlas == corn_atlas_coords:
			return "corn_seeds"
		if atlas == corn_watered_coords:
			return "corn_seeds_watered"
		if atlas == corn_ready_coords:
			return "corn_seeds_ready"

	if source_id == pineapple_source_id:
		if atlas == pineapple_atlas_coords:
			return "pineapple_crown"
		if atlas == pineapple_watered_coords:
			return "pineapple_crown_watered"
		if atlas == pineapple_ready_coords:
			return "pineapple_crown_ready"

	return ""


func till_player_tile(cell: Vector2i) -> void:
	var tile_data := ground_layer.get_cell_tile_data(cell)

	if tile_data == null:
		print("There is no ground beneath you.")
		return

	if not bool(tile_data.get_custom_data("farmable")):
		print("This tile cannot be tilled.")
		return

	if _get_plot_state(cell) != "":
		print("This tile has already been worked.")
		return

	ground_layer.set_cell(
		cell,
		tilled_source_id,
		tilled_atlas_coords,
		tilled_alternative_tile
	)

	plot_states[cell] = "tilled"
	print("Tilled tile: ", cell)


func plant_crop(cell: Vector2i) -> void:
	var seed_id: String = Global.selected_seed

	if seed_id == "":
		print("Select seeds or a pineapple crown in your backpack first.")
		return

	if Global.get_backpack_item_count(seed_id) <= 0:
		print("You don't have any of that item left.")
		Global.selected_seed = ""
		return

	var source_id: int
	var atlas_coords: Vector2i
	var alternative_tile: int

	match seed_id:
		"eggplant_seeds":
			source_id = eggplant_source_id
			atlas_coords = eggplant_atlas_coords
			alternative_tile = eggplant_alternative_tile

		"corn_seeds":
			source_id = corn_source_id
			atlas_coords = corn_atlas_coords
			alternative_tile = corn_alternative_tile

		"pineapple_crown":
			source_id = pineapple_source_id
			atlas_coords = pineapple_atlas_coords
			alternative_tile = pineapple_alternative_tile

		_:
			print("That item cannot be planted.")
			return

	if not Global.remove_item(seed_id, 1):
		print("Could not consume the selected item.")
		return

	ground_layer.set_cell(
		cell,
		source_id,
		atlas_coords,
		alternative_tile
	)

	plot_states[cell] = seed_id
	growth_timers.erase(cell)

	print("Planted ", seed_id, " at ", cell)


func water_crop(cell: Vector2i, crop_id: String) -> void:
	var source_id: int
	var watered_coords: Vector2i
	var alternative_tile: int

	match crop_id:
		"eggplant_seeds":
			source_id = eggplant_source_id
			watered_coords = eggplant_watered_coords
			alternative_tile = eggplant_alternative_tile

		"corn_seeds":
			source_id = corn_source_id
			watered_coords = corn_watered_coords
			alternative_tile = corn_alternative_tile

		"pineapple_crown":
			source_id = pineapple_source_id
			watered_coords = pineapple_watered_coords
			alternative_tile = pineapple_alternative_tile

		_:
			print("This crop cannot be watered.")
			return

	ground_layer.set_cell(
		cell,
		source_id,
		watered_coords,
		alternative_tile
	)

	plot_states[cell] = crop_id + "_watered"
	growth_timers[cell] = maxf(growth_time_seconds, 0.1)

	print("Watered ", crop_id, ". Growth started at ", cell)


func _update_crop_growth(delta: float) -> void:
	if ground_layer == null:
		return

	# Duplicate keys so the dictionary can safely be updated.
	for cell in growth_timers.keys():
		var remaining: float = float(growth_timers[cell]) - delta
		growth_timers[cell] = remaining

		if remaining > 0.0:
			continue

		var state := str(plot_states.get(cell, ""))

		match state:
			"eggplant_seeds_watered":
				_set_crop_ready(
					cell,
					"eggplant_seeds",
					eggplant_source_id,
					eggplant_ready_coords,
					eggplant_alternative_tile
				)

			"corn_seeds_watered":
				_set_crop_ready(
					cell,
					"corn_seeds",
					corn_source_id,
					corn_ready_coords,
					corn_alternative_tile
				)

			"pineapple_crown_watered":
				_set_crop_ready(
					cell,
					"pineapple_crown",
					pineapple_source_id,
					pineapple_ready_coords,
					pineapple_alternative_tile
				)
			_:
				growth_timers.erase(cell)


func _set_crop_ready(
	cell: Vector2i,
	crop_id: String,
	source_id: int,
	atlas_coords: Vector2i,
	alternative_tile: int
) -> void:
	ground_layer.set_cell(
		cell,
		source_id,
		atlas_coords,
		alternative_tile
	)

	plot_states[cell] = crop_id + "_ready"
	growth_timers.erase(cell)

	print(crop_id, " is ready to harvest at ", cell)


func harvest_crop(cell: Vector2i, state: String) -> void:
	var product_id: String

	match state:
		"eggplant_seeds_ready":
			product_id = "eggplant"

		"corn_seeds_ready":
			product_id = "corn"

		"pineapple_crown_ready":
			product_id = "pineapple"

		_:
			print("This crop is not ready to harvest.")
			return

	# Add one harvested crop to the backpack.
	Global.add_item(product_id, 1)

	# Return the plot to tilled soil.
	ground_layer.set_cell(
		cell,
		tilled_source_id,
		tilled_atlas_coords,
		tilled_alternative_tile
	)

	plot_states[cell] = "tilled"
	growth_timers.erase(cell)

	print("Harvested ", product_id, " at ", cell)


func reset_plot_tracking() -> void:
	plot_states.clear()
	growth_timers.clear()
