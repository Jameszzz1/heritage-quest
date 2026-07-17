extends VBoxContainer

var unlocked_list: Array = []

func _ready():
	unlocked_list = []
	update_ui_icons() # Set to dark initially
	
	await wait_for_session()
	await load_from_supabase()

func wait_for_session():
	var tries = 0
	while (Supabase.auth == null or Supabase.auth._session == null or not Supabase.auth._session.has("user")) and tries < 15:
		print("⏳ Waiting for session (Try ", tries, ")...")
		await get_tree().create_timer(0.5).timeout
		tries += 1
	
	if Supabase.auth._session == null or not Supabase.auth._session.has("user"):
		print("❌ FAILED: Session not ready.")
	else:
		print("✅ Session ready!")

func load_from_supabase():
	if Supabase.auth._session == null or not Supabase.auth._session.has("user"):
		print("❌ No valid session found.")
		return

	var user_id = Supabase.auth._session["user"]["id"]
	print("🎯 Target User ID: ", user_id)

	var query = SupabaseQuery.new().from("user_progress").select(["unlocked_badges"]).eq("user_id", user_id)
	var task = Supabase.database.query(query)
	
	# Hintayin ang task.completed signal
	var result = await task.completed

	print("--- DEBUG LOG ---")
	
	# SA VERSION MO: Kung ang result ay <Node>, kailangan nating kunin ang data property nito
	var final_data = []
	
	if result is Array:
		final_data = result
	elif result is Dictionary and result.has("data"):
		final_data = result["data"]
	elif result is Object:
		# Pilitin nating hanapin ang data property sa loob ng Node object
		if "data" in result:
			final_data = result.data
		elif result.has_method("get_data"):
			final_data = result.get_data()

	print("EXTRACTED DATA: ", final_data)

	if final_data is Array and final_data.size() > 0:
		# Kunin ang unlocked_badges array mula sa unang row
		unlocked_list = final_data[0]["unlocked_badges"]
		print("✅ Badges Found: ", unlocked_list)
		update_ui_icons()
	else:
		print("❌ No row found for user or empty data.")

func update_ui_icons():
	recursive_apply_logic(self)

func recursive_apply_logic(node):
	for child in node.get_children():
		if child is TextureRect:
			if unlocked_list.has(child.name):
				child.modulate = Color(1, 1, 1, 1) # Lit
				print("✨ Light ON: ", child.name)
			else:
				child.modulate = Color(0.15, 0.15, 0.15, 1) # Dark
		
		if child.get_child_count() > 0:
			recursive_apply_logic(child)
