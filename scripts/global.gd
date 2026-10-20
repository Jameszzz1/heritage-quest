extends Node

signal inventory_changed
signal journal_updated(province: String)
signal token_claimed(province: String)

const SAVE_PATH = "user://heritage_progress.save"
const DEFAULT_PLAYER_NAME := "James"

# Pangalan ng player (galing sa Create Account)
var player_name: String = DEFAULT_PLAYER_NAME:
	set(value):
		print("DEBUG PLAYER NAME: ", player_name, " -> ", value)
		print_stack()
		player_name = value

var current_health: float = -1
var current_stamina: float = -1
var current_energy: float = -1
var current_battery: float = -1
var spawn_position: Vector2 = Vector2.ZERO
var flashlight_on: bool = false
var return_scene: String = ""
var return_spawn_pos: Vector2 = Vector2.ZERO

var current_location: String = ""

# Inventory
var battery_items: int = 0
var fish_items: int = 0

# Journal & NPC Progress System
var province_journals: Dictionary = {}
var completed_npcs: Dictionary = {}

# NPC na natapos nang basahin ang "Pag-aralan ang Kultura"
var culture_read_npcs: Dictionary = {}

# NPC quiz cooldown (kailan muling pwede mag-attempt, Unix time)
var npc_quiz_cooldowns: Dictionary = {}

# Mini game at Token
var current_minigame_npc: String = ""
var minigame_passed: Dictionary = {}
var tokens_claimed: Dictionary = {}
var pending_token_toast: String = ""

# Mga pickup na nakuha na (para hindi mag-respawn)
var collected_items: Dictionary = {}

# Huling save na scene at pwesto ni James
var saved_scene: String = ""
var saved_position: Vector2 = Vector2.ZERO

# Cloud
var cloud_user_id: String = ""

func _ready():
	_ensure_audio_buses()
	load_progress()

func _ensure_audio_buses():
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

	if AudioServer.get_bus_index("MUSIC") == -1:
		AudioServer.add_bus()
		var idx2 = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx2, "MUSIC")
		AudioServer.set_bus_send(idx2, "Master")

# ---------------- PLAYER NAME ----------------

func get_player_name() -> String:
	var n = player_name.strip_edges()
	return n if n != "" else DEFAULT_PLAYER_NAME

# Pinapalitan ang "James" sa text ng pangalan ng player
func apply_player_name(text: String) -> String:
	return text.replace("James", get_player_name())

func save_player_stats(player):
	current_health = player.health
	current_stamina = player.stamina
	current_energy = player.energy
	current_battery = player.battery
	flashlight_on = player.flashlight_on

func load_player_stats(player):
	if current_health != -1:
		player.health = current_health
	if current_stamina != -1:
		player.stamina = current_stamina
	if current_energy != -1:
		player.energy = current_energy
	if current_battery != -1:
		player.battery = current_battery
	player.flashlight_on = flashlight_on

# ---------------- COLLECTED ITEMS ----------------

# item_id ay dapat unique, halimbawa: scene_path + ":" + node_name
func mark_item_collected(item_id: String) -> void:
	collected_items[item_id] = true
	save_progress()

func is_item_collected(item_id: String) -> bool:
	return collected_items.get(item_id, false)

# ---------------- SAVE / LOAD ----------------

# Kinukuha ang scene, pwesto, at stats ni James (kung nasa game scene siya)
func capture_player_position() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var scene = get_tree().current_scene
	if player == null or scene == null:
		return
	if scene.scene_file_path == "":
		return
	saved_scene = scene.scene_file_path
	saved_position = player.global_position
	save_player_stats(player)

func has_saved_game() -> bool:
	return saved_scene != ""

# Data na isi-save (local file at Supabase)
func get_save_data() -> Dictionary:
	return {
		"player_name": player_name,
		"province_journals": province_journals,
		"completed_npcs": completed_npcs,
		"culture_read_npcs": culture_read_npcs,
		"minigame_passed": minigame_passed,
		"tokens_claimed": tokens_claimed,
		"collected_items": collected_items,
		"battery_items": battery_items,
		"fish_items": fish_items,
		"saved_scene": saved_scene,
		"saved_position": {"x": saved_position.x, "y": saved_position.y},
		"stats": {
			"health": current_health,
			"stamina": current_stamina,
			"energy": current_energy,
			"battery": current_battery,
			"flashlight_on": flashlight_on
		}
	}

