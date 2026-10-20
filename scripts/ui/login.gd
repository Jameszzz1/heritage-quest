extends Control

const REMEMBER_PATH := "user://remember_login.dat"
const OLD_REMEMBER_PATH := "user://remember_me.cfg"
const MIN_PASSWORD_LENGTH := 6
const POPUP_FONT := preload("res://assets/fonts/GrapeSoda.ttf")
const POPUP_FONT_SIZE := 12
const POPUP_ALPHA := 0.6       # 0.6 = 40% transparent
const POPUP_DIM := 0.4         # dilim sa likod ng popup

@onready var login_ui: Panel = $LoginUI
@onready var create_account_ui: Panel = $CreateAccountUI
@onready var otp_ui: Panel = $otpUI
@onready var email_field = $CreateAccountUI/EmailLE
@onready var password_field = $CreateAccountUI/PassLE
@onready var player_name_field = $CreateAccountUI/PlayerNameLE
@onready var login_email_field = $LoginUI/Username
@onready var login_password_field = $LoginUI/Password
@onready var remember_me: CheckBox = $LoginUI/RememberMe
@onready var login_btn: Button = $LoginUI/Loginn
@onready var register_btn: Button = $CreateAccountUI/Register
@onready var otp_input = $otpUI/OTPInput
@onready var otp_status = $otpUI/OTPStatus

var current_email = ""
var current_password = ""
var trusted_email = ""   # email na naka-remember (skip OTP)
var is_login_otp = false
var pending_player_name = ""   # pangalang tinype sa Register, ise-save pagka-verify ng OTP

var popup_root: Control
var popup_title: Label
var popup_msg: Label
var popup_ok: Button

func _ready() -> void:
	login_ui.show()
	create_account_ui.hide()
	otp_ui.hide()
	login_password_field.secret = true
	password_field.secret = true

	_build_popup()

	# Burahin ang lumang file (plain text) kung nandiyan pa
	if FileAccess.file_exists(OLD_REMEMBER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_REMEMBER_PATH))

	_load_remembered()

# ---------------- POPUP ----------------

func _build_popup() -> void:
	popup_root = Control.new()
	popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_root.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_root.z_index = 100
	popup_root.visible = false
	add_child(popup_root)

	# Dim sa likod (humaharang sa click)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, POPUP_DIM)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_root.add_child(dim)

	# Laging nasa gitna
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.25, 0.25, POPUP_ALPHA)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title + X
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	header.add_child(spacer)

	popup_title = Label.new()
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_override("font", POPUP_FONT)
	popup_title.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	header.add_child(popup_title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_override("font", POPUP_FONT)
	close_btn.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
	close_btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.1, 0.1))
	close_btn.pressed.connect(_close_popup)
	header.add_child(close_btn)

	# Message (naka-center)
	popup_msg = Label.new()
	popup_msg.custom_minimum_size = Vector2(220, 0)
	popup_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_msg.add_theme_font_override("font", POPUP_FONT)
	popup_msg.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	vbox.add_child(popup_msg)

	# OK button: puting pill, itim na text
	popup_ok = Button.new()
	popup_ok.text = "OK"
	popup_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup_ok.custom_minimum_size = Vector2(56, 16)
	popup_ok.add_theme_font_override("font", POPUP_FONT)
	popup_ok.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	popup_ok.add_theme_stylebox_override("normal", _pill_style(Color.WHITE))
	popup_ok.add_theme_stylebox_override("hover", _pill_style(Color(0.9, 0.9, 0.9)))
	popup_ok.add_theme_stylebox_override("pressed", _pill_style(Color(0.75, 0.75, 0.75)))
	popup_ok.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		popup_ok.add_theme_color_override(c, Color.BLACK)
	popup_ok.pressed.connect(_close_popup)
	vbox.add_child(popup_ok)

func _pill_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(100)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

func show_popup(title: String, message: String) -> void:
	popup_title.text = title
	popup_msg.text = message
	popup_root.show()
	popup_ok.grab_focus()

