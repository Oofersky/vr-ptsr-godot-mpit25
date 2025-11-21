# test_data_generator.gd
extends Node

@onready var logger = $"/root/Logger"

func _ready():
	# Генерируем тестовые данные при запуске
	call_deferred("generate_test_data")

func generate_test_data():
	print("Генерация тестовых данных...")
	
	# Тест шифрования
	if logger.has_method("test_encryption"):
		logger.test_encryption()
	
	# Создаем несколько тестовых сессий
	create_test_sessions()
	
	print("Тестовые данные сгенерированы!")

func create_test_sessions():
	# Сессия 1: Успешная терапия
	var session1 = {
		"session_id": "session_20241220_143025_001",
		"patient_id": "patient_001",
		"therapist_id": "therapist_anna",
		"start_time": "2024-12-20T14:30:25",
		"end_time": "2024-12-20T15:15:30",
		"modules_used": [
			{
				"module": "exposure_360",
				"start_time": "2024-12-20T14:30:30",
				"parameters": {"intensity": 0.7, "scene": "bombardment"},
				"duration_sec": 120.5
			},
			{
				"module": "emdr", 
				"start_time": "2024-12-20T14:32:35",
				"parameters": {"frequency": 2.5, "pattern": "horizontal"},
				"duration_sec": 180.2
			},
			{
				"module": "safe_place",
				"start_time": "2024-12-20T14:35:40", 
				"parameters": {"scene": "forest", "duration": 120},
				"duration_sec": 120.0
			}
		],
		"sud_ratings": {
			"exposure_360": {"pre_sud": 8, "post_sud": 4, "timestamp": "2024-12-20T14:32:30"},
			"emdr": {"pre_sud": 4, "post_sud": 2, "timestamp": "2024-12-20T14:35:35"},
			"safe_place": {"pre_sud": 2, "post_sud": 1, "timestamp": "2024-12-20T14:37:40"}
		},
		"events": [
			{"type": "session_started", "timestamp": "2024-12-20T14:30:25", "details": {"patient_id": "patient_001"}},
			{"type": "session_ended", "timestamp": "2024-12-20T15:15:30", "details": {}}
		],
		"session_parameters": {"therapy_type": "PTSD", "intensity_level": "medium"}
	}
	
	# Сохраняем тестовую сессию
	save_test_session(session1)
	
	# Сессия 2: Экстренная остановка
	var session2 = {
		"session_id": "session_20241220_160015_002",
		"patient_id": "patient_002", 
		"therapist_id": "therapist_max",
		"start_time": "2024-12-20T16:00:15",
		"end_time": "2024-12-20T16:02:30",
		"modules_used": [
			{
				"module": "exposure_360",
				"start_time": "2024-12-20T16:00:20",
				"parameters": {"intensity": 0.9, "scene": "urban_combat"},
				"duration_sec": 45.7
			}
		],
		"sud_ratings": {
			"exposure_360": {"pre_sud": 9, "post_sud": 9, "timestamp": "2024-12-20T16:01:10"}
		},
		"events": [
			{"type": "session_started", "timestamp": "2024-12-20T16:00:15", "details": {}},
			{"type": "emergency_stop", "timestamp": "2024-12-20T16:01:15", "details": {"reason": "high_sud_escalation"}},
			{"type": "session_ended", "timestamp": "2024-12-20T16:02:30", "details": {}}
		],
		"session_parameters": {"therapy_type": "PTSD", "intensity_level": "high"}
	}
	
	save_test_session(session2)

func save_test_session(session_data: Dictionary):
	var json_data = JSON.stringify(session_data)
	var encrypted_data = logger.encrypt_string(json_data)
	
	var file_path = logger.LOG_DIR + session_data["session_id"] + ".json.enc"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_buffer(encrypted_data)
		file.close()
		print("Тестовая сессия сохранена: ", session_data["session_id"])
