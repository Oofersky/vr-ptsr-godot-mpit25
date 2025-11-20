extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	print("Кнопка 'Новый сеанс' нажата - запуск процесса инициализации")
	
	# Получаем SessionManager через корневой узел
	var session_manager = get_node("/root/SessionManagers")
	
	if session_manager.has_pending_session():
		print("Обнаружен сеанс от админки, показываем панель подтверждения")
		show_admin_session_panel(session_manager)
	else:
		print("Запускаем стандартный процесс инициализации сеанса")
		start_manual_session_flow()

func show_admin_session_panel(session_manager):
	# В случае с 2D UI, показываем панель подтверждения
	var admin_panel = get_node_or_null("../SessionStatusPanel")
	if admin_panel:
		admin_panel.visible = true
		
		# Скрываем основную панель управления
		var main_panel = get_node_or_null("..")
		if main_panel:
			main_panel.visible = false
	else:
		# Если панели нет, просто запускаем сеанс
		start_session_with_admin_config(session_manager)

func start_session_with_admin_config(session_manager):
	var session_config = session_manager.get_pending_session()
	session_manager.start_session_with_config(session_config)
	
	# Переходим к терапевтической сцене
	var scene_path = "res://Scenes/TherapyModules/Exposure360Scene.tscn"
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)

func start_manual_session_flow():
	# Переходим к сцене инициализации сеанса
	var scene_path = "res://VR360Module.tscn"
	
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Сцена не найдена: " + scene_path)
