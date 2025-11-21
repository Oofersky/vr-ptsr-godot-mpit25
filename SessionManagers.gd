# session_manager.gd
extends Node

@onready var logger = $Logger

var current_module_start_time: float = 0.0
var current_module_name: String = ""
var current_patient_id: String = ""

func start_therapy_session(patient_id: String, therapist_id: String = ""):
	current_patient_id = patient_id
	logger.start_new_session(patient_id, therapist_id)
	logger.log_event("session_started", {"patient_id": patient_id})
	print("Started therapy session for patient: ", patient_id)

func start_module(module_name: String, parameters: Dictionary = {}):
	if current_module_name != "":
		end_current_module()
	
	current_module_name = module_name
	current_module_start_time = Time.get_ticks_msec()
	
	logger.log_event("module_started", {
		"module": module_name,
		"parameters": parameters
	})
	
	# Записываем Pre-SUD если доступен
	if parameters.has("pre_sud"):
		logger.log_sud_rating(module_name, parameters["pre_sud"], -1)

func end_current_module():
	if current_module_name != "":
		var duration = (Time.get_ticks_msec() - current_module_start_time) / 1000.0
		logger.log_module_usage(current_module_name, {}, duration)
		current_module_name = ""

func record_sud_rating(pre_sud: int, post_sud: int, module: String = ""):
	var target_module = module if module != "" else current_module_name
	if target_module != "":
		logger.log_sud_rating(target_module, pre_sud, post_sud)
		print("Recorded SUD for %s: Pre=%d, Post=%d" % [target_module, pre_sud, post_sud])

func log_pause_event(reason: String = ""):
	logger.log_event("session_paused", {"reason": reason})
	print("Session paused: ", reason)

func log_emergency_stop():
	logger.log_event("emergency_stop", {})
	end_current_session()
	print("EMERGENCY STOP: Session terminated")

func log_intensity_change(parameter: String, old_value: float, new_value: float):
	logger.log_event("intensity_changed", {
		"parameter": parameter,
		"old_value": old_value,
		"new_value": new_value
	})

func log_event(event_type: String, details: Dictionary):
	logger.log_event(event_type, details)

func end_current_session():
	end_current_module()
	logger.log_event("session_ended", {})
	logger.save_session()
	print("Session completed and saved for patient: ", current_patient_id)

# Экспорт данных в CSV для анализа
func export_sessions_to_csv() -> String:
	var all_data = "session_id,patient_id,module,pre_sud,post_sud,sud_change,duration,timestamp\n"
	var sessions = logger.get_available_sessions()
	
	for session_id in sessions:
		var session = logger.load_session(session_id)
		if not session.is_empty():
			for module in session.get("modules_used", []):
				var sud_data = session["sud_ratings"].get(module["module"], {})
				var pre_sud = sud_data.get("pre_sud", -1)
				var post_sud = sud_data.get("post_sud", -1)
				var sud_change = post_sud - pre_sud if pre_sud != -1 and post_sud != -1 else 0
				
				var line = "%s,%s,%s,%d,%d,%d,%.1f,%s\n" % [
					session["session_id"],
					session["patient_id"],
					module["module"],
					pre_sud,
					post_sud,
					sud_change,
					module.get("duration_sec", 0),
					module["start_time"]
				]
				all_data += line
	
	var export_path = logger.LOG_DIR + "all_sessions_export.csv"
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		file.store_string(all_data)
		file.close()
		return export_path
	
	return ""
