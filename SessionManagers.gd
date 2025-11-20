# SessionManager.gd
extends Node

# Автозагружаемый скрипт для управления сеансами терапии
# Добавьте этот скрипт в Project Settings -> Autoload с именем "SessionManager"

class_name SessionManager

# Переменные для хранения данных
var pending_session: Dictionary = {}  # Ожидающий сеанс от админки
var current_session: Dictionary = {}   # Текущий активный сеанс
var session_history: Array = []        # История всех сеансов
var patient_profiles: Array = []       # Профили пациентов
var therapist_profiles: Array = []     # Профили терапевтов

# Сигналы
signal session_started(session_data: Dictionary)
signal session_paused(session_id: String)
signal session_ended(session_data: Dictionary)
signal pending_session_received(session_config: Dictionary)

func _ready():
	print("SessionManager initialized")
	load_profiles()
	load_session_history()

# ==================== УПРАВЛЕНИЕ СЕАНСАМИ ====================

# Проверяет, есть ли ожидающий сеанс от админки
func has_pending_session() -> bool:
	return not pending_session.is_empty()

# Возвращает конфигурацию ожидающего сеанса
func get_pending_session() -> Dictionary:
	return pending_session.duplicate()  # Возвращаем копию, чтобы избежать изменений

# Устанавливает ожидающий сеанс от админки
func set_pending_session(config: Dictionary):
	pending_session = config.duplicate()
	print("Pending session set: ", config.get("session_id", "unknown"))
	pending_session_received.emit(config)

# Очищает ожидающий сеанс
func clear_pending_session():
	pending_session = {}
	print("Pending session cleared")

# Начинает новый сеанс с конфигурацией
func start_session_with_config(config: Dictionary):
	current_session = {
		"session_id": config.get("session_id", generate_session_id()),
		"patient_id": config.get("patient_id", ""),
		"patient_name": config.get("patient_name", "Unknown Patient"),
		"therapist_id": config.get("therapist_id", ""),
		"therapist_name": config.get("therapist_name", "Unknown Therapist"),
		"scene_name": config.get("scene_name", "default"),
		"start_time": Time.get_datetime_string_from_system(),
		"end_time": "",
		"events": [],
		"sud_data": [],
		"intensity_settings": config.get("intensity_profile", {}),
		"status": "active"
	}
	
	print("Session started: ", current_session.session_id)
	session_started.emit(current_session)
	
	# Добавляем событие начала сеанса
	add_session_event("session_started", "system")

# Начинает ручной сеанс
func start_manual_session(patient_id: String, therapist_id: String, scene_name: String):
	var patient = get_patient_by_id(patient_id)
	var therapist = get_therapist_by_id(therapist_id)
	
	current_session = {
		"session_id": generate_session_id(),
		"patient_id": patient_id,
		"patient_name": patient.get("display_name", "Unknown Patient") if patient else "Unknown Patient",
		"therapist_id": therapist_id,
		"therapist_name": therapist.get("display_name", "Unknown Therapist") if therapist else "Unknown Therapist",
		"scene_name": scene_name,
		"start_time": Time.get_datetime_string_from_system(),
		"end_time": "",
		"events": [],
		"sud_data": [],
		"intensity_settings": {
			"initial_volume": 0.5,
			"initial_brightness": 0.5,
			"max_intensity": 0.8
		},
		"status": "active"
	}
	
	print("Manual session started: ", current_session.session_id)
	session_started.emit(current_session)
	add_session_event("session_started", "system")

# Завершает текущий сеанс
func end_current_session():
	if current_session.is_empty():
		return
	
	current_session.end_time = Time.get_datetime_string_from_system()
	current_session.status = "completed"
	
	add_session_event("session_ended", "system")
	
	# Сохраняем в историю
	session_history.append(current_session.duplicate())
	save_session_history()
	
	print("Session ended: ", current_session.session_id)
	session_ended.emit(current_session)
	
	current_session = {}

