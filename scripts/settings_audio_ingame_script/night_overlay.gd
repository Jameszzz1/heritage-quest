extends CanvasModulate

@export var night_color: Color = Color(0, 0, 0, 1)

func _ready() -> void:
	color = night_color
