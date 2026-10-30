extends Area2D
## Nagpapakita ng comic nang ISANG BESES lang. Pumili ng "Route" sa Inspector.

const COMIC_PATH := "res://scenes/ui/comic_maliksi.tscn"

# page = image ng comic
# lines = narration sa kanan. Gawing [] kung nakalagay na ang text sa mismong image
# (malaki at nasa gitna ang comic kapag walang lines).
const ROUTES := {
	"route1_fading": {
		"page": "res://assets/comics/route1_fading.png",
		"lines": [],
	},
	"route2_dark_road": {
		"page": "res://assets/comics/route2_dark_road.png",
		"lines": [],
	},
	"route3_highland": {
		"page": "res://assets/comics/route3_highland.png",
		"lines": [],
	},
}

@export_enum("route1_fading", "route2_dark_road", "route3_highland") var route: String = "route1_fading"
@export var pause_game: bool = true
# Para sa night scenes: lalabas ang comic pagpasok sa scene, kahit walang tinatapakan
@export var auto_play_on_ready: bool = false
@export var auto_play_delay: float = 0.8

var _playing := false


func _ready() -> void:
	if not ROUTES.has(route):
		push_warning("RouteComicTrigger: walang route na '%s'" % route)
		return
	# Nakita na dati: tanggalin ang trigger
	if Global.has_seen_story(route):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	if auto_play_on_ready:
		await get_tree().create_timer(auto_play_delay).timeout
		_play_comic()


func _on_body_entered(body: Node2D) -> void:
	if _playing:
		return
	if not (body.is_in_group("player") or body.name == "James"):
		return
	_play_comic()


func _play_comic() -> void:
	if _playing or Global.has_seen_story(route):
		return

	var data: Dictionary = ROUTES[route]
	var page_path: String = data["page"]
	if not ResourceLoader.exists(page_path) or not ResourceLoader.exists(COMIC_PATH):
		push_warning("RouteComicTrigger: kulang ang file: %s" % page_path)
		return

	_playing = true
	Global.mark_story_seen(route)

	var parts: Array = []
	for line in data["lines"]:
		parts.append(line)

	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(layer)

	var comic = load(COMIC_PATH).instantiate()
	comic.pages = [page_path]
	comic.narration = [parts]
	comic.speaker = ""                    # walang pangalan sa itaas ng narration
	comic.center_page = parts.is_empty()  # walang narration = malaki sa gitna
	comic.next_scene = ""                 # popup lang, hindi lilipat ng scene
	layer.add_child(comic)

	if pause_game:
		get_tree().paused = true
	await comic.finished
	if pause_game:
		get_tree().paused = false

	layer.queue_free()
	queue_free()
