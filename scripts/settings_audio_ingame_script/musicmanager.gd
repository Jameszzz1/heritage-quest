extends Node

var player: AudioStreamPlayer
var current_stream: String = ""

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)

func play_music(stream_path: String):
	if current_stream == stream_path and player.playing:
		return
	current_stream = stream_path
	player.stream = load(stream_path)
	player.bus = "Master"  # <- i-set sa Master bus
	player.play()

func stop_music():
	player.stop()
	current_stream = ""
