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

# Cell coordinates -> Unix time (seconds) when the crop becomes ready.
# Uses real time, so crops keep growing while you are in another scene.
var growth_ready_at: Dictionary = {}

# The scene this farm belongs to (used as the key in Global.farm_plots).
var _scene_key: String = ""


func _ready() -> void:
	if ground_layer == null:
		push_warning("FarmManager: Assign Ground Layer in the Inspector.")
		return

	var scene := get_tree().current_scene
	if scene:
		_scene_key = scene.scene_file_path

	_restore_plots()


func _process(_delta: float) -> void:
	_update_crop_growth()

	if Input.is_action_just_pressed("interact"):
		_handle_interaction()


# ---------------------------------------------------------------- PERSISTENCE

# Saves every plot of this scene into Global (which also writes the save file).
func _save_plots() -> void:
	if _scene_key == "":
		return

	var data: Dictionary = {}
	for cell in plot_states.keys():
		var c: Vector2i = cell
		data["%d,%d" % [c.x, c.y]] = {
			"state": str(plot_states[cell]),
			"ready_at": float(growth_ready_at.get(cell, 0.0))
		}

	Global.set_farm_scene(_scene_key, data)


# Rebuilds the tiles from Global when the scene is entered again.
func _restore_plots() -> void:
	if _scene_key == "":
		return

	var saved: Dictionary = Global.get_farm_scene(_scene_key)
	var now: float = Time.get_unix_time_from_system()

	for key in saved.keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			continue

		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var entry = saved[key]
		if not (entry is Dictionary):
			continue

		var state: String = str(entry.get("state", ""))
		var ready_at: float = float(entry.get("ready_at", 0.0))

		if state.ends_with("_watered"):
			if now >= ready_at:
				# It finished growing while the player was away.
				state = state.trim_suffix("_watered") + "_ready"
			else:
				growth_ready_at[cell] = ready_at

		plot_states[cell] = state
		_paint_cell(cell, state)

	print("FarmManager: restored ", plot_states.size(), " plots for ", _scene_key)


# ---------------------------------------------------------------- TILE HELPERS

func _tile_for_state(state: String) -> Dictionary:
	match state:
		"tilled":
			return {"source": tilled_source_id, "coords": tilled_atlas_coords, "alt": tilled_alternative_tile}

		"eggplant_seeds":
			return {"source": eggplant_source_id, "coords": eggplant_atlas_coords, "alt": eggplant_alternative_tile}
		"eggplant_seeds_watered":
			return {"source": eggplant_source_id, "coords": eggplant_watered_coords, "alt": eggplant_alternative_tile}
		"eggplant_seeds_ready":
			return {"source": eggplant_source_id, "coords": eggplant_ready_coords, "alt": eggplant_alternative_tile}

		"corn_seeds":
			return {"source": corn_source_id, "coords": corn_atlas_coords, "alt": corn_alternative_tile}
		"corn_seeds_watered":
			return {"source": corn_source_id, "coords": corn_watered_coords, "alt": corn_alternative_tile}
		"corn_seeds_ready":
			return {"source": corn_source_id, "coords": corn_ready_coords, "alt": corn_alternative_tile}

		"pineapple_crown":
			return {"source": pineapple_source_id, "coords": pineapple_atlas_coords, "alt": pineapple_alternative_tile}
		"pineapple_crown_watered":
			return {"source": pineapple_source_id, "coords": pineapple_watered_coords, "alt": pineapple_alternative_tile}
		"pineapple_crown_ready":
			return {"source": pineapple_source_id, "coords": pineapple_ready_coords, "alt": pineapple_alternative_tile}

	return {}


func _paint_cell(cell: Vector2i, state: String) -> void:
	var t := _tile_for_state(state)
	if t.is_empty():
		return
	ground_layer.set_cell(cell, t["source"], t["coords"], t["alt"])


# ---------------------------------------------------------------- INTERACTION

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

	_paint_cell(cell, "tilled")
	plot_states[cell] = "tilled"
	_save_plots()
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

	if _tile_for_state(seed_id).is_empty():
		print("That item cannot be planted.")
		return

	if not Global.remove_item(seed_id, 1):
		print("Could not consume the selected item.")
		return

	_paint_cell(cell, seed_id)
	plot_states[cell] = seed_id
	growth_ready_at.erase(cell)
	_save_plots()

	print("Planted ", seed_id, " at ", cell)


func water_crop(cell: Vector2i, crop_id: String) -> void:
	var watered_state := crop_id + "_watered"

	if _tile_for_state(watered_state).is_empty():
		print("This crop cannot be watered.")
		return

	_paint_cell(cell, watered_state)
	plot_states[cell] = watered_state
	growth_ready_at[cell] = Time.get_unix_time_from_system() + maxf(growth_time_seconds, 0.1)
	_save_plots()

	print("Watered ", crop_id, ". Growth started at ", cell)


func _update_crop_growth() -> void:
	if ground_layer == null or growth_ready_at.is_empty():
		return

	var now: float = Time.get_unix_time_from_system()
	var changed := false

	# keys() returns a copy, so it is safe to modify the dictionary inside.
	for cell in growth_ready_at.keys():
		if now < float(growth_ready_at[cell]):
			continue

		var state := str(plot_states.get(cell, ""))

		if state.ends_with("_watered"):
			_set_crop_ready(cell, state.trim_suffix("_watered"))
			changed = true
		else:
			growth_ready_at.erase(cell)

	if changed:
		_save_plots()


func _set_crop_ready(cell: Vector2i, crop_id: String) -> void:
	var ready_state := crop_id + "_ready"

	_paint_cell(cell, ready_state)
	plot_states[cell] = ready_state
	growth_ready_at.erase(cell)

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

	# Return the plot to tilled soil and save it first.
	_paint_cell(cell, "tilled")
	plot_states[cell] = "tilled"
	growth_ready_at.erase(cell)
	_save_plots()

	# Add one harvested crop to the backpack.
	Global.add_item(product_id, 1)

	print("Harvested ", product_id, " at ", cell)


func reset_plot_tracking() -> void:
	plot_states.clear()
	growth_ready_at.clear()
	if _scene_key != "":
		Global.set_farm_scene(_scene_key, {})
