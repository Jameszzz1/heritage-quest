extends Area2D

@export var target_scene: String = ""
@export var spawn_pos: Vector2

@export var return_scene: String = ""
@export var return_spawn_pos: Vector2

@export var show_on_minimap: bool = false

# Token na kailangan bago makapasok. "none" = bukas palagi.
@export_enum("none", "south_cotabato", "sarangani", "sultan_kudarat", "cotabato_province") var required_token: String = "none"

const PROVINCE_NAMES = {
	"south_cotabato": "South Cotabato",
	"sarangani": "Sarangani",
	"sultan_kudarat": "Sultan Kudarat",
	"cotabato_province": "Cotabato"
}

var _busy := false


func _ready():
	if show_on_minimap:
		add_to_group("minimap_location")


func _on_body_entered(body):
	if _busy or body.name != "James":
		return

	# Sarado kung kulang ang token
	if required_token != "none" and not Global.has_token(required_token):
		_show_toast("Sarado pa ang daan. Kailangan mo ang Token ng " + PROVINCE_NAMES.get(required_token, required_token) + "!")
		_push_back(body)
		return

	_busy = true
	Global.spawn_position = spawn_pos
	Global.return_scene = return_scene
	Global.return_spawn_pos = return_spawn_pos

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
