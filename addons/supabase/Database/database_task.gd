@tool
extends BaseTask
class_name DatabaseTask

func match_code(code : int) -> int:
	match code:
		SupabaseQuery.REQUESTS.INSERT: return HTTPClient.METHOD_POST
		SupabaseQuery.REQUESTS.SELECT: return HTTPClient.METHOD_GET
		SupabaseQuery.REQUESTS.UPDATE: return HTTPClient.METHOD_PATCH
		SupabaseQuery.REQUESTS.DELETE: return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_POST

# Inalis natin ang 'handler: HTTPRequest' para maging 4 arguments nalang
func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	var result_body: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 300:
		complete(result_body)
	else:
		# Gumagamit tayo ng generic Dictionary muna para iwas crash sa error parsing
		complete(null, result_body)

func complete(_data = null, _error = null) -> void:
	super._complete(_data, _error)
