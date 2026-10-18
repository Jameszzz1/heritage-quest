extends Area2D
# Gate papunta sa susunod na province. Sarado hangga't wala ang kinakailangang token.
#
# Sa Inspector, itakda ang:
#   required_token = token na kailangan ("none" kung bukas palagi)
#   target_scene   = scene na pupuntahan
#   target_spawn   = pwesto ni James sa bagong scene

@export_enum("none", "south_cotabato", "sarangani", "sultan_kudarat", "cotabato_province") var required_token: String = "none"
@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn: Vector2 = Vector2.ZERO
@export var locked_message: String = "Sarado pa ang daan. Kailangan mo ang Token ng "

const PROVINCE_NAMES = {
	"south_cotabato": "South Cotabato",
	"sarangani": "Sarangani",
	"sultan_kudarat": "Sultan Kudarat",
	"cotabato_province": "Cotabato"
}

var _busy := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if _busy or body.name != "James":
		return

	if required_token != "none" and required_token != "" and not Global.has_token(required_token):
		_show_toast(locked_message + PROVINCE_NAMES.get(required_token, required_token) + "!")
		_push_back(body)
		return

	if target_scene == "":
		return

	_busy = true
	Global.spawn_position = target_spawn
	LoadingScreen.change_scene(target_scene)

func _push_back(body):
	# Itinutulak pabalik si James para hindi paulit-ulit ang toast
	var dir = (body.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	body.global_position += dir * 12.0

func _show_toast(msg: String):
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_toast"):
		hud._show_toast(msg)
