extends CanvasLayer

# --- UI Переменные ---
@export_group("UI Panels")
@export var main_menu_panel: Control
@export var more_menu_panel: Control
@export var sud_panel: Control  # Сюда перетащите SettingsEMDR

var current_panel: Control

# --- Переменные SUD ---
var sud_slider: Slider
var sud_counter_label: Label
var sud_confirm_btn: BaseButton

# --- Переменные состояния ---
var is_paused = false
var dark_screen: ColorRect

# --- TCP Server Переменные ---
var _server: TCPServer
var _port = 9080
var chat_label 
var chat_timer: Timer 

func _ready() -> void:
	# Чтобы работало на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_to_group("pause_menu")
	add_to_group("ui_manager")
	
	create_dark_screen()
	
	# Подключаем кнопки
	check_and_connect_panels()
	
	# Скрываем все меню при старте игры
	hide_all_panels()
	dark_screen.hide()
	
	# Сервер
	_server = TCPServer.new()
	if _server.listen(_port) != OK:
		push_error("Не удалось запустить сервер!")
	else:
		print("Сервер запущен на порту ", _port)
	
	# Чат
	call_deferred("find_chat_label")
	chat_timer = Timer.new()
	chat_timer.wait_time = 3.0
	chat_timer.one_shot = true
	chat_timer.timeout.connect(_on_chat_timer_timeout)
	add_child(chat_timer)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func _process(_delta):
	if _server.is_connection_available():
		handle_tcp_connection()

# --- ЛОГИКА ПАУЗЫ ---

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		# --- ПАУЗА ВКЛЮЧЕНА ---
		print("Пауза: Открываем SUD меню")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		dark_screen.show()
		
		# При паузе всегда открываем SUD первым
		if sud_panel:
			if sud_slider: sud_slider.value = 0 # Сброс значения
			switch_to_panel(sud_panel)
		else:
			push_error("SUD Panel не назначена! Пытаюсь открыть главное меню.")
			if main_menu_panel: switch_to_panel(main_menu_panel)
			
	else:
		# --- ИГРА ВОЗОБНОВЛЕНА ---
		print("Пауза снята")
		hide_all_panels()
		dark_screen.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- УПРАВЛЕНИЕ ПАНЕЛЯМИ ---

func create_dark_screen():
	dark_screen = ColorRect.new()
	dark_screen.color = Color(0, 0, 0, 0.8)
	dark_screen.size = get_viewport().get_visible_rect().size
	dark_screen.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(dark_screen)
	move_child(dark_screen, 0)

func check_and_connect_panels():
	# Проверяем назначения
	if not main_menu_panel: push_error("ОШИБКА: MainMenuPanel не назначена в Инспекторе!")
	if not more_menu_panel: push_error("ОШИБКА: MoreMenuPanel не назначена в Инспекторе!")
	if not sud_panel: push_error("ОШИБКА: SUD Panel (SettingsEMDR) не назначена в Инспекторе!")
	
	connect_buttons()
	connect_sud_elements()

func hide_all_panels():
	if main_menu_panel: main_menu_panel.hide()
	if more_menu_panel: more_menu_panel.hide()
	if sud_panel: sud_panel.hide()
	current_panel = null

func switch_to_panel(panel: Control):
	print("Переключение на панель: ", panel.name if panel else "NULL")
	
	if not panel:
		push_error("Попытка переключиться на пустую панель!")
		return
	
	# Скрываем текущую, если она есть
	if current_panel:
		current_panel.hide()
	
	# Показываем новую
	panel.show()
	current_panel = panel

# --- ПОДКЛЮЧЕНИЕ КНОПОК ---

func connect_buttons():
	if main_menu_panel:
		var menu_btn = main_menu_panel.get_node_or_null("MenuButton")
		if menu_btn and not menu_btn.pressed.is_connected(switch_to_more_menu):
			menu_btn.pressed.connect(switch_to_more_menu)
			
		var resume_btn = main_menu_panel.get_node_or_null("ResumeButton")
		if resume_btn and not resume_btn.pressed.is_connected(toggle_pause):
			resume_btn.pressed.connect(toggle_pause)
	
	if more_menu_panel:
		var close_btn = more_menu_panel.get_node_or_null("MenuCloseButton")
		if close_btn and not close_btn.pressed.is_connected(switch_to_main_menu):
			close_btn.pressed.connect(switch_to_main_menu)
		var exit_btn = more_menu_panel.get_node_or_null("FastExitButton")
		if exit_btn and not exit_btn.pressed.is_connected(exit_application):
			exit_btn.pressed.connect(exit_application)
		var emdr_btn = more_menu_panel.get_node_or_null("EMDRButton")
		if emdr_btn and not emdr_btn.pressed.is_connected(open_emdr_mode):
			emdr_btn.pressed.connect(open_emdr_mode)
		var safe_btn = more_menu_panel.get_node_or_null("SafePlaceButton")
		if safe_btn and not safe_btn.pressed.is_connected(open_safe_place):
			safe_btn.pressed.connect(open_safe_place)

