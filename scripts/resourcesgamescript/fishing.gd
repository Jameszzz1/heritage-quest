extends Control

# --- 1. NODE REFERENCES ---
@onready var tube = $Tube
@onready var green_bar = $Tube/Greenbar
@onready var fish = $Tube/OrangeFish
@onready var progress_bar = $Tube/ProgressBar
@onready var caught_label = $"Caught!"
@onready var particle_burst = $ParticleBurst
@onready var fish_counter_label = $FishCounter
@onready var timer_label = $TimerLabel

# Audio Nodes
@onready var water_splash = $WaterSplash
@onready var fishing_reel = $FishingReel
@onready var success_sfx = $Success

# --- 2. VARIABLES ---
var gravity = 0.20
var velocity = 0.0
var lift_force = -5.0
var max_velocity = 7.0

var fish_target_y = 0.0
var fish_timer = 0.0
var catch_progress = 0.0
var is_active = false

var fish_count = 0
var time_left = 30.0

const TUBE_WIDTH = 25
const TUBE_HEIGHT = 150
const BAR_WIDTH = 25
const BAR_HEIGHT = 40

func _ready():
	caught_label.visible = false
	particle_burst.emitting = false
	progress_bar.value = 0
	caught_label.pivot_offset = Vector2(148.5, 25.5)

	tube.custom_minimum_size = Vector2(TUBE_WIDTH, TUBE_HEIGHT)
	tube.size = Vector2(TUBE_WIDTH, TUBE_HEIGHT)
	green_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	green_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	green_bar.position.y = (tube.size.y / 2.0) - (green_bar.size.y / 2.0)
	fish.position.y = (tube.size.y / 2.0) - 16
	fish_target_y = fish.position.y

	timer_label.text = "Time: 30s"
	update_counter_text()

	if Supabase.auth == null or Supabase.auth._session == null:
		print("⚠️ SYSTEM: Naka-OFF ang Cloud Save (Walang Login Session).")

func _input(event):
	if event.is_action_pressed("ui_accept") and not is_active:
		start_fishing()

func start_fishing():
	is_active = true
	catch_progress = 0
	progress_bar.value = 0
	green_bar.position.y = (tube.size.y / 2.0) - (green_bar.size.y / 2.0)
	if water_splash:
		water_splash.play()
	caught_label.visible = false

func _process(delta):
	if not is_active:
		return

	# Timer countdown
	time_left -= delta
	timer_label.text = "Time: " + str(int(time_left)) + "s"
	if time_left <= 0:
		time_left = 30.0
		catch_progress = 0
		progress_bar.value = 0
		fish.position.y = (tube.size.y / 2.0) - 16
		fish_target_y = fish.position.y
		green_bar.position.y = (tube.size.y / 2.0) - (green_bar.size.y / 2.0)
		velocity = 0

	# Green bar control
	if Input.is_action_pressed("ui_accept"):
		velocity += lift_force
	else:
		velocity += gravity

	velocity = clamp(velocity, -max_velocity, max_velocity)
	green_bar.position.y += velocity

	# Clamp green bar inside tube
	var max_y = tube.size.y - green_bar.size.y
	green_bar.position.y = clamp(green_bar.position.y, 0, max_y)
	if green_bar.position.y <= 0 or green_bar.position.y >= max_y:
		velocity = 0

	# Fish movement
	fish_timer -= delta
	if fish_timer <= 0:
		fish_target_y = randf_range(0, tube.size.y - 32)
		fish_timer = randf_range(0.5, 1.5)
	fish.position.y = lerp(fish.position.y, fish_target_y, 0.05)
	fish.position.y = clamp(fish.position.y, 0, tube.size.y - 32)

	# Progress logic
	var fish_center = fish.position.y + 16
	var bar_top = green_bar.position.y
	var bar_bottom = green_bar.position.y + green_bar.size.y

	if fish_center > bar_top and fish_center < bar_bottom:
		catch_progress += 40 * delta
		if fishing_reel and not fishing_reel.playing:
			fishing_reel.play(2.27)
	else:
		catch_progress -= 20 * delta
		if fishing_reel and fishing_reel.playing:
			fishing_reel.stop()

	catch_progress = clamp(catch_progress, 0, 100)
	progress_bar.value = catch_progress

	if catch_progress >= 100:
		win_game()

# --- 3. WIN AND CLOUD SAVE LOGIC ---

func win_game():
	is_active = false
	fish_count += 1
	update_counter_text()
	save_fish_to_supabase("Fish")

	if fishing_reel:
		fishing_reel.stop()
	if success_sfx:
		success_sfx.play()

	caught_label.visible = true
	caught_label.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(caught_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	particle_burst.emitting = true

	await get_tree().create_timer(3.0).timeout
	caught_label.visible = false
	progress_bar.value = 0
	is_active = true

func save_fish_to_supabase(fish_type: String):
	if Supabase.auth == null: return
	if Supabase.auth._session == null: return
	if not Supabase.auth._session.has("user"): return

	var user_id = Supabase.auth._session["user"]["id"]

	var query = SupabaseQuery.new().from("user_progress").select(["inventory"]).eq("user_id", user_id)
	var task = Supabase.database.query(query)
	var result = await task.completed

	var current_inv = {}
	var final_data = []

	if result is Array: final_data = result
	elif result is Dictionary and result.has("data"): final_data = result["data"]

	if final_data.size() > 0:
		current_inv = final_data[0].get("inventory", {})

	if current_inv.has(fish_type):
		current_inv[fish_type] += 1
	else:
		current_inv[fish_type] = 1

	var update_query = SupabaseQuery.new().from("user_progress").update({"inventory": current_inv}).eq("user_id", user_id)
	var update_task = Supabase.database.query(update_query)
	await update_task.completed	

	print("✅ Cloud Updated! Inventory: ", current_inv)

func update_counter_text():
	if fish_counter_label:
		fish_counter_label.text = "Fishes Caught: " + str(fish_count)

func _on_button_pressed() -> void:
	Global.spawn_position = Vector2(-276.0, 36.0)
	get_tree().change_scene_to_file("res://scenes/provinces/south_cotabato/south_cotabato.tscn")