func _close_popup() -> void:
	popup_root.hide()

# ---------------- REMEMBER ME ----------------

func _remember_key() -> String:
	return OS.get_unique_id() + "heritage_quest_remember"

func _save_remembered(email: String, password: String) -> void:
	var cfg := ConfigFile.new()
	if remember_me.button_pressed:
		cfg.set_value("login", "remember", true)
		cfg.set_value("login", "email", email)
		cfg.set_value("login", "password", password)
		trusted_email = email
	else:
		cfg.set_value("login", "remember", false)
		trusted_email = ""
	cfg.save_encrypted_pass(REMEMBER_PATH, _remember_key())

func _load_remembered() -> void:
	if not FileAccess.file_exists(REMEMBER_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load_encrypted_pass(REMEMBER_PATH, _remember_key()) != OK:
		return
	if cfg.get_value("login", "remember", false):
		trusted_email = cfg.get_value("login", "email", "")
		login_email_field.text = trusted_email
		login_password_field.text = cfg.get_value("login", "password", "")
		remember_me.button_pressed = true

# ---------------- HELPERS ----------------

func _is_valid_email(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
	return regex.search(email) != null

# Supabase: kapag existing na ang email, success pero walang laman ang identities
func _is_email_taken(result) -> bool:
	var ids = null
	if result.data is Dictionary:
		ids = result.data.get("identities", null)
		if ids == null and result.data.get("user") is Dictionary:
			ids = result.data["user"].get("identities", null)
	if ids == null and result.get("user") != null and "identities" in result.user:
		ids = result.user.identities
	return ids is Array and ids.is_empty()

# Pumapasok na sa game: load ng cloud save, tapos main menu
func _finish_login(auth_data, is_new_account: bool = false) -> void:
	Global.reset_progress()
	Global.player_name = Global.DEFAULT_PLAYER_NAME   # linisin muna bago mag-load ng account
	Global.set_cloud_user_from_auth(auth_data)
	print("Cloud user id: ", Global.cloud_user_id)
	var found = await Global.download_cloud_save()
	print("Cloud save found: ", found)

	# Bagong account: laging gamitin ang Player Name na tinype sa Register
	if is_new_account and pending_player_name != "":
		Global.player_name = pending_player_name
		Global.save_progress()
		await Global.upload_cloud_save()
	pending_player_name = ""

	print("Player name: ", Global.player_name)
	LoadingScreen.change_scene("res://scenes/ui/main_menu.tscn")

# ---------------- NAVIGATION ----------------

func _on_create_acc_pressed() -> void:
	MusicManager.play_button_sfx()
	login_ui.hide()
	create_account_ui.show()

func _on_button_pressed() -> void:
	MusicManager.play_button_sfx()
	create_account_ui.hide()
	login_ui.show()

# ---------------- LOGIN ----------------

func _on_loginn_pressed() -> void:
	MusicManager.play_button_sfx()
	var email = login_email_field.text.strip_edges()
	var password = login_password_field.text

	if email == "" or password == "":
		show_popup("Login", "Please fill in your email and password.")
		return
	if not _is_valid_email(email):
		show_popup("Login", "Please enter a valid email address.")
		return

	login_btn.disabled = true
	var auth_task = Supabase.auth.sign_in(email, password)
	var result = await auth_task.completed

	if result.error != null:
		login_btn.disabled = false
		_show_login_error(str(result.error))
		return

	current_email = email
	current_password = password

	# Naka-Remember me at kilalang email -> walang OTP
	var skip_otp: bool = remember_me.button_pressed \
		and trusted_email != "" \
		and email.to_lower() == trusted_email.to_lower()

	if skip_otp:
		print("✅ Trusted device - skipping OTP")
		_save_remembered(email, password)
		await _finish_login(result.data)
		login_btn.disabled = false
		return

	# Kailangan ng OTP
	is_login_otp = true
	var otp_task = Supabase.auth.send_otp(email)
	var otp_result = await otp_task.completed
	login_btn.disabled = false
	if otp_result.error != null:
		print("OTP Send Error: ", otp_result.error)
		show_popup("Login", "Could not send the OTP. Please try again.")
		return
	login_ui.hide()
	otp_ui.show()
	otp_input.text = ""
	otp_status.text = "OTP sent to: " + email

func _show_login_error(raw: String) -> void:
	print("❌ LOGIN ERROR: ", raw)
	var err := raw.to_lower()
	if "invalid" in err or "credentials" in err or "invalid_grant" in err:
		show_popup("Login Failed", "Wrong email or password.")
	elif "not confirmed" in err:
		show_popup("Login Failed", "Your email is not verified yet. Please register again to get a new OTP.")
	elif "rate" in err or "too many" in err:
		show_popup("Login Failed", "Too many attempts. Please wait a moment and try again.")
	else:
		show_popup("Login Failed", "Something went wrong. Check your internet and try again.")

# ---------------- OTP ----------------

func _on_verify_pressed() -> void:
	MusicManager.play_button_sfx()
	var token = otp_input.text.strip_edges()
	if token == "":
		otp_status.text = "❌ Enter the OTP!"
		return
	otp_status.text = "Verifying..."
	var type = "email" if is_login_otp else "signup"
	var task = Supabase.auth.verify_otp(current_email, token, type)
	var result = await task.completed
	print("OTP Result: ", result.data)
	print("OTP Error: ", result.error)
	if result.error == null and result.data != null and result.data.has("access_token"):
		print("✅ OTP Verified!")
		if is_login_otp:
			_save_remembered(current_email, current_password)
		otp_status.text = "Loading your progress..."
		await _finish_login(result.data, not is_login_otp)
	else:
		otp_status.text = "❌ Wrong or expired OTP. Try again."
		print("OTP Failed: ", result.error)

# ---------------- REGISTER ----------------

func _on_register_pressed() -> void:
	MusicManager.play_button_sfx()
	var email = email_field.text.strip_edges()
	var password = password_field.text
	# Tinatanggal ang [ ] para hindi masira ang BBCode sa dialogue box
	var player_name = player_name_field.text.strip_edges().replace("[", "").replace("]", "")

	if email == "" or password == "" or player_name == "":
		show_popup("Register", "Please fill in your player name, email and password.")
		return
	if player_name.length() < 2:
		show_popup("Register", "Player name must be at least 2 characters.")
		return
	if not _is_valid_email(email):
		show_popup("Register", "Please enter a valid email address.")
		return
	if password.length() < MIN_PASSWORD_LENGTH:
		show_popup("Register", "Password must be at least %d characters." % MIN_PASSWORD_LENGTH)
		return

	register_btn.disabled = true
	var auth_task = Supabase.auth.sign_up(email, password)
	var result = await auth_task.completed
	register_btn.disabled = false

	print("Register data: ", result.data)

	if result.error != null:
		_show_register_error(str(result.error))
		return

	if _is_email_taken(result):
		show_popup("Register Failed", "That email is already taken.")
		return

	print("✅ REGISTER SUCCESS! OTP sent automatically by Supabase!")
	current_email = email
	pending_player_name = player_name
	is_login_otp = false
	create_account_ui.hide()
	otp_ui.show()
	otp_input.text = ""
	otp_status.text = "OTP sent to: " + email

func _show_register_error(raw: String) -> void:
	print("❌ REGISTER ERROR: ", raw)
	var err := raw.to_lower()
	if "already" in err or "registered" in err or "exists" in err:
		show_popup("Register Failed", "That email is already taken.")
	elif "password" in err:
		show_popup("Register Failed", "Password is too weak. Try a longer one.")
	elif "rate" in err or "too many" in err:
		show_popup("Register Failed", "Too many attempts. Please wait a moment and try again.")
	else:
		show_popup("Register Failed", "Something went wrong. Check your internet and try again.")
