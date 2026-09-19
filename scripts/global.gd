extends Node
var current_health: float = -1
var current_stamina: float = -1
var current_energy: float = -1
var spawn_position: Vector2 = Vector2.ZERO
var has_torch: bool = false
var return_scene: String = ""
var return_spawn_pos: Vector2 = Vector2.ZERO

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
	has_torch = player.has_torch

func load_player_stats(player):
	if current_health != -1:
		player.health = current_health
	if current_stamina != -1:
		player.stamina = current_stamina
	if current_energy != -1:
		player.energy = current_energy
	player.has_torch = has_torch