# Ipinapasok ang data (galing local file o Supabase) sa Global
func _set_data(d: Dictionary) -> void:
	player_name = str(d.get("player_name", DEFAULT_PLAYER_NAME))
	province_journals = d.get("province_journals", {})
	completed_npcs = d.get("completed_npcs", {})
	culture_read_npcs = d.get("culture_read_npcs", {})
	minigame_passed = d.get("minigame_passed", {})
	tokens_claimed = d.get("tokens_claimed", {})
	collected_items = d.get("collected_items", {})
	battery_items = int(d.get("battery_items", 0))
	fish_items = int(d.get("fish_items", 0))
	saved_scene = str(d.get("saved_scene", ""))
	var p = d.get("saved_position", {})
	if p is Dictionary and p.has("x") and p.has("y"):
		saved_position = Vector2(float(p["x"]), float(p["y"]))
	else:
		saved_position = Vector2.ZERO
	var s = d.get("stats", {})
	if s is Dictionary and not s.is_empty():
		current_health = float(s.get("health", -1))
		current_stamina = float(s.get("stamina", -1))
		current_energy = float(s.get("energy", -1))
		current_battery = float(s.get("battery", -1))
		flashlight_on = bool(s.get("flashlight_on", false))
	else:
		current_health = -1
		current_stamina = -1
		current_energy = -1
		current_battery = -1
		flashlight_on = false

# Tawagin ito pagkatapos mag-download ng save mula sa Supabase
func apply_save_data(d: Dictionary) -> void:
	_set_data(d)
	save_progress()
	inventory_changed.emit()
	journal_updated.emit("")
	for p in tokens_claimed.keys():
		token_claimed.emit(p)

func save_progress() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(get_save_data())

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = f.get_var()
	if typeof(d) != TYPE_DICTIONARY:
		return
	_set_data(d)

# Para sa "New Game" button o pag-test: binubura ang lahat ng progress
func reset_progress() -> void:
	province_journals = {}
	completed_npcs = {}
	culture_read_npcs = {}
	npc_quiz_cooldowns = {}
	minigame_passed = {}
	tokens_claimed = {}
	collected_items = {}
	pending_token_toast = ""
	current_minigame_npc = ""
	battery_items = 0
	fish_items = 0
	saved_scene = ""
	saved_position = Vector2.ZERO
	current_health = -1
	current_stamina = -1
	current_energy = -1
	current_battery = -1
	flashlight_on = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	inventory_changed.emit()
	journal_updated.emit("")

# ---------------- INVENTORY ----------------

func add_battery(amount: int = 1):
	battery_items += amount
	inventory_changed.emit()
	save_progress()

func consume_battery() -> bool:
	if battery_items <= 0:
		return false
	battery_items -= 1
	inventory_changed.emit()
	save_progress()
	return true

func add_fish(amount: int = 1):
	fish_items += amount
	inventory_changed.emit()
	save_progress()

func consume_fish() -> bool:
	if fish_items <= 0:
		return false
	fish_items -= 1
	inventory_changed.emit()
	save_progress()
	return true

# ---------------- JOURNAL ----------------

func add_journal_entry(province: String, entry_title: String, entry_content: String) -> void:
	if not province_journals.has(province):
		province_journals[province] = []

	var data = { "title": entry_title, "content": entry_content }
	if not data in province_journals[province]:
		province_journals[province].append(data)
		journal_updated.emit(province)
		save_progress()

func get_journal_entries(province: String) -> Array:
	if province_journals.has(province):
		return province_journals[province]
	return []

func mark_npc_completed(npc_name: String) -> void:
	completed_npcs[npc_name] = true
	save_progress()

func is_npc_completed(npc_name: String) -> bool:
	return completed_npcs.get(npc_name, false)

