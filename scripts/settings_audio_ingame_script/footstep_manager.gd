extends Node

var grass_sound = preload("res://assets/audio/sfx/grass_footsteps.wav")
var dirt_sound = preload("res://assets/audio/sfx/dirt_footsteps.wav")
var wood_sound = preload("res://assets/audio/sfx/wood_footsteps.wav")

var audio_player = AudioStreamPlayer.new()
var footstep_timer = 0.0
var footstep_interval = 0.4

# Gawing true para makita sa Output kung anong surface ang nababasa
var debug_footstep: bool = false


func _ready():
	# Kung walang "SFX" bus, Master ang gagamitin para may tunog pa rin
	if AudioServer.get_bus_index("SFX") != -1:
		audio_player.bus = "SFX"
	else:
		audio_player.bus = "Master"
		push_warning("FootstepManager: walang 'SFX' bus, Master ang ginamit.")
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

		# Kapag blangko o hindi kilala ang surface, dirt ang default
		if surface != "grass" and surface != "dirt" and surface != "wood":
			surface = "dirt"

		if debug_footstep:
			print("surface detected: ", surface)

		if surface == "grass":
			audio_player.stream = grass_sound
		elif surface == "dirt":
			audio_player.stream = dirt_sound
		elif surface == "wood":
			audio_player.stream = wood_sound

		audio_player.play()
