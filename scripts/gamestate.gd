extends Node

var tutorial_shown: bool = false

const SAVE_PATH = "user://gamestate.cfg"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # gumagana kahit naka-pause
	load_state()

func _input(event):
	# Ctrl + Shift + R = reset tutorial (pang-demo). Tapos i-restart ang game.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and event.ctrl_pressed and event.shift_pressed:
			reset_state()
			print("[Gamestate] Tutorial reset. I-restart ang game.")

func set_tutorial_shown():
	tutorial_shown = true
	save_state()

func reset_state():
	tutorial_shown = false
	save_state()

func save_state():
	var config = ConfigFile.new()
	config.set_value("flags", "tutorial_shown", tutorial_shown)
	config.save(SAVE_PATH)

func load_state():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		tutorial_shown = config.get_value("flags", "tutorial_shown", false)
