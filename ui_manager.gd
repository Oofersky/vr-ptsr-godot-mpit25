extends CanvasLayer

# --- UI Переменные (Назначить в Инспекторе) ---
@export_group("UI Panels")
@export var main_menu_panel: Control       # Главное меню
@export var more_menu_panel: Control       # Меню "Еще"
@export var sud_panel: Control             # Панель SUD (ползунок)
@export var emdr_settings_panel: Control   # Настройки EMDR
@export var ball_run_panel: Control        # BallRun (с анимацией)

@export_group("Scenes")
@export_file("*.tscn") var safe_place_scene: String

var current_panel: Control

# --- Переменные SUD ---
var sud_slider: Slider
var sud_counter_label: Label
var sud_confirm_btn: BaseButton

# --- Переменные СУБТИТРОВ (Создаются кодом) ---
var subtitle_container: PanelContainer
var subtitle_label: Label
var subtitle_timer: Timer 

# --- Переменные состояния ---
var is_paused = false
var dark_screen: ColorRect

# --- TCP Server ---
var _server: TCPServer
var _port = 9080

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	add_to_group("ui_manager")
	
	# 1. Создаем визуальные элементы
	create_dark_screen()
	create_subtitle_ui() # <--- Создаем интерфейс чата/субтитров
	
	# 2. Подключаем меню
	check_and_connect_panels()
	hide_all_panels()
	dark_screen.hide()
	
	# 3. Сервер
	_server = TCPServer.new()
	if _server.listen(_port) == OK: print("Сервер запущен на порту ", _port)
	
	# 4. Таймер для субтитров
	subtitle_timer = Timer.new()
	subtitle_timer.wait_time = 5.0 # Сообщение висит 5 секунд
	subtitle_timer.one_shot = true
	subtitle_timer.timeout.connect(_on_subtitle_timeout)
	add_child(subtitle_timer)

func _input(event):
	if event.is_echo(): return
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func _process(_delta):
	if _server.is_connection_available(): handle_tcp_connection()

# --- СИСТЕМА СУБТИТРОВ (НОВАЯ) ---

func create_subtitle_ui():
	# 1. Контейнер (Фон)
	subtitle_container = PanelContainer.new()
	# Настройка стиля фона (полупрозрачный черный, скругленный)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	subtitle_container.add_theme_stylebox_override("panel", style)
	
	# Позиционирование (Внизу по центру)
	subtitle_container.anchor_left = 0.5
	subtitle_container.anchor_top = 0.85 # 85% высоты экрана
	subtitle_container.anchor_right = 0.5
	subtitle_container.anchor_bottom = 0.85
	subtitle_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitle_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Максимальная ширина субтитров
	subtitle_container.custom_minimum_size.x = 600
	
	# 2. Текст (Label)
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Настройка шрифта (размер)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Собираем
	subtitle_container.add_child(subtitle_label)
	add_child(subtitle_container)
	
	# Скрываем по умолчанию
	subtitle_container.hide()
	subtitle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE # Чтобы сквозь них можно было кликать

func show_chat_message(msg: String):
	if subtitle_label and subtitle_container:
		subtitle_label.text = msg
		subtitle_container.show()
		
		# Анимация появления (опционально)
		var tween = create_tween()
		subtitle_container.modulate.a = 0.0
		tween.tween_property(subtitle_container, "modulate:a", 1.0, 0.3)
		
		# Перезапуск таймера
		subtitle_timer.start()

func _on_subtitle_timeout():
	# Плавное исчезновение
	if subtitle_container:
		var tween = create_tween()
		tween.tween_property(subtitle_container, "modulate:a", 0.0, 0.5)
		tween.tween_callback(subtitle_container.hide)

# --- ЛОГИКА ПАУЗЫ ---

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		print("Пауза вкл -> SUD")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		dark_screen.show()
		
		if sud_panel:
			if sud_slider: sud_slider.value = 0
			switch_to_panel(sud_panel)
		else:
			if main_menu_panel: switch_to_panel(main_menu_panel)
	else:
		print("Пауза выкл")
		hide_all_panels()
		dark_screen.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func remote_open_emdr():
	print("Удаленная команда: Запуск EMDR")
	if not is_paused:
		toggle_pause()
	if emdr_settings_panel:
		switch_to_panel(emdr_settings_panel)

# --- УПРАВЛЕНИЕ ПАНЕЛЯМИ ---

func create_dark_screen():
	dark_screen = ColorRect.new()
	dark_screen.color = Color(0, 0, 0, 0.8)
	dark_screen.size = get_viewport().get_visible_rect().size
	dark_screen.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(dark_screen)
	move_child(dark_screen, 0)

func check_and_connect_panels():
	# Проверки (warning вместо error, чтобы игра не крашилась если что-то забыли)
	if not main_menu_panel: push_warning("MainMenuPanel не назначена")
	if not more_menu_panel: push_warning("MoreMenuPanel не назначена")
	
	connect_main_and_more_buttons()
	connect_sud_elements()
	connect_emdr_settings_elements()
	connect_ball_run_elements()

