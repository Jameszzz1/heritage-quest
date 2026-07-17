@tool
extends BaseTask
class_name AuthTask

func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	var result_body : Dictionary = {}
	if(!body.is_empty()):
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			result_body = parsed
	
	if result != 0:
		_complete(null, {"message": "Connection Error", "details": result})
		return

	if response_code < 300:
		_complete(result_body)
	else:
		_complete(null, result_body)

func _complete(_data = null, _error = null) -> void:
	super._complete(_data, _error)
