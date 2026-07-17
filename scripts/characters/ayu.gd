extends CharacterBody2D

var can_talk = false
var current_phase = 0 # 0: Lore, 1-5: Questions

func _ready():
	# Siguraduhin na ang Area2D ay child ng Ayu node mo
	$Area2D.body_entered.connect(_on_area_2d_body_entered)
	$Area2D.body_exited.connect(_on_area_2d_body_exited)

func _input(event):
	if can_talk and event.is_action_pressed("ui_accept"):
		start_interaction()

func _on_area_2d_body_entered(body):
	if "Player" in body.name: # Dapat "Player" ang pangalan ng node ni James
		can_talk = true
		print("Pindutin ang Enter para kausapin ang Keeper of Ayub Cave.")

func _on_area_2d_body_exited(body):
	if "Player" in body.name:
		can_talk = false
		current_phase = 0 # Reset pag lumayo si James

func start_interaction():
	if current_phase == 0:
		show_lore()
	elif current_phase <= 5:
		ask_question(current_phase)

func show_lore():
	print("--- PHASE 1: DEEP LORE ---")
	print("Ayu: Step carefully, James. You are standing where the ancient ones once rested...")
	print("Ayu: Back in 1991, in Ayub Cave, the Maitum Anthropomorphic Jars were found.")
	print("Ayu: They are from the Metal Age and serve as secondary burial jars.")
	print("Ayu: [Tapos na ang kwento. Pindutin ulit ang Enter para sa Quiz!]")
	current_phase = 1

func ask_question(num):
	print("--- PHASE 2: QUESTION " + str(num) + " ---")
	if num == 1:
		print("Ayu: In which cave were these ancient human-faced jars first discovered?")
		print("A) The Hills of Alabel | B) Ayub Cave in Maitum | C) The Gumasa Coastline")
	elif num == 2: 
		print("Ayu: When I say these jars are 'Anthropomorphic,' what does that mean?")
		print("A) Volcanic stones | B) Human-like features | C) Water storage")
	elif num == 3:
		print("Ayu: To which historical period do they belong?")
		print("A) Spanish Colonial | B) Metal Age | C) Neolithic Age")
	elif num == 4:
		print("Ayu: What was the sacred purpose of these jars?")
		print("A) Secondary burial jars | B) Food containers | C) Boundary markers")
	elif num == 5:
		print("Ayu: What is the focus of your survival mission in this area?")
		print("A) Desert survival | B) Coastal heritage and preservation | C) Mountain safety")
	
	current_phase += 1
	if current_phase > 5:
		print("Ayu: Maraming salamat, James. Alam mo na ang kasaysayan ng Sarangani!")
		current_phase = 0 # Reset para pwede ulit kausapin
