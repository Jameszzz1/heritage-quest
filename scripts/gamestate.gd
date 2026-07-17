extends Node

var tutorial_shown: bool = false

const SAVE_PATH = "user://gamestate.cfg"

func _ready():
	load_state()

func set_tutorial_shown():
	tutorial_shown = true
	save_state()

func save_state():
	var config = ConfigFile.new()
	config.set_value("flags", "tutorial_shown", tutorial_shown)
	config.save(SAVE_PATH)

func load_state():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		tutorial_shown = config.get_value("flags", "tutorial_shown", false)
