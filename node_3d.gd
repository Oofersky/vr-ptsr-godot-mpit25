extends Node

var _server: TCPServer
var _port = 9080
var pause_menu  # Ссылка на ноду паузы
var chat_label  # Ссылка на Label для отображения сообщений у игрока
var chat_timer: Timer  # Таймер для скрытия сообщения

func _ready():
	_server = TCPServer.new()
	if _server.listen(_port) != OK:
		push_error("Не удалось запустить сервер!")
	else:
		print("Сервер запущен на порту ", _port)
	
	# Ищем ноду паузы в дереве сцены
	pause_menu = get_tree().get_first_node_in_group("pause_menu")
	
	# Ищем Label у игрока для отображения сообщений
	call_deferred("find_chat_label")
	
	# Создаем таймер заранее
	chat_timer = Timer.new()
	chat_timer.wait_time = 3.0
	chat_timer.one_shot = true
	chat_timer.timeout.connect(_on_chat_timer_timeout)
	add_child(chat_timer)

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

func _process(_delta):
	if _server.is_connection_available():
		var client: StreamPeerTCP = _server.take_connection()
		var request = client.get_utf8_string(client.get_available_bytes())
		
		if request:
			print("Получен запрос: ", request)  # Отладочная информация
			
			# Обработка паузы
			if "button_pressed" in request:
				print("Кнопка нажата! Активация паузы через сервер")
				toggle_pause_from_server()
				client.put_data("HTTP/1.1 200 OK\r\n\r\n".to_utf8_buffer())
			
			# Обработка сообщений чата
			elif "chat_message" in request:
				# Извлекаем тело сообщения (после двойного перевода строки)
				var parts = request.split("\r\n\r\n")
				if parts.size() > 1:
					var message = parts[1]
					print("Получено сообщение: ", message)
					
					# Показываем сообщение у игрока
					show_chat_message(message)
					
					client.put_data("HTTP/1.1 200 OK\r\n\r\n".to_utf8_buffer())
				else:
					push_warning("Не удалось извлечь сообщение из запроса")

func toggle_pause_from_server():
	if pause_menu and pause_menu.has_method("toggle_pause_remote"):
		pause_menu.toggle_pause_remote()
	else:
		push_warning("Нода паузы не найдена или метод недоступен")

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
