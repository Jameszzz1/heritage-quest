extends Sprite2D

@export var sound: AudioStream = preload("res://assets/audio/sfx/sultankudarat_falls.mp3")
@export var max_distance: float = 450.0        # lampas dito, wala nang maririnig (world pixels)
@export var attenuation_strength: float = 1.6  # taas = mabilis humina paglayo, baba = unti-unti
@export var volume: float = -4.0               # dB, mas baba = mas mahina
@export var sound_offset: Vector2 = Vector2(0, 110) # saan nanggagaling ang tunog, nasa pool/falls base
@export var audio_bus: StringName = &"Master"

func _ready() -> void:
	var stream: AudioStream = sound.duplicate()
	if stream is AudioStreamMP3:
		stream.loop = true # tuloy-tuloy ang tunog

	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.position = sound_offset
	player.max_distance = max_distance
	player.attenuation = attenuation_strength
	player.volume_db = volume
	player.panning_strength = 1.0
	player.bus = audio_bus
	add_child(player)
	player.play()