func hide_all_panels():
	if main_menu_panel: main_menu_panel.hide()
	if more_menu_panel: more_menu_panel.hide()
	if sud_panel: sud_panel.hide()
	if emdr_settings_panel: emdr_settings_panel.hide()
	if ball_run_panel: ball_run_panel.hide()
	current_panel = null

func switch_to_panel(panel: Control):
	if not panel: return
	if current_panel: current_panel.hide()
	panel.show()
	current_panel = panel

# --- ПОДКЛЮЧЕНИЕ КНОПОК ---

func connect_main_and_more_buttons():
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
		if emdr_btn and not emdr_btn.pressed.is_connected(open_emdr_settings):
			emdr_btn.pressed.connect(open_emdr_settings)
		var safe_btn = more_menu_panel.get_node_or_null("SafePlaceButton")
		if safe_btn and not safe_btn.pressed.is_connected(open_safe_place):
			safe_btn.pressed.connect(open_safe_place)

func connect_sud_elements():
	if not sud_panel: return
	sud_slider = sud_panel.get_node_or_null("Pool/Slider")
	sud_confirm_btn = sud_panel.get_node_or_null("TextureButton")
	sud_counter_label = sud_panel.get_node_or_null("MarginContainer/Counter")
	
	if sud_slider and not sud_slider.value_changed.is_connected(_on_sud_slider_changed):
		sud_slider.value_changed.connect(_on_sud_slider_changed)
	if sud_confirm_btn and not sud_confirm_btn.pressed.is_connected(_on_sud_confirmed):
		sud_confirm_btn.pressed.connect(_on_sud_confirmed)

func connect_emdr_settings_elements():
	if not emdr_settings_panel: return
	var save_btn = emdr_settings_panel.get_node_or_null("Panel2/SaveButton")
	if save_btn:
		if not save_btn.pressed.is_connected(_on_emdr_settings_save_pressed):
			save_btn.pressed.connect(_on_emdr_settings_save_pressed)

func connect_ball_run_elements():
	if not ball_run_panel: return
	var stop_btn = ball_run_panel.get_node_or_null("StonButton")
	if stop_btn:
		if not stop_btn.pressed.is_connected(_on_ball_run_stop_pressed):
			stop_btn.pressed.connect(_on_ball_run_stop_pressed)

# --- CALLBACKS ---

func _on_sud_slider_changed(value):
	if sud_counter_label: sud_counter_label.text = str(int(value))

func _on_sud_confirmed():
	if main_menu_panel: switch_to_panel(main_menu_panel)

func open_emdr_settings():
	if emdr_settings_panel: switch_to_panel(emdr_settings_panel)

func _on_emdr_settings_save_pressed():
	if ball_run_panel:
		switch_to_panel(ball_run_panel)
		var anim = ball_run_panel.get_node_or_null("Ball/AnimationPlayer")
		if anim and not anim.is_playing():
			anim.play("RESET"); anim.play("Move")
	else:
		switch_to_more_menu()

func _on_ball_run_stop_pressed():
	if more_menu_panel: switch_to_panel(more_menu_panel)

func switch_to_main_menu(): switch_to_panel(main_menu_panel)
func switch_to_more_menu(): switch_to_panel(more_menu_panel)
func open_safe_place():
	print("Opening Safe Place: VR369Sea")
	
	# 1. Обязательно снимаем с паузы перед сменой сцены!
	if is_paused:
		toggle_pause() # Эта функция у тебя уже снимает паузу и прячет меню
	
	# 2. Проверяем, указан ли путь
	if safe_place_scene != "":
		# 3. Меняем сцену
		get_tree().change_scene_to_file(safe_place_scene)
	else:
		print("ОШИБКА: Не указан путь к сцене VR369Sea в Инспекторе UIManager!")
func exit_application(): get_tree().quit()

# --- TCP SERVER ---
func handle_tcp_connection():
	var client = _server.take_connection()
	var request = client.get_utf8_string(client.get_available_bytes())
	
	if request:
		var lines = request.split("\r\n")
		var parts = lines[0].split(" ") if lines.size() > 0 else []
		var path = parts[1] if parts.size() > 1 else ""
		
		if parts[0] == "OPTIONS": 
			send_response(client, "", true)
			return
		
		if "button_pressed" in path: 
			call_deferred("toggle_pause")
			send_response(client, "Pause toggled")
		
		elif "emdr_start" in path:
			call_deferred("remote_open_emdr")
			send_response(client, "EMDR Settings Opened")
		
		elif "chat_message" in path:
			var msg = request.split("\r\n\r\n")
			if msg.size() > 1: 
				# Теперь вызываем нашу новую функцию, которая не зависит от Player
				call_deferred("show_chat_message", msg[1])
				send_response(client, "Message sent")
			else: 
				send_response(client, "No msg", false, 400)

func send_response(client, body, is_cors=false, code=200):
	var h = "HTTP/1.1 " + ("200 OK" if code==200 else "400 Bad Req") + "\r\nAccess-Control-Allow-Origin: *\r\n"
	if is_cors: h += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nContent-Length: 0\r\n\r\n"
	else: h += "Content-Type: text/plain\r\nContent-Length: " + str(body.length()) + "\r\n\r\n" + body
	client.put_data(h.to_utf8_buffer())
