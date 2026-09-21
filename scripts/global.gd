extends Node

signal inventory_changed

var current_health: float = -1
var current_stamina: float = -1
var current_energy: float = -1
var current_battery: float = -1
var spawn_position: Vector2 = Vector2.ZERO
var flashlight_on: bool = false
var return_scene: String = ""
var return_spawn_pos: Vector2 = Vector2.ZERO

# Inventory
var battery_items: int = 0

func _ready():
	_ensure_audio_buses()

func _ensure_audio_buses():
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

	if AudioServer.get_bus_index("MUSIC") == -1:
		AudioServer.add_bus()
		var idx2 = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx2, "MUSIC")
		AudioServer.set_bus_send(idx2, "Master")

func save_player_stats(player):
	current_health = player.health
	current_stamina = player.stamina
	current_energy = player.energy
	current_battery = player.battery
	flashlight_on = player.flashlight_on

func load_player_stats(player):
	if current_health != -1:
		player.health = current_health
	if current_stamina != -1:
		player.stamina = current_stamina
	if current_energy != -1:
		player.energy = current_energy
	if current_battery != -1:
		player.battery = current_battery
	player.flashlight_on = flashlight_on

# ---------------- INVENTORY ----------------

func add_battery(amount: int = 1):
	battery_items += amount
	inventory_changed.emit()

# True kung may nagamit na battery, False kung wala
func consume_battery() -> bool:
	if battery_items <= 0:
		return false
	battery_items -= 1
	inventory_changed.emit()
	return true