# ==================== УПРАВЛЕНИЕ СОБЫТИЯМИ ====================

# Добавляет событие в текущий сеанс
func add_session_event(event_type: String, module: String, data: Dictionary = {}):
	if current_session.is_empty():
		return
	
	var event = {
		"timestamp": Time.get_datetime_string_from_system(),
		"event_type": event_type,
		"module": module,
		"data": data
	}
	
	current_session.events.append(event)
	print("Event added: ", event_type, " in ", module)

# Добавляет данные SUD
func add_sud_data(pre_sud: int, post_sud: int, module: String, notes: String = ""):
	if current_session.is_empty():
		return
	
	var sud_record = {
		"timestamp": Time.get_datetime_string_from_system(),
		"pre_sud": pre_sud,
		"post_sud": post_sud,
		"module": module,
		"improvement": pre_sud - post_sud,
		"notes": notes
	}
	
	current_session.sud_data.append(sud_record)
	print("SUD data added: ", pre_sud, " -> ", post_sud, " in ", module)

# ==================== УПРАВЛЕНИЕ ПРОФИЛЯМИ ====================

# Загружает профили из файлов
func load_profiles():
	# В реальной реализации здесь будет загрузка из JSON файлов
	# Для демо создаем тестовые данные
	
	patient_profiles = [
		{
			"patient_id": "patient_001",
			"display_name": "Иван Петров",
			"trauma_type": "combat",
			"therapy_stage": 2,
			"created_date": "2024-01-01"
		},
		{
			"patient_id": "patient_002", 
			"display_name": "Алексей Сидоров",
			"trauma_type": "accident",
			"therapy_stage": 1,
			"created_date": "2024-01-02"
		}
	]
	
	therapist_profiles = [
		{
			"therapist_id": "therapist_001",
			"display_name": "Доктор Иванова",
			"specialization": "PTSD",
			"license_number": "PSY-12345"
		}
	]
	
	print("Profiles loaded: ", patient_profiles.size(), " patients, ", therapist_profiles.size(), " therapists")

# Возвращает профиль пациента по ID
func get_patient_by_id(patient_id: String) -> Dictionary:
	for patient in patient_profiles:
		if patient.patient_id == patient_id:
			return patient
	return {}

# Возвращает профиль терапевта по ID  
func get_therapist_by_id(therapist_id: String) -> Dictionary:
	for therapist in therapist_profiles:
		if therapist.therapist_id == therapist_id:
			return therapist
	return {}

# ==================== УТИЛИТЫ ====================

# Генерирует уникальный ID сеанса
func generate_session_id() -> String:
	var time = Time.get_unix_time_from_system()
	var random = randi() % 1000
	return "session_%d_%03d" % [time, random]

# Загружает историю сеансов
func load_session_history():
	# В реальной реализации - загрузка из файла
	session_history = []
	print("Session history loaded: ", session_history.size(), " sessions")

# Сохраняет историю сеансов
func save_session_history():
	# В реальной реализации - сохранение в файл
	print("Session history saved: ", session_history.size(), " sessions")

# Возвращает статистику по сеансам
func get_session_statistics() -> Dictionary:
	return {
		"total_sessions": session_history.size(),
		"completed_sessions": session_history.filter(func(s): return s.status == "completed").size(),
		"total_therapy_time": calculate_total_therapy_time(),
		"average_sud_improvement": calculate_average_sud_improvement()
	}

# ==================== ПРИВАТНЫЕ МЕТОДЫ ====================

func calculate_total_therapy_time() -> int:
	var total = 0
	for session in session_history:
		if session.has("start_time") and session.has("end_time"):
			# Здесь должна быть логика расчета разницы времени
			pass
	return total

func calculate_average_sud_improvement() -> float:
	var total_improvement = 0
	var count = 0
	
	for session in session_history:
		for sud in session.get("sud_data", []):
			total_improvement += sud.get("improvement", 0)
			count += 1
	
	return total_improvement / count if count > 0 else 0.0
