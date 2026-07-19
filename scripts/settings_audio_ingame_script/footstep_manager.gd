extends Node

var grass_sound = preload("res://assets/audio/sfx/grass_footsteps.wav")
var dirt_sound = preload("res://assets/audio/sfx/dirt_footsteps.wav")

var audio_player = AudioStreamPlayer.new()
var footstep_timer = 0.0
var footstep_interval = 0.4

func _ready():
	add_child(audio_player)

func play_footstep(surface: String, delta: float, is_moving: bool, is_sprinting: bool):
	if not is_moving:
		footstep_timer = 0.0
		return
	if is_sprinting:
		footstep_interval = 0.25
	else:
		footstep_interval = 0.4
	footstep_timer += delta
	if footstep_timer >= footstep_interval:
		footstep_timer = 0.0
		if surface == "grass":
			audio_player.stream = grass_sound
			audio_player.play()
		elif surface == "dirt":
			audio_player.stream = dirt_sound
			audio_player.play()
