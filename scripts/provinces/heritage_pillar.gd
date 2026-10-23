extends Sprite2D
# Heritage Pillar sa homebase: walang token sa simula, kumpleto pagkatapos ng Descent.

const TEXTURE_EMPTY := "res://assets/sprites/things/heritage_pillar_notoken.png"
const TEXTURE_FULL := "res://assets/sprites/things/heritage_pillar_withtoken.png"

func _ready() -> void:
	Global.heritage_completed.connect(_update_pillar)
	_update_pillar()

func _update_pillar() -> void:
	var path: String = TEXTURE_FULL if Global.heritage_complete else TEXTURE_EMPTY
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		push_warning("Heritage Pillar: hindi makita ang " + path)
