extends Area2D

# I-drag mo dito yung path ng Fishing Scene mo (yung Control node script mo)
var fishing_scene = preload("res://fishing.tscn") 

var can_interact = false

func _on_body_entered(body):
	if "Player" in body.name:
		can_interact = true
		print("Press Enter to start fishing in Sultan Kudarat!")

func _on_body_exited(body):
	if "Player" in body.name:
		can_interact = false

func _input(event):
	if can_interact and event.is_action_pressed("ui_accept"):
		# Dito natin ilo-load yung mini-game na pinakita mo
		var fish_ui = fishing_scene.instantiate()
		get_tree().root.add_child(fish_ui)
		print("Sultan Kudarat Fishing Mini-game Started!")
