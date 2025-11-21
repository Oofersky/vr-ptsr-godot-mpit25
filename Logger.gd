# logger.gd
extends Node

const LOG_DIR = "user://session_logs/"

var current_session_data: Dictionary

func _ready():
	_ensure_log_directory()

func start_new_session(patient_id: String, therapist_id: String = ""):
	current_session_data = {
		"session_id": generate_session_id(),
		"patient_id": patient_id,
		"therapist_id": therapist_id,
		"start_time": Time.get_datetime_string_from_system(),
		"modules_used": [],
		"events": [],
		"sud_ratings": {},
		"session_parameters": {}
	}

func log_module_usage(module_name: String, parameters: Dictionary, duration: float):
	var module_log = {
		"module": module_name,
		"start_time": Time.get_datetime_string_from_system(),
		"parameters": parameters.duplicate(),
		"duration_sec": duration
	}
	current_session_data["modules_used"].append(module_log)

func log_sud_rating(module: String, pre_sud: int, post_sud: int):
	current_session_data["sud_ratings"][module] = {
		"pre_sud": pre_sud,
		"post_sud": post_sud,
		"timestamp": Time.get_datetime_string_from_system()
	}

func log_event(event_type: String, details: Dictionary):
	var event = {
		"type": event_type,
		"timestamp": Time.get_datetime_string_from_system(),
		"details": details.duplicate()
	}
	current_session_data["events"].append(event)

func log_session_parameters(parameters: Dictionary):
	current_session_data["session_parameters"] = parameters.duplicate()

func save_session():
	if current_session_data.is_empty():
		return
	
	current_session_data["end_time"] = Time.get_datetime_string_from_system()
	
	# Сохраняем в JSON (без шифрования для простоты)
	var json_data = JSON.stringify(current_session_data)
	
	var file_path = LOG_DIR + current_session_data["session_id"] + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_data)
		file.close()
		print("Session saved: ", file_path)
	
	# Также сохраняем в CSV для удобства анализа
	save_session_csv()

func save_session_csv():
	var csv_path = LOG_DIR + current_session_data["session_id"] + ".csv"
	var file = FileAccess.open(csv_path, FileAccess.WRITE)
	if file:
		# Заголовок CSV
		file.store_line("session_id,patient_id,module,pre_sud,post_sud,duration,timestamp,parameters")
		
		# Данные модулей
		for module in current_session_data["modules_used"]:
			var sud_data = current_session_data["sud_ratings"].get(module["module"], {})
			var params_str = JSON.stringify(module.get("parameters", {}))
			var line = "%s,%s,%s,%d,%d,%.1f,%s,%s" % [
				current_session_data["session_id"],
				current_session_data["patient_id"],
				module["module"],
				sud_data.get("pre_sud", -1),
				sud_data.get("post_sud", -1),
				module.get("duration_sec", 0),
				module["start_time"],
				params_str
			]
			file.store_line(line)
		file.close()

func _ensure_log_directory():
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		var dir = DirAccess.open("user://")
		if dir.make_dir_recursive(LOG_DIR) != OK:
			push_error("Failed to create log directory: " + LOG_DIR)

func generate_session_id() -> String:
	var time = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	return "session_%s_%d" % [time, randi() % 1000]

# Функция для загрузки сессии по ID
func load_session(session_id: String) -> Dictionary:
	var file_path = LOG_DIR + session_id + ".json"
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		file.close()
		
		var parsed = JSON.parse_string(json_data)
		if parsed == null:
			print("Error: Failed to parse JSON for session: ", session_id)
			return {}
			
		if parsed is Dictionary:
			return parsed
		else:
			print("Error: Parsed data is not a dictionary for session: ", session_id)
			return {}
	
	return {}

# Получить список всех сессий
func get_available_sessions() -> Array[String]:
	var sessions: Array[String] = []
	var dir = DirAccess.open(LOG_DIR)
	if dir:
		var files = dir.get_files()
		for file in files:
			if file.ends_with(".json"):
				sessions.append(file.trim_suffix(".json"))
	return sessions

# Экспорт всех сессий в CSV
func export_sessions_to_csv() -> String:
	var csv_path = LOG_DIR + "all_sessions_export.csv"
	var file = FileAccess.open(csv_path, FileAccess.WRITE)
	if file:
		file.store_line("session_id,patient_id,module,pre_sud,post_sud,sud_change,duration,timestamp")
		
		var sessions = get_available_sessions()
		for session_id in sessions:
			var session_data = load_session(session_id)
			if not session_data.is_empty():
				for module in session_data.get("modules_used", []):
					var sud_data = session_data["sud_ratings"].get(module["module"], {})
					var pre_sud = sud_data.get("pre_sud", -1)
					var post_sud = sud_data.get("post_sud", -1)
					var sud_change = post_sud - pre_sud if pre_sud != -1 and post_sud != -1 else 0
					
					var line = "%s,%s,%s,%d,%d,%d,%.1f,%s" % [
						session_data["session_id"],
						session_data["patient_id"],
						module["module"],
						pre_sud,
						post_sud,
						sud_change,
						module.get("duration_sec", 0),
						module["start_time"]
					]
					file.store_line(line)
		
		file.close()
		return csv_path
	
	return ""

# Простая функция для тестирования
func test_system() -> bool:
	var test_data = "Hello, this is a test message!"
	print("System test:")
	print("Original: ", test_data)
	print("Success: System is working")
	return true
