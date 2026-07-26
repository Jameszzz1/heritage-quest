extends Node
var player: AudioStreamPlayer
var current_stream: String = ""

var button_sfx_player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	player.bus = "MUSIC"
	add_child(player)

	button_sfx_player = AudioStreamPlayer.new()
	button_sfx_player.bus = "SFX"
	button_sfx_player.stream = load("res://assets/audio/sfx/buttonuisfx.wav")
	add_child(button_sfx_player)

func play_music(stream_path: String):
	if current_stream == stream_path and player.playing:
		return
	current_stream = stream_path
	player.stream = load(stream_path)
	player.play()

func stop_music():
	player.stop()
	current_stream = ""

func play_button_sfx():
	button_sfx_player.stop()
	button_sfx_player.play()
