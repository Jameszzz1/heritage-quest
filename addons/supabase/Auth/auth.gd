@tool
extends Node
class_name SupabaseAuth
signal signed_up(user)
signal signed_in(user)
signal error(error)
var _config : Dictionary
var _header : PackedStringArray
var _session : Dictionary
func _init(config : Dictionary, header : PackedStringArray) -> void:
	_config = config
	_header = header
	name = "Auth"
func sign_up(email : String, password : String, data : Dictionary = {}) -> Variant:
	var endpoint : String = _config["supabaseUrl"] + "/auth/v1/signup"
	var body : String = JSON.stringify({"email": email, "password": password, "data": data})
	var task = load("res://addons/supabase/Auth/auth_task.gd").new()
	task._setup(HTTPClient.METHOD_POST, endpoint, _header, body)
	_process_task(task)
	return task
func sign_in(email : String, password : String) -> Variant:
	var endpoint : String = _config["supabaseUrl"] + "/auth/v1/token?grant_type=password"
	var body : String = JSON.stringify({"email": email, "password": password})
	var task = load("res://addons/supabase/Auth/auth_task.gd").new()
	task._setup(HTTPClient.METHOD_POST, endpoint, _header, body)
	_process_task(task)
	return task
func send_otp(email: String) -> Variant:
	var endpoint: String = _config["supabaseUrl"] + "/auth/v1/otp"
	var body: String = JSON.stringify({
		"email": email,
		"create_user": true
	})
	var task = load("res://addons/supabase/Auth/auth_task.gd").new()
	task._setup(HTTPClient.METHOD_POST, endpoint, _header, body)
	_process_task(task)
	return task
func verify_otp(email: String, token: String, type: String = "email") -> Variant:
	var endpoint: String = _config["supabaseUrl"] + "/auth/v1/verify"
	var body: String = JSON.stringify({
		"email": email,
		"token": token,
		"type": type
	})
	var task = load("res://addons/supabase/Auth/auth_task.gd").new()
	task._setup(HTTPClient.METHOD_POST, endpoint, _header, body)
	_process_task(task)
	return task
func _process_task(task) -> void:
	var httprequest := HTTPRequest.new()
	add_child(httprequest)
	task.completed.connect(_on_task_completed)
	task.push_request(httprequest)
func _on_task_completed(task) -> void:
	if task.error != null:
		emit_signal("error", task.error)
		return
	if task.data.has("error") or task.data.has("error_code"):
		task.error = task.data
		emit_signal("error", task.error)
		return
	if task.data.has("access_token"):
		_session = task.data
		emit_signal("signed_in", _session)
func __get_session_header() -> PackedStringArray:
	if _session.is_empty():
		return []
	return ["Authorization: Bearer " + _session["access_token"]]
