extends Node

signal inventory_changed
signal journal_updated(province: String)
signal token_claimed(province: String)
signal badge_unlocked(id: String)
signal heritage_completed   # HERITAGE

const SAVE_PATH = "user://heritage_progress.save"
const DEFAULT_PLAYER_NAME := "James"

# ---------------- BADGE SETTINGS ----------------
const BADGE_FONT_PATH := "res://assets/fonts/GrapeSoda.ttf"
const BADGE_SHOW_SECONDS := 3.0
const BADGE_POPUP_WIDTH := 150.0      # lapad ng description (palakihin kung masikip)
const BADGE_POPUP_TOP_MARGIN := 8.0
const BADGE_ICON_SIZE := Vector2(28, 30)
const BADGE_HEADER_FONT_SIZE := 6
const BADGE_TITLE_FONT_SIZE := 8
const BADGE_DESC_FONT_SIZE := 6

# SFX kapag may bagong badge (random ang pili, hindi uulit ang kapareho ng huli)
const BADGE_SFX_PATHS: Array = [
	"res://assets/audio/sfx/achievement-badge-pop-sound-1.mp3",
	"res://assets/audio/sfx/achievement-badge-pop-sound-2.mp3",
	"res://assets/audio/sfx/achievement-badge-pop-sound-3.mp3",
]
const BADGE_SFX_BUS := "SFX"
const BADGE_SFX_VOLUME_DB := 0.0

# 14 badges. Ang "id" ang sine-save sa Supabase (user_progress.unlocked_badges)
# "short" = isang sentence na ginagamit sa Achievements screen; "description" = buo, ginagamit sa pop up
const BADGES: Array = [
	{"id": "south_cotabato_historian", "short": "Answered the T'boli cultural question correctly.", "title": "South Cotabato Historian",
	 "description": "Correctly answered the T'boli cultural question and registered the lore in the Discovery Journal.",
	 "icon": "res://assets/images/badges/1.Badge_South_Cotabato_Historian.png"},
	{"id": "dreamweaver_apprentice", "short": "Finished Rhythmweaving with a 50-combo streak.", "title": "Dreamweaver Apprentice",
	 "description": "Completed Rhythmweaving with a 50-combo streak and 150,000 points, and got the South Cotabato Token.",
	 "icon": "res://assets/images/badges/2_Dreamweaver Apprentice.png"},
	{"id": "sarangani_archaeologist", "short": "Answered the Ayub Cave question correctly.", "title": "Sarangani Archaeologist",
	 "description": "Correctly answered the Ayub Cave historical question and saved the artifact profile in the Journal.",
	 "icon": "res://assets/images/badges/3. Sarangani Archaeologist.png"},
	{"id": "keeper_of_the_anthropomorphic_jars", "short": "Solved the Slide Puzzle in under 7 minutes.", "title": "Keeper of the Anthropomorphic Jars",
	 "description": "Solved the Slide Puzzle in under 7 minutes and got the Sarangani Token.",
	 "icon": "res://assets/images/badges/4. Keeper of the Anthropomorphic Jars.png"},
	{"id": "sultan_kudarat_chronicler", "short": "Answered the Islamic heritage question correctly.", "title": "Sultan Kudarat Chronicler",
	 "description": "Correctly answered the Islamic heritage and governance question.",
	 "icon": "res://assets/images/badges/5. Sultan Kudarat Chronicler.png"},
	{"id": "master_of_the_golden_grid", "short": "Scored 50,000 in Tile-Matching within 7 minutes.", "title": "Master of the Golden Grid",
	 "description": "Scored 50,000 points in Tile-Matching within 7 minutes and got the Sultan Kudarat Token.",
	 "icon": "res://assets/images/badges/6. Master of the Golden Grid.png"},
	{"id": "highland_scholar", "short": "Answered the Mt. Apo legend question correctly.", "title": "Highland Scholar",
	 "description": "Correctly answered the oral literature legend question and recorded the Mt. Apo lore.",
	 "icon": "res://assets/images/badges/7. Highland Scholar.png"},
	{"id": "mountain_climber_safe_descent", "short": "Reached the Mt. Apo summit and descended unharmed.", "title": "Mountain Climber & Safe Descent",
	 "description": "Reached the summit of Mt. Apo and finished the descent without taking damage. Got the Cotabato Province Token.",
	 "icon": "res://assets/images/badges/8. Peak Guardian & Swift Escape.png"},
	{"id": "resourceful_archivist", "short": "Collected food through fishing and farming.", "title": "Resourceful Archivist",
	 "description": "Used fishing and farming to collect food resources into the Archivist Pack.",
	 "icon": "res://assets/images/badges/9.Resourceful Archivist.png"},
	{"id": "perfect_sustenance", "short": "Restored Health and Energy to 100%.", "title": "Perfect Sustenance",
	 "description": "Restored both Health and Energy to 100% using recovery items.",
	 "icon": "res://assets/images/badges/10.Perfect Sustenance.png"},
	{"id": "apex_dodger", "short": "Escaped a hostile animal without losing Health.", "title": "Apex Dodger",
	 "description": "Sprinted away from a hostile animal's attack without losing Health.",
	 "icon": "res://assets/images/badges/11. Apex Dodger.png"},
	{"id": "endurance_explorer", "short": "Kept Energy at 80% or higher for 2 minutes.", "title": "Endurance Explorer",
	 "description": "Kept Energy at 80% or higher for 2 minutes.",
	 "icon": "res://assets/images/badges/12.Endurance Explorer.png"},
	{"id": "chronicles_of_the_wild", "short": "Survived all four night scenes.", "title": "Chronicles of the Wild",
	 "description": "Survived all four night scenes while tracking regional quests.",
	 "icon": "res://assets/images/badges/13. Chronicles of the Wild.png"},
	{"id": "soccsksargen_heritage_master", "short": "Inserted all 4 Tokens and completed the Knowledge Vault.", "title": "SOCCSKSARGEN Heritage Master",
	 "description": "Inserted all 4 regional Tokens into the Heritage Pillar and completed the Knowledge Vault.",
	 "icon": "res://assets/images/badges/14. SOCCSKSARGEN Heritage Master.png"},
]

