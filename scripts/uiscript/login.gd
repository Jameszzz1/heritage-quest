extends Control
@onready var login_ui: Panel = $LoginUI
@onready var create_account_ui: Panel = $CreateAccountUI
@onready var otp_ui: Panel = $otpUI
@onready var email_field = $CreateAccountUI/EmailLE
@onready var password_field = $CreateAccountUI/PassLE
@onready var login_email_field = $LoginUI/Username
@onready var login_password_field = $LoginUI/Password
@onready var otp_input = $otpUI/OTPInput
@onready var otp_status = $otpUI/OTPStatus
var current_email = ""
var is_login_otp = false
func _ready() -> void:
	login_ui.show()
	create_account_ui.hide()
	otp_ui.hide()
func _on_create_acc_pressed() -> void:
	login_ui.hide()
	create_account_ui.show()
func _on_loginn_pressed() -> void:
	var email = login_email_field.text
	var password = login_password_field.text
	if email == "" or password == "":
		print("Paki-fill up ang email at password!")
		return
	print("Logging in...")
	var auth_task = Supabase.auth.sign_in(email, password)
	var result = await auth_task.completed
	if result.error == null:
		print("✅ Logged in - Sending OTP...")
		current_email = email
		is_login_otp = true
		var otp_task = Supabase.auth.send_otp(email)
		var otp_result = await otp_task.completed
		print("OTP Send Result: ", otp_result.data)
		print("OTP Send Error: ", otp_result.error)
		login_ui.hide()
		otp_ui.show()
		otp_input.text = ""
		otp_status.text = "OTP sent to: " + email
	else:
		print("❌ LOGIN ERROR: ", str(result.error))
func _on_verify_pressed() -> void:
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
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	else:
		otp_status.text = "❌ Wrong or expired OTP. Try again."
		print("OTP Failed: ", result.error)
func _on_register_pressed() -> void:
	var email = email_field.text
	var password = password_field.text
	if email == "" or password == "":
		print("Need email and password!")
		return
	var auth_task = Supabase.auth.sign_up(email, password)
	var result = await auth_task.completed
	if result.error == null:
		print("✅ REGISTER SUCCESS! OTP sent automatically by Supabase!")
		current_email = email
		is_login_otp = false
		create_account_ui.hide()
		otp_ui.show()
		otp_input.text = ""
		otp_status.text = "OTP sent to: " + email
	else:
		print("❌ REGISTER ERROR: ", str(result.error))
func _on_button_pressed() -> void:
	create_account_ui.hide()
	login_ui.show()
