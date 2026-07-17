extends Node

var current_health: float = -1
var current_stamina: float = -1
var current_energy: float = -1
var spawn_position: Vector2 = Vector2.ZERO
var has_torch: bool = false

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
