# tcp_server.gd
extends Node

var _server: TCPServer
var _port = 9080
var pause_menu
var logger

func _ready():
	_server = TCPServer.new()
	if _server.listen(_port) != OK:
		push_error("Не удалось запустить сервер!")
	else:
		print("Сервер запущен на порту ", _port)
	
	# Ищем ноду паузы и логгер
	pause_menu = get_tree().get_first_node_in_group("pause_menu")
	logger = get_node("/root/Logger")

func _process(_delta):
	if _server.is_connection_available():
		var client: StreamPeerTCP = _server.take_connection()
		var request = client.get_utf8_string(client.get_available_bytes())
		
		if request:
			handle_request(client, request)

func handle_request(client: StreamPeerTCP, request: String):
	print("Получен запрос: ", request)
	
	if "GET /button_pressed" in request:
		toggle_pause_from_server()
		send_http_response(client, "200 OK", "text/plain", "Пауза активирована")
		
	elif "GET /logs/json" in request:
		var logs_data = get_all_logs_json()
		send_http_response(client, "200 OK", "application/json", logs_data)
		
	elif "GET /logs/csv" in request:
		var csv_data = get_all_logs_csv()
		send_http_response(client, "200 OK", "text/csv", csv_data)
		
	elif "GET /sessions/list" in request:
		var sessions_list = get_sessions_list()
		send_http_response(client, "200 OK", "application/json", sessions_list)
		
	elif "GET /session/" in request:
		var session_id = extract_session_id(request)
		if session_id:
			var session_data = get_session_data(session_id)
			send_http_response(client, "200 OK", "application/json", session_data)
		else:
			send_http_response(client, "404 Not Found", "text/plain", "Session not found")
			
	elif "GET /stats" in request:
		var stats = get_session_stats()
		send_http_response(client, "200 OK", "application/json", stats)
		
	elif "GET /test" in request:
		var test_result = logger.test_system() if logger else false
		# Исправлено: преобразуем Dictionary в String
		var test_response = JSON.stringify({"system_test": test_result})
		send_http_response(client, "200 OK", "application/json", test_response)
		
	else:
		# Для всех остальных запросов возвращаем 404
		send_http_response(client, "404 Not Found", "text/plain", "Endpoint not found")

func send_http_response(client: StreamPeerTCP, status: String, content_type: String, body: String):
	var response = "HTTP/1.1 {status}\r\n".format({"status": status})
	response += "Content-Type: {type}; charset=utf-8\r\n".format({"type": content_type})
	response += "Content-Length: {length}\r\n".format({"length": body.to_utf8_buffer().size()})
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Connection: close\r\n\r\n"
	response += body
	
	client.put_data(response.to_utf8_buffer())

func toggle_pause_from_server():
	if pause_menu and pause_menu.has_method("toggle_pause_remote"):
		pause_menu.toggle_pause_remote()
		print("Пауза активирована через сервер")
	else:
		push_warning("Нода паузы не найдена или метод недоступен")

# Функции для работы с логами
func get_all_logs_json() -> String:
	if logger and logger.has_method("get_available_sessions"):
		var sessions = logger.get_available_sessions()
		var all_data = []
		for session_id in sessions:
			var session_data = logger.load_session(session_id)
			if not session_data.is_empty():
				all_data.append(session_data)
		return JSON.stringify(all_data, "\t")
	return "[]"

func get_all_logs_csv() -> String:
	if logger and logger.has_method("export_sessions_to_csv"):
		var csv_path = logger.export_sessions_to_csv()
		if FileAccess.file_exists(csv_path):
			var file = FileAccess.open(csv_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				return content
	return "session_id,patient_id,module,pre_sud,post_sud,sud_change,duration,timestamp\n"

func get_sessions_list() -> String:
	if logger and logger.has_method("get_available_sessions"):
		var sessions = logger.get_available_sessions()
		return JSON.stringify(sessions)
	return "[]"

func get_session_data(session_id: String) -> String:
	if logger and logger.has_method("load_session"):
		var session_data = logger.load_session(session_id)
		return JSON.stringify(session_data, "\t")
	return "{}"

func get_session_stats() -> String:
	if logger and logger.has_method("get_available_sessions"):
		var sessions = logger.get_available_sessions()
		var stats = {
			"total_sessions": sessions.size(),
			"sessions_today": get_sessions_today_count(),
			"average_sud_reduction": calculate_average_sud_reduction()
		}
		# Исправлено: преобразуем Dictionary в String
		return JSON.stringify(stats)
	return "{}"

func extract_session_id(request: String) -> String:
	var regex = RegEx.new()
	regex.compile("GET /session/([^\\s]+)")
	var result = regex.search(request)
	if result:
		return result.get_string(1)
	return ""

func get_sessions_today_count() -> int:
	if not logger:
		return 0
	
	var today = Time.get_date_string_from_system()
	var sessions = logger.get_available_sessions()
	var count = 0
	
	for session_id in sessions:
		if today in session_id:
			count += 1
	
	return count

func calculate_average_sud_reduction() -> float:
	if not logger:
		return 0.0
	
	var sessions = logger.get_available_sessions()
	var total_reduction = 0.0
	var count = 0
	
	for session_id in sessions:
		var session = logger.load_session(session_id)
		for module_name in session.get("sud_ratings", {}):
			var sud = session["sud_ratings"][module_name]
			if sud.has("pre_sud") and sud.has("post_sud") and sud["pre_sud"] > 0 and sud["post_sud"] >= 0:
				total_reduction += sud["pre_sud"] - sud["post_sud"]
				count += 1
	
	return total_reduction / count if count > 0 else 0.0