# ---------------- CULTURE READ (Pag-aralan ang Kultura) ----------------

func mark_culture_read(npc_name: String) -> void:
	culture_read_npcs[npc_name] = true
	save_progress()

func is_culture_read(npc_name: String) -> bool:
	return culture_read_npcs.get(npc_name, false)

# ---------------- MINI GAME AT TOKEN ----------------

func mark_minigame_passed(npc_name: String) -> void:
	if npc_name != "":
		minigame_passed[npc_name] = true
		save_progress()

func is_minigame_passed(npc_name: String) -> bool:
	return minigame_passed.get(npc_name, false)

func claim_token(province: String) -> void:
	tokens_claimed[province] = true
	token_claimed.emit(province)
	save_progress()

func has_token(province: String) -> bool:
	return tokens_claimed.get(province, false)

# ---------------- NPC QUIZ COOLDOWN ----------------

func set_quiz_cooldown(npc_name: String, seconds: float = 120.0) -> void:
	npc_quiz_cooldowns[npc_name] = Time.get_unix_time_from_system() + seconds

func get_quiz_cooldown_remaining(npc_name: String) -> float:
	if not npc_quiz_cooldowns.has(npc_name):
		return 0.0
	var remaining = npc_quiz_cooldowns[npc_name] - Time.get_unix_time_from_system()
	return max(0.0, remaining)

# ---------------- CLOUD SAVE (SUPABASE) ----------------

# Tinatawag pagka-verify ng OTP. Kinukuha ang user id mula sa auth result.
func set_cloud_user_from_auth(auth_data) -> void:
	cloud_user_id = ""
	if auth_data == null:
		return
	if auth_data is Dictionary and auth_data.has("user"):
		var u = auth_data["user"]
		if u is Dictionary and u.has("id"):
			cloud_user_id = str(u["id"])
			return
	if auth_data is Dictionary and auth_data.has("access_token"):
		var parts = str(auth_data["access_token"]).split(".")
		if parts.size() >= 2:
			var payload = parts[1].replace("-", "+").replace("_", "/")
			while payload.length() % 4 != 0:
				payload += "="
			var json_text = Marshalls.base64_to_utf8(payload)
			var parsed = JSON.parse_string(json_text)
			if parsed is Dictionary and parsed.has("sub"):
				cloud_user_id = str(parsed["sub"])

func _cloud_user_id() -> String:
	return cloud_user_id

# Kinukuha ang save mula sa Supabase. Returns true kung may nakuha.
func download_cloud_save() -> bool:
	var uid = _cloud_user_id()
	if uid == "":
		push_warning("Cloud save: walang user id")
		return false
	var q = SupabaseQuery.new().from("game_saves").select(["data"]).eq("user_id", uid)
	var res = await Supabase.database.query(q).completed
	if res.error != null:
		push_warning("Cloud load error: " + str(res.error))
		return false
	if res.data is Array and res.data.size() > 0:
		var d = res.data[0].get("data", {})
		if d is Dictionary and not d.is_empty():
			apply_save_data(d)
			return true
	return false

# Ina-upload ang kasalukuyang progress. Returns true kung nagtagumpay.
func upload_cloud_save() -> bool:
	var uid = _cloud_user_id()
	if uid == "":
		push_warning("Cloud save: walang user id")
		return false
	capture_player_position()   # scene, pwesto, at stats ni James
	save_progress()
	var data = get_save_data()

	var check = await Supabase.database.query(
		SupabaseQuery.new().from("game_saves").select(["user_id"]).eq("user_id", uid)
	).completed
	if check.error != null:
		push_warning("Cloud save error: " + str(check.error))
		return false

	var res
	if check.data is Array and check.data.size() > 0:
		res = await Supabase.database.query(
			SupabaseQuery.new().from("game_saves").update({"data": data}).eq("user_id", uid)
		).completed
	else:
		res = await Supabase.database.query(
			SupabaseQuery.new().from("game_saves").insert([{"user_id": uid, "data": data}])
		).completed

	if res.error != null:
		push_warning("Cloud save error: " + str(res.error))
		return false
	return true
