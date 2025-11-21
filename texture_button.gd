extends CanvasLayer

var paused_nodes = {}
var is_paused = false
var dark_screen: ColorRect
var sud_instance: Node = null  # Для хранения экземпляра сцены SUD

# TCP-сервер переменные
var _server: TCPServer
var _port = 9080
var chat_label  # Ссылка на Label для отображения сообщений у игрока
var chat_timer: Timer  # Таймер для скрытия сообщения

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	create_dark_screen()
	
	# Инициализация TCP-сервера
	_server = TCPServer.new()
	if _server.listen(_port) != OK:
		push_error("Не удалось запустить сервер!")
	else:
		print("Сервер запущен на порту ", _port)
	
	# Ищем Label у игрока для отображения сообщений
	call_deferred("find_chat_label")
	
	# Создаем таймер заранее
	chat_timer = Timer.new()
	chat_timer.wait_time = 3.0
	chat_timer.one_shot = true
	chat_timer.timeout.connect(_on_chat_timer_timeout)
	add_child(chat_timer)

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC
		toggle_pause()

func _process(_delta):
	# Обработка TCP-соединений
	if _server.is_connection_available():
		var client: StreamPeerTCP = _server.take_connection()
		var request = client.get_utf8_string(client.get_available_bytes())
		
		if request:
			print("Получен запрос: ", request)
			
			# Разбираем HTTP запрос
			var lines = request.split("\r\n")
			var first_line = lines[0] if lines.size() > 0 else ""
			var parts = first_line.split(" ")
			var method = parts[0] if parts.size() > 0 else ""
			var path = parts[1] if parts.size() > 1 else ""
			
			# Обработка preflight OPTIONS запроса для CORS
			if method == "OPTIONS":
				print("Обработка CORS preflight запроса")
				var response = "HTTP/1.1 200 OK\r\n"
				response += "Access-Control-Allow-Origin: *\r\n"
				response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
				response += "Access-Control-Allow-Headers: Content-Type\r\n"
				response += "Content-Length: 0\r\n"
				response += "\r\n"
				client.put_data(response.to_utf8_buffer())
				return
			
			# Обработка паузы
			if "button_pressed" in path:
				print("Кнопка нажата! Активация паузы через сервер")
				toggle_pause()
				var response = "HTTP/1.1 200 OK\r\n"
				response += "Access-Control-Allow-Origin: *\r\n"
				response += "Content-Type: text/plain\r\n"
				response += "Content-Length: 13\r\n"
				response += "\r\n"
				response += "Pause toggled"
				client.put_data(response.to_utf8_buffer())
			
			# Обработка сообщений чата
			elif "chat_message" in path:
				var message_parts = request.split("\r\n\r\n")
				if message_parts.size() > 1:
					var message = message_parts[1]
					print("Получено сообщение: ", message)
					show_chat_message(message)
					var response = "HTTP/1.1 200 OK\r\n"
					response += "Access-Control-Allow-Origin: *\r\n"
					response += "Content-Type: text/plain\r\n"
					response += "Content-Length: 12\r\n"
					response += "\r\n"
					response += "Message sent"
					client.put_data(response.to_utf8_buffer())
				else:
					push_warning("Не удалось извлечь сообщение из запроса")
					var response = "HTTP/1.1 400 Bad Request\r\n"
					response += "Access-Control-Allow-Origin: *\r\n"
					response += "Content-Type: text/plain\r\n"
					response += "Content-Length: 11\r\n"
					response += "\r\n"
					response += "No message"
					client.put_data(response.to_utf8_buffer())

func toggle_pause():
	if is_paused:
		hide_dark_screen()
		resume_world()
		# Удаляем сцену SUD при снятии паузы
		if sud_instance:
			sud_instance.queue_free()
			sud_instance = null
		# Скрываем и блокируем мышку при возобновлении игры
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		pause_world()
		show_dark_screen()
		# Загружаем и показываем сцену SUD при паузе
		load_sud_scene()
		# Показываем и разблокируем мышку при паузе
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	is_paused = !is_paused
	print("Пауза ", "включена" if is_paused else "выключена")

func load_sud_scene():
	# Загружаем и создаем экземпляр сцены SUD
	var sud_scene = load("res://SUD.tscn")
	if sud_scene:
		sud_instance = sud_scene.instantiate()
		add_child(sud_instance)
		print("Сцена SUD загружена и добавлена")
	else:
		push_error("Не удалось загрузить сцену SUD.tscn")

