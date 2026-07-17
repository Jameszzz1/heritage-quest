@tool
extends BaseTask
class_name StorageTask

enum METHODS {
	LIST_BUCKETS,
	GET_BUCKET,
	CREATE_BUCKET,
	UPDATE_BUCKET,
	EMPTY_BUCKET,
	DELETE_BUCKET,
	
	LIST_OBJECTS,
	UPLOAD_OBJECT,
	UPDATE_OBJECT,
	MOVE_OBJECT,
	CREATE_SIGNED_URL,
	DOWNLOAD,
	GET_PUBLIC_URL,
	REMOVE
}

var bytepayload : PackedByteArray

func match_code(code : int) -> int:
	match code:
		METHODS.LIST_BUCKETS, METHODS.GET_BUCKET, METHODS.DOWNLOAD: return HTTPClient.METHOD_GET
		METHODS.CREATE_BUCKET, METHODS.UPDATE_BUCKET, METHODS.EMPTY_BUCKET, \
		METHODS.LIST_OBJECTS, METHODS.UPLOAD_OBJECT, METHODS.MOVE_OBJECT, \
		METHODS.CREATE_SIGNED_URL: return HTTPClient.METHOD_POST
		METHODS.UPDATE_OBJECT: return HTTPClient.METHOD_PUT
		METHODS.DELETE_BUCKET, METHODS.REMOVE: return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_GET

# Inalis na natin ang 'handler: HTTPRequest' sa dulo para maging 4 arguments
func _on_task_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	var result_body = JSON.parse_string(body.get_string_from_utf8())
	if result_body == null:
		result_body = {}
		
	if response_code in [200, 201, 204]:
		if _code == METHODS.DOWNLOAD:
			_complete(body)
		else:
			if _code == METHODS.CREATE_SIGNED_URL:
				result_body.signedURL = get_meta("base_url") + result_body.signedURL
				var download = get_meta("options").get("download")
				if download:
					result_body.signedURL += "&download=%s" % download if (download is String) else get_meta("object")
			_complete(result_body)
	else:
		if result_body.is_empty():
			result_body.statusCode = str(response_code)
		_complete(null, result_body)

func complete(_data = null, _error = null) -> void:
	super._complete(_data, _error)