func connect_sud_elements():
	if not sud_panel: return
	
	# Ссылки согласно вашим скриншотам
	sud_slider = sud_panel.get_node_or_null("Pool/Slider")
	sud_confirm_btn = sud_panel.get_node_or_null("TextureButton")
	sud_counter_label = sud_panel.get_node_or_null("MarginContainer/Counter")
	
	if sud_slider:
		if not sud_slider.value_changed.is_connected(_on_sud_slider_changed):
			sud_slider.value_changed.connect(_on_sud_slider_changed)
	else:
		push_error("Не найден Slider по пути: Pool/Slider")

	if sud_confirm_btn:
		print("Кнопка подтверждения SUD найдена, подключаем сигнал...")
		if not sud_confirm_btn.pressed.is_connected(_on_sud_confirmed):
			sud_confirm_btn.pressed.connect(_on_sud_confirmed)
	else:
		push_error("Не найдена TextureButton внутри SettingsEMDR!")

# --- ЛОГИКА SUD (Исправлено скрытие) ---

func _on_sud_slider_changed(value):
	if sud_counter_label:
		sud_counter_label.text = str(int(value))

func _on_sud_confirmed():
	print("!!! Кнопка SUD нажата !!!")
	print("Значение: ", sud_slider.value if sud_slider else "N/A")
	
	# 1. ПРИНУДИТЕЛЬНО скрываем SUD панель
	if sud_panel:
		print("Скрываю SUD Panel")
		sud_panel.hide()
	
	# 2. Проверяем, назначено ли главное меню
	if main_menu_panel:
		print("Открываю главное меню")
		switch_to_main_menu()
	else:
		push_error("ОШИБКА: Некуда переходить! MainMenuPanel не назначена.")

# --- Callbacks ---
func switch_to_main_menu(): switch_to_panel(main_menu_panel)
func switch_to_more_menu(): switch_to_panel(more_menu_panel)
func open_emdr_mode(): print("EMDR Mode")
func open_safe_place(): print("Safe Place")
func exit_application(): get_tree().quit()

# --- TCP SERVER ---
func handle_tcp_connection():
	var client: StreamPeerTCP = _server.take_connection()
	var request = client.get_utf8_string(client.get_available_bytes())
	if request:
		var lines = request.split("\r\n")
		var parts = lines[0].split(" ") if lines.size() > 0 else []
		var path = parts[1] if parts.size() > 1 else ""
		if parts[0] == "OPTIONS": send_response(client, "", true); return
		if "button_pressed" in path: call_deferred("toggle_pause"); send_response(client, "Pause toggled")
		elif "chat_message" in path:
			var msg = request.split("\r\n\r\n")
			if msg.size() > 1: call_deferred("show_chat_message", msg[1]); send_response(client, "Message sent")
			else: send_response(client, "No msg", false, 400)

func send_response(client, body, is_cors=false, code=200):
	var h = "HTTP/1.1 " + ("200 OK" if code==200 else "400 Bad Req") + "\r\nAccess-Control-Allow-Origin: *\r\n"
	if is_cors: h += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nContent-Length: 0\r\n\r\n"
	else: h += "Content-Type: text/plain\r\nContent-Length: " + str(body.length()) + "\r\n\r\n" + body
	client.put_data(h.to_utf8_buffer())

func find_chat_label():
	chat_label = get_node_or_null("../Player/XRCamera3D/ChatUI/ChatLabel")
	if not chat_label: chat_label = find_node_by_name(get_tree().root, "ChatLabel")
	if not chat_label: chat_label = get_tree().get_first_node_in_group("chat_label")
	if chat_label: chat_label.visible = false

func find_node_by_name(root, name):
	if root.name == name: return root
	for c in root.get_children():
		var r = find_node_by_name(c, name)
		if r: return r
	return null

func show_chat_message(msg):
	if chat_label: chat_label.text = "Сообщение: " + msg; chat_label.visible = true; chat_timer.start()
	else: find_chat_label(); if chat_label: show_chat_message(msg)

func _on_chat_timer_timeout(): if chat_label: chat_label.visible = false
