@tool
extends Node
class_name BaseTask

signal completed(task)

var _code : int = -1
var _endpoint : String
var _header : PackedStringArray
var _body : String

var data : Variant
var error : Variant

func _setup(code : int, endpoint : String, header : PackedStringArray, body : String = "") -> void:
	_code = code
	_endpoint = endpoint
	_header = header
	_body = body

func push_request(httprequest : HTTPRequest) -> void:
	httprequest.request_completed.connect(_on_task_completed)

	var err = httprequest.request(
		_endpoint,
		_header,
		match_code(_code),
		_body
	)

	if err != OK:
		_on_task_completed(1, 0, PackedStringArray(), PackedByteArray())

func match_code(code : int) -> int:
	match code:
		HTTPClient.METHOD_POST:
			return HTTPClient.METHOD_POST
		HTTPClient.METHOD_PUT:
			return HTTPClient.METHOD_PUT
		HTTPClient.METHOD_DELETE:
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET

func _on_task_completed(_result : int, _response_code : int, _headers : PackedStringArray, _body : PackedByteArray) -> void:
	pass

func _complete(_data = null, _error = null) -> void:
	data = _data
	error = _error
	emit_signal("completed", self)
