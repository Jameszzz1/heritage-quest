extends CharacterBody2D

var can_talk = false
var current_phase = 0 # 0: Lore, 1-5: Questions

func _ready():
	$Area2D.body_entered.connect(_on_area_2d_body_entered)
	$Area2D.body_exited.connect(_on_area_2d_body_exited)

func _input(event):
	if can_talk and event.is_action_pressed("ui_accept"):
		start_interaction()

func _on_area_2d_body_entered(body):
	if "Player" in body.name:
		can_talk = true
		print("Press Enter to speak with Ustadz Ameer.")

func _on_area_2d_body_exited(body):
	if "Player" in body.name:
		can_talk = false
		current_phase = 0 

func start_interaction():
	if current_phase == 0:
		show_lore()
	elif current_phase <= 5:
		ask_question(current_phase)

func show_lore():
	print("--- PHASE 1: SULTAN KUDARAT LORE ---")
	print("Ustadz Ameer: Assalamu Alaikum, James. Welcome to the majestic Grand Mosque.")
	print("Ustadz Ameer: This is the Sultan Haji Hassanal Bolkiah Mosque, the largest in the country.")
	print("Ustadz Ameer: Its golden domes represent the rich heritage and faith of our people.")
	print("Ustadz Ameer: Our province is named after Sultan Muhammad Dipatuan Kudarat, a symbol of bravery.")
	print("Ustadz Ameer: Be careful as you travel; the terrain here is prone to Landslides during heavy rains.")
	print("Ustadz Ameer: [Lore entry complete. Press Enter to start the Quiz!]")
	current_phase = 1

func ask_question(num):
	print("--- PHASE 2: PROVINCIAL QUIZ (" + str(num) + "/5) ---")
	if num == 1:
		print("Ustadz Ameer: What is the formal name of this Grand Mosque, the largest in the Philippines?")
		print("A) Masjid Dimaukom | B) Sultan Haji Hassanal Bolkiah Mosque | C) Golden Mosque")
	elif num == 2:
		print("Ustadz Ameer: Our province is named after a hero who stood firm against foreign invaders. Who is he?")
		print("A) Sultan Muhammad Dipatuan Kudarat | B) Datu Kalantiao | C) Lapu-Lapu")
	elif num == 3:
		print("Ustadz Ameer: What distinctive feature of the Grand Mosque shines as a landmark of Sultan Kudarat?")
		print("A) The Pink Walls | B) The Golden Domes | C) The Bamboo Pillars")
	elif num == 4:
		print("Ustadz Ameer: According to your survival logic, what disaster should you prepare for in this province?")
		print("A) Tsunami | B) Landslide | C) Volcanic Eruption")
	elif num == 5:
		print("Ustadz Ameer: Why is Sultan Kudarat a vital part of the SOCCSKSARGEN Knowledge Vault?")
		print("A) For its industrial factories | B) For its preserved history of undefeated leadership | C) For its desert landscapes")
	
	current_phase += 1
	if current_phase > 5:
		print("Ustadz Ameer: You have proven your wisdom, Archivist. Go forth and secure the rest of the region!")
		current_phase = 0
