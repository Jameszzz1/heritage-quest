extends CanvasLayer
@onready var backpack_button = $Backpack
@onready var backpack_popup = $BackpackPopup
@onready var close_button = $BackpackPopup/Button
@onready var grid = $BackpackPopup/TabContainer/Inventory/GridContainer
@onready var minimap = $MiniMap
@onready var settings = $Settings
@onready var pause_label = $PauseLabel
var is_paused: bool = false

var death_screen: ColorRect
var death_countdown_label: Label

func _ready():
	backpack_popup.visible = false
	minimap.visible = false
	pause_label.visible = false
	add_to_group("hud")
	call_deferred("_find_player")
	backpack_button.pressed.connect(_on_backpack_pressed)
	close_button.pressed.connect(_on_close_pressed)
	setup_death_overlay()

func setup_death_overlay():
	death_screen = ColorRect.new()
	death_screen.color = Color(0, 0, 0, 0)
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.z_index = 4096
	add_child(death_screen)

	death_countdown_label = Label.new()
	death_countdown_label.add_theme_font_size_override("font_size", 40)
	death_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	var custom_font = load("res://assets/fonts/GrapeSoda.ttf")
	if custom_font:
		death_countdown_label.add_theme_font_override("font", custom_font)
	death_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_countdown_label.visible = false
	death_countdown_label.z_index = 4096
	add_child(death_countdown_label)

func _center_countdown_label():
	var viewport_size = get_viewport().get_visible_rect().size
	death_countdown_label.reset_size()
	var label_size = death_countdown_label.size
	death_countdown_label.position = (viewport_size - label_size) / 2.0

func show_death_sequence() -> void:
	var tween = create_tween()
	tween.tween_property(death_screen, "color", Color(0, 0, 0, 0.6), 1.0)
	await tween.finished

	death_countdown_label.visible = true
	var seconds_left = 10
	while seconds_left > 0:
		death_countdown_label.text = "Respawning in " + str(seconds_left) + ""
		_center_countdown_label()
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1

	death_countdown_label.visible = false
	death_screen.color = Color(0, 0, 0, 0)

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