func create_dark_screen():
	# Создаем затемняющий фон
	dark_screen = ColorRect.new()
	dark_screen.color = Color(0, 0, 0, 0)  # Начальная прозрачность
	dark_screen.size = get_viewport().get_visible_rect().size
	dark_screen.anchor_left = 0
	dark_screen.anchor_top = 0
	dark_screen.anchor_right = 1
	dark_screen.anchor_bottom = 1
	dark_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Не блокирует клики
	add_child(dark_screen)
	
	# Убедимся, что затемнение позади меню паузы
	dark_screen.z_index = -1

func show_dark_screen():
	# Плавное появление затемнения
	var tween = create_tween()
	tween.tween_property(dark_screen, "color:a", 0.5, 0.3)  # Полупрозрачный черный
	tween.set_ease(Tween.EASE_OUT)
	print("Экран затемнен")

func hide_dark_screen():
	# Плавное исчезновение затемнения
	var tween = create_tween()
	tween.tween_property(dark_screen, "color:a", 0.0, 0.3)  # Полная прозрачность
	tween.set_ease(Tween.EASE_OUT)
	print("Экран восстановлен")

func pause_world():
	paused_nodes.clear()
	var game_root = get_tree().current_scene
	if game_root:
		pause_node_recursive(game_root)

func resume_world():
	for node in paused_nodes.keys():
		if !is_instance_valid(node):
			continue

		var state = paused_nodes[node]

		if state.get("process", false):
			node.set_process(true)
		if state.get("physics", false):
			node.set_physics_process(true)
		if state.get("video", false):
			if node is VideoStreamPlayer:
				node.paused = false

	paused_nodes.clear()

func pause_node_recursive(node):
	if node == self or node.is_in_group("pause_menu"):
		return

	var state = {}

	if node.has_method("set_process") and node.is_processing():
		node.set_process(false)
		state["process"] = true

	if node.has_method("set_physics_process") and node.is_physics_processing():
		node.set_physics_process(false)
		state["physics"] = true

	if node is VideoStreamPlayer:
		if not node.paused:
			node.paused = true
			state["video"] = true

	if !state.is_empty():
		paused_nodes[node] = state

	for child in node.get_children():
		pause_node_recursive(child)

# TCP-сервер функции
func find_chat_label():
	# Пытаемся найти ChatLabel разными способами
	print("Поиск ChatLabel...")
	
	# Способ 1: По указанному пути
	chat_label = get_node_or_null("../Player/XRCamera3D/ChatUI/ChatLabel")
	if chat_label:
		print("Chat label найден по пути: ../Player/XRCamera3D/ChatUI/ChatLabel")
		print("Тип ChatLabel: ", chat_label.get_class())
		chat_label.visible = false
		return
	
	# Способ 2: Поиск по всему дереву сцены
	chat_label = find_node_by_name(get_tree().root, "ChatLabel")
	if chat_label:
		print("Chat label найден по имени во всем дереве сцены")
		print("Путь: ", chat_label.get_path())
		print("Тип ChatLabel: ", chat_label.get_class())
		chat_label.visible = false
		return
	
	# Способ 3: Поиск по группе
	chat_label = get_tree().get_first_node_in_group("chat_label")
	if chat_label:
		print("Chat label найден по группе 'chat_label'")
		print("Тип ChatLabel: ", chat_label.get_class())
		chat_label.visible = false
		return
	
	push_warning("Chat label не найден!")

# Вспомогательная функция для поиска узла по имени во всем дереве
func find_node_by_name(root, node_name):
	if root.name == node_name:
		return root
	
	for child in root.get_children():
		var result = find_node_by_name(child, node_name)
		if result:
			return result
	
	return null

func show_chat_message(message: String):
	if chat_label:
		print("Устанавливаем текст: ", message)
		print("Текущий текст ChatLabel: ", chat_label.text)
		print("ChatLabel видимый: ", chat_label.visible)
		
		# Устанавливаем текст сообщения
		chat_label.text = "Сообщение: " + message
		chat_label.visible = true
		
		# Принудительно обновляем UI
		chat_label.queue_redraw()
		
		# Перезапускаем таймер
		chat_timer.start()
		
		print("Новый текст ChatLabel: ", chat_label.text)
		print("ChatLabel теперь видимый: ", chat_label.visible)
	else:
		push_warning("Chat label не доступен для отображения сообщения")
		# Попробуем найти label снова
		find_chat_label()
		if chat_label:
			show_chat_message(message)  # Повторяем попытку

func _on_chat_timer_timeout():
	if chat_label:
		print("Скрываем сообщение")
		chat_label.visible = false
		chat_label.text = ""
		chat_label.queue_redraw()
