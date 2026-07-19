extends Area2D

# 1. SIGURADUHIN: I-right click ang fishing scene file (.tscn) sa FileSystem,
# piliin ang "Copy Path", at i-paste sa loob ng quotes sa ibaba.
var fishing_scene = preload("res://fishing.tscn") 

var can_interact = false

# 2. SIGNAL: Siguraduhin na naka-connect ito sa Area2D node
func _on_body_entered(body: Node2D) -> void:
	if "Player" in body.name:
		can_interact = true
		# Localized message para sa Sarangani
		print("You are near Sarangani Bay. Press Enter to start fishing for Tuna!")

# 3. SIGNAL: Siguraduhin na naka-connect din ito
func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		can_interact = false
		print("Leaving the Sarangani fishing zone.")

func _input(event: InputEvent) -> void:
	if can_interact and event.is_action_pressed("ui_accept"):
		# I-check kung wala pang nakabukas na UI para hindi mag-duplicate
		if not get_tree().root.has_node("FishingUI"): 
			var fish_ui = fishing_scene.instantiate()
			fish_ui.name = "FishingUI"
			get_tree().root.add_child(fish_ui)
			print("Sarangani Fishing Mini-game Started!")