# ---------------- DEBUG / NAME FIX SETTINGS ----------------
const DEBUG_PLAYER_NAME := true         # i-set sa false kapag ayos na
const AUTO_REPLACE_NAME_IN_UI := true   # pantapal: pinapalitan ang "James" sa lahat ng Label/RichTextLabel
const NAME_SCAN_INTERVAL := 0.3

# Pangalan ng player (galing sa Create Account)
var player_name: String = DEFAULT_PLAYER_NAME:
	set(value):
		if DEBUG_PLAYER_NAME:
			print("DEBUG PLAYER NAME: ", player_name, " -> ", value)
			if str(player_name) != str(value):
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
var shovel_equipped: bool = false
var watering_can_equipped: bool = false

# Chest storage: item ID -> quantity
var chest_inventory: Dictionary = {}

# Generic inventory for future item types.
# Battery and Fish continue using their existing counters.
var inventory_items: Dictionary = {}

# Currently selected crop for planting
var selected_seed: String = ""

# ---------------- CHEST STORAGE ----------------

func store_in_chest(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	chest_inventory[item_id] = int(chest_inventory.get(item_id, 0)) + amount
	inventory_changed.emit()
	save_progress()
	return true


func take_from_chest(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var current_amount := int(chest_inventory.get(item_id, 0))

	if current_amount < amount:
		return false

	current_amount -= amount

	if current_amount <= 0:
		chest_inventory.erase(item_id)
	else:
		chest_inventory[item_id] = current_amount

	inventory_changed.emit()
	save_progress()
	return true


# Journal & NPC Progress System
var province_journals: Dictionary = {}
var completed_npcs: Dictionary = {}

# NPC na nakausap na ni James (para sa Quest Log: "Find ...")
var met_npcs: Dictionary = {}

# Mga scene na napasukan na ni James (para sa Quest Log: "Proceed to the next province")
var visited_scenes: Dictionary = {}

# HERITAGE: kumpleto na ang Heritage Pillar (itinatakda pagkatapos ng Descent)
var heritage_complete: bool = false

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

# Para sa badge #12 (Endurance Explorer): ilang segundo nang 80%+ ang energy
var high_energy_seconds: float = 0.0

# Para sa badge #13 (Chronicles of the Wild): mga night scene na nalampasan na
const NIGHT_SCENES: Array = [
	"res://scenes/short_provinces/south_cotabato_shortway.tscn",
	"res://scenes/short_provinces/sarangani_shortway.tscn",
	"res://scenes/short_provinces/sultan_kudarat_shortway.tscn",
	"res://scenes/short_provinces/cotabato_province_shortway.tscn",
]
var night_scenes_survived: Dictionary = {}

# Badges (hindi binubura ng reset_progress; nasa Supabase user_progress)
var unlocked_badges: Array = []
var _badges_loaded := false
var _badges_loading := false
var _badge_row_exists := false
var _badge_queue: Array = []
var _badge_showing := false
var _badge_panel: PanelContainer
var _badge_icon: TextureRect
var _badge_title_lbl: Label
var _badge_desc_lbl: Label
var _badge_sfx_player: AudioStreamPlayer
var _badge_sfx_streams: Array = []
var _last_badge_sfx := -1

var _name_scan_timer := 0.0

func _ready():
	_ensure_audio_buses()
	load_progress()
	_build_badge_popup()
	_build_badge_sfx()

# Pantapal: awtomatikong pinapalitan ang "James" sa lahat ng Label/RichTextLabel
# ng pangalan ng player, kahit hardcoded pa sa dialogue o menu.
func _process(delta: float) -> void:
	if not AUTO_REPLACE_NAME_IN_UI:
		return
	_name_scan_timer += delta
	if _name_scan_timer < NAME_SCAN_INTERVAL:
		return
	_name_scan_timer = 0.0
	var pname := get_player_name()
	if pname == DEFAULT_PLAYER_NAME:
		return
	_replace_name_in_tree(get_tree().root, pname)

func _replace_name_in_tree(node: Node, pname: String) -> void:
	if node == null or node == self:
		return
	if node is RichTextLabel or node is Label:
		if node.text.contains(DEFAULT_PLAYER_NAME):
			node.text = node.text.replace(DEFAULT_PLAYER_NAME, pname)
	for child in node.get_children():
		_replace_name_in_tree(child, pname)

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
	return text.replace(DEFAULT_PLAYER_NAME, get_player_name())

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
		"met_npcs": met_npcs,
		"visited_scenes": visited_scenes,
		"heritage_complete": heritage_complete,   # HERITAGE
		"culture_read_npcs": culture_read_npcs,
		"minigame_passed": minigame_passed,
		"tokens_claimed": tokens_claimed,
		"collected_items": collected_items,
		"battery_items": battery_items,
		"fish_items": fish_items,
		"inventory_items": inventory_items,
		"chest_inventory": chest_inventory,
		"night_scenes_survived": night_scenes_survived,
		"unlocked_badges": unlocked_badges,
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
	if DEBUG_PLAYER_NAME:
		print("DEBUG _set_data: player_name in data = '", d.get("player_name", "<WALA>"), "'")
	player_name = str(d.get("player_name", DEFAULT_PLAYER_NAME))
	province_journals = d.get("province_journals", {})
	completed_npcs = d.get("completed_npcs", {})
	met_npcs = d.get("met_npcs", {})
	visited_scenes = d.get("visited_scenes", {})
	heritage_complete = bool(d.get("heritage_complete", false))   # HERITAGE
	culture_read_npcs = d.get("culture_read_npcs", {})
	minigame_passed = d.get("minigame_passed", {})
	tokens_claimed = d.get("tokens_claimed", {})
	collected_items = d.get("collected_items", {})
	battery_items = int(d.get("battery_items", 0))
	fish_items = int(d.get("fish_items", 0))
	inventory_items = d.get("inventory_items", {}).duplicate(true)
	chest_inventory = d.get("chest_inventory", {}).duplicate(true)
	night_scenes_survived = d.get("night_scenes_survived", {})
	var saved_badges = d.get("unlocked_badges", [])
	if saved_badges is Array:
		for bid in saved_badges:
			if not unlocked_badges.has(bid):
				unlocked_badges.append(bid)
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
		push_warning("save_progress: hindi mabuksan ang " + SAVE_PATH)
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
	met_npcs = {}
	visited_scenes = {}
	heritage_complete = false   # HERITAGE
	culture_read_npcs = {}
	npc_quiz_cooldowns = {}
	minigame_passed = {}
	tokens_claimed = {}
	collected_items = {}
	pending_token_toast = ""
	current_minigame_npc = ""
	battery_items = 0
	fish_items = 0
	inventory_items.clear()
	chest_inventory.clear()
	night_scenes_survived = {}
	high_energy_seconds = 0.0
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
	heritage_completed.emit()   # HERITAGE: para bumalik sa walang-token ang pillar


# ---------------- GENERIC INVENTORY ----------------

func get_backpack_item_count(item_id: String) -> int:
	if item_id == "battery":
		return battery_items

	if item_id == "fish":
		return fish_items

	return int(inventory_items.get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	if item_id == "battery":
		add_battery(amount)
		return true

	if item_id == "fish":
		add_fish(amount)
		return true

	inventory_items[item_id] = get_backpack_item_count(item_id) + amount
	inventory_changed.emit()
	save_progress()
	return true


func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	var current := get_backpack_item_count(item_id)

	if current < amount:
		return false

	if item_id == "battery":
		for i in range(amount):
			if not consume_battery():
				return false
		return true

	if item_id == "fish":
		for i in range(amount):
			if not consume_fish():
				return false
		return true

	var remaining := current - amount

	if remaining == 0:
		inventory_items.erase(item_id)
	else:
		inventory_items[item_id] = remaining

	inventory_changed.emit()
	save_progress()
	return true


func transfer_to_chest(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if get_backpack_item_count(item_id) < amount:
		return false

	if not remove_item(item_id, amount):
		return false

	if not store_in_chest(item_id, amount):
		add_item(item_id, amount)
		return false

	return true


func transfer_to_backpack(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if int(chest_inventory.get(item_id, 0)) < amount:
		return false

	if not take_from_chest(item_id, amount):
		return false

	if not add_item(item_id, amount):
		store_in_chest(item_id, amount)
		return false

	return true


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

# ---------------- NPC MET (Quest Log: "Find ...") ----------------

func mark_npc_met(npc_name: String) -> void:
	if npc_name == "" or met_npcs.get(npc_name, false):
		return
	met_npcs[npc_name] = true
	save_progress()

func is_npc_met(npc_name: String) -> bool:
	return met_npcs.get(npc_name, false)

# ---------------- SCENE VISITED (Quest Log: "Proceed to the next province") ----------------

func mark_scene_visited(scene_path: String) -> void:
	if scene_path == "" or visited_scenes.get(scene_path, false):
		return
	visited_scenes[scene_path] = true
	save_progress()

func has_visited_scene(scene_path: String) -> bool:
	return visited_scenes.get(scene_path, false)

# ---------------- HERITAGE PILLAR ----------------
# HERITAGE: tawagin sa dulo ng Descent (pagkatapos ng cutscene, bago lumipat sa homebase)

func complete_heritage_pillar() -> void:
	if heritage_complete:
		return
	heritage_complete = true
	save_progress()
	heritage_completed.emit()

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
	var prev_uid := cloud_user_id
	cloud_user_id = ""
	if auth_data == null:
		return
	_set_cloud_user_inner(auth_data)
	if cloud_user_id != prev_uid:
		# ibang user: huwag mag-leak ang badges ng nakaraang account
		unlocked_badges.clear()
		_badges_loaded = false
		_badges_loading = false
		_badge_row_exists = false

func _set_cloud_user_inner(auth_data) -> void:
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
			if DEBUG_PLAYER_NAME:
				print("DEBUG download_cloud_save: cloud player_name = '", d.get("player_name", "<WALA>"), "'")
			apply_save_data(d)
			return true
	if DEBUG_PLAYER_NAME:
		print("DEBUG download_cloud_save: walang row/data sa cloud")
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
	if DEBUG_PLAYER_NAME:
		print("DEBUG upload_cloud_save: ina-upload ang player_name = '", data["player_name"], "'")

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
	if DEBUG_PLAYER_NAME:
		print("DEBUG upload_cloud_save: SUCCESS")
	return true

# ---------------- BADGES ----------------
# Gamitin kahit saan:  Global.unlock_badge("south_cotabato_historian")
# Isang beses lang magpa-pop up ang bawat badge, at nase-save sa Supabase (user_progress.unlocked_badges)

func get_badge(id: String) -> Dictionary:
	for b in BADGES:
		if b["id"] == id:
			return b
	return {}

func is_badge_unlocked(id: String) -> bool:
	return unlocked_badges.has(id)

# Tawagin kapag nakaligtas ang player sa isang night scene. Kapag lahat ng apat, ibibigay ang #13.
func mark_night_survived(scene_path: String) -> void:
	if not NIGHT_SCENES.has(scene_path):
		return
	night_scenes_survived[scene_path] = true
	save_progress()
	for p in NIGHT_SCENES:
		if not night_scenes_survived.has(p):
			return
	unlock_badge("chronicles_of_the_wild")

# Ibibigay ang huling badge (#14) kapag kumpleto na ang 13 pang ibang badge.
# Tawagin sa homebase pagkatapos ng Descent.
func check_final_badge() -> void:
	await _ensure_badges_loaded()
	for b in BADGES:
		if b["id"] == "soccsksargen_heritage_master":
			continue
		if not unlocked_badges.has(b["id"]):
			return
	await unlock_badge("soccsksargen_heritage_master")

func unlock_badge(id: String) -> void:
	var data := get_badge(id)
	if data.is_empty():
		push_warning("Badge: walang badge na may id '%s'" % id)
		return
	await _ensure_badges_loaded()
	if unlocked_badges.has(id):
		return
	unlocked_badges.append(id)
	print("Badge: unlocked ", id, " | user id = '", _badge_user_id(), "'")
	save_progress()   # local save, kahit walang internet/session
	badge_unlocked.emit(id)
	_badge_queue.append(data)
	_show_next_badge()
	await _save_badges()

# Tinatawag pagka-login: ina-upload sa user_progress ang mga badge na nasa local pero wala pa sa cloud
func sync_badges_to_cloud() -> void:
	await _ensure_badges_loaded()
	if not _badges_loaded:
		push_warning("Badge sync: hindi makuha ang cloud badges, hindi muna mag-a-upload")
		return
	if unlocked_badges.is_empty():
		return
	print("Badge: syncing to cloud ", unlocked_badges)
	await _save_badges()

# Para sa testing lang: buburahin lahat ng badge ng user
func debug_reset_badges() -> void:
	await _ensure_badges_loaded()
	unlocked_badges.clear()
	await _save_badges()

func _badge_user_id() -> String:
	if cloud_user_id != "":
		return cloud_user_id
	if Supabase.auth != null and Supabase.auth._session != null and Supabase.auth._session.has("user"):
		return str(Supabase.auth._session["user"]["id"])
	return ""

func _ensure_badges_loaded() -> void:
	if _badges_loaded:
		return
	if _badges_loading:
		while _badges_loading:
			await get_tree().process_frame
		return
	_badges_loading = true
	_badges_loaded = await _fetch_badges()
	_badges_loading = false


func _fetch_badges() -> bool:
	var uid := _badge_user_id()
	if uid == "":
		push_warning("Badge: walang user id, hindi makuha ang badges")
		return false
	var q = SupabaseQuery.new().from("user_progress").select(["unlocked_badges"]).eq("user_id", uid)
	var res = await Supabase.database.query(q).completed
	if res.error != null:
		push_warning("Badge load error: " + str(res.error))
		return false
	_badge_row_exists = res.data is Array and res.data.size() > 0
	if _badge_row_exists:
		var saved = res.data[0].get("unlocked_badges", [])
		if saved is Array:
			for b in saved:
				if not unlocked_badges.has(b):
					unlocked_badges.append(b)
	print("Badge: loaded ", unlocked_badges)
	return true

func _save_badges() -> void:
	var uid := _badge_user_id()
	if uid == "":
		push_warning("Badge: walang user id, hindi nasave ang badge")
		return
	var res
	if _badge_row_exists:
		res = await Supabase.database.query(
			SupabaseQuery.new().from("user_progress").update({"unlocked_badges": unlocked_badges}).eq("user_id", uid)
		).completed
	else:
		res = await Supabase.database.query(
			SupabaseQuery.new().from("user_progress").insert([{"user_id": uid, "unlocked_badges": unlocked_badges}])
		).completed
		if res.error == null:
			_badge_row_exists = true
	if res.error != null:
		print("❌ Badge save error: ", res.error)
		push_warning("Badge save error: " + str(res.error))
	else:
		print("Badge: saved ", unlocked_badges)

# ---------------- BADGE POPUP ----------------

func _build_badge_popup() -> void:
	var font: Font = null
	if ResourceLoader.exists(BADGE_FONT_PATH):
		font = load(BADGE_FONT_PATH)

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_badge_panel = PanelContainer.new()
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	sb.border_color = Color(1.0, 0.9, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_badge_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_badge_panel)
	_badge_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_badge_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.add_child(row)

	_badge_icon = TextureRect.new()
	_badge_icon.custom_minimum_size = BADGE_ICON_SIZE
	_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge_icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var header := Label.new()
	header.text = "BADGE UNLOCKED!"
	_badge_style(header, font, BADGE_HEADER_FONT_SIZE, Color(0.6, 1.0, 0.6))
	col.add_child(header)

	_badge_title_lbl = Label.new()
	_badge_style(_badge_title_lbl, font, BADGE_TITLE_FONT_SIZE, Color(1.0, 0.9, 0.3))
	col.add_child(_badge_title_lbl)

	_badge_desc_lbl = Label.new()
	_badge_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_badge_desc_lbl.custom_minimum_size = Vector2(BADGE_POPUP_WIDTH, 0)
	_badge_style(_badge_desc_lbl, font, BADGE_DESC_FONT_SIZE, Color.WHITE)
	col.add_child(_badge_desc_lbl)

# Gumagawa ng audio player at naglo-load ng tatlong sound
func _build_badge_sfx() -> void:
	_badge_sfx_player = AudioStreamPlayer.new()
	_badge_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_badge_sfx_player.volume_db = BADGE_SFX_VOLUME_DB
	_badge_sfx_player.bus = BADGE_SFX_BUS if AudioServer.get_bus_index(BADGE_SFX_BUS) != -1 else "Master"
	add_child(_badge_sfx_player)

	_badge_sfx_streams.clear()
	for path in BADGE_SFX_PATHS:
		if ResourceLoader.exists(path):
			_badge_sfx_streams.append(load(path))
		else:
			push_warning("Badge SFX: hindi makita ang " + str(path))

# Random na sound, hindi pareho sa huling pinatugtog
func _play_badge_sfx() -> void:
	if _badge_sfx_player == null or _badge_sfx_streams.is_empty():
		return
	var idx := randi() % _badge_sfx_streams.size()
	if _badge_sfx_streams.size() > 1:
		while idx == _last_badge_sfx:
			idx = randi() % _badge_sfx_streams.size()
	_last_badge_sfx = idx
	_badge_sfx_player.stream = _badge_sfx_streams[idx]
	_badge_sfx_player.play()

func _badge_style(lbl: Label, font: Font, size: int, color: Color) -> void:
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_next_badge() -> void:
	if _badge_showing or _badge_queue.is_empty():
		return
	_badge_showing = true
	var data: Dictionary = _badge_queue.pop_front()
	_badge_title_lbl.text = data["title"]
	_badge_desc_lbl.text = data["description"]
	var path: String = data["icon"]
	_badge_icon.texture = load(path) if ResourceLoader.exists(path) else null

	_badge_panel.visible = true
	_play_badge_sfx()
	_badge_panel.reset_size()
	await get_tree().process_frame
	_badge_panel.position.y = -_badge_panel.size.y - 10.0

	var tw := create_tween()
	tw.tween_property(_badge_panel, "position:y", BADGE_POPUP_TOP_MARGIN, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(BADGE_SHOW_SECONDS).timeout
	var tw2 := create_tween()
	tw2.tween_property(_badge_panel, "position:y", -_badge_panel.size.y - 10.0, 0.3)
	await tw2.finished

	_badge_panel.visible = false
	_badge_showing = false
	_show_next_badge()
