extends CanvasLayer

@onready var backpack_button = $Backpack
@onready var backpack_popup = $BackpackPopup
@onready var close_button = $BackpackPopup/Button
@onready var journal = $BackpackPopup/TabContainer/Journal
@onready var grid = $BackpackPopup/TabContainer/Inventory/GridContainer
@onready var minimap = $MiniMap
@onready var settings = $Settings
@onready var pause_label = $PauseLabel

var is_paused: bool = false

func _ready():
	backpack_popup.visible = false
	minimap.visible = false
	pause_label.visible = false
	backpack_button.pressed.connect(_on_backpack_pressed)
	close_button.pressed.connect(_on_close_pressed)
	call_deferred("_find_player")

func _find_player():
	var james = get_tree().get_first_node_in_group("player")
	if james:
		minimap.player = james
		james.energy_bar = get_tree().get_first_node_in_group("energy_bar")
	else:
		print("James not found in group!")

func _unhandled_input(event):
	if event.is_action_pressed("toggle_map"):
		minimap.visible = !minimap.visible
	if event.is_action_pressed("pause_game"):
		is_paused = !is_paused
		get_tree().paused = is_paused
		pause_label.visible = is_paused

func _on_settings_pressed():
	settings.toggle()

func _on_backpack_pressed():
	backpack_popup.visible = !backpack_popup.visible

func _on_close_pressed():
	backpack_popup.visible = false

func add_journal_entry(npc_name: String, dialogue: String):
	journal.text += "\n[b]" + npc_name + "[/b]\n" + dialogue + "\n"
