# PauseManager.gd
extends Node

signal game_paused
signal game_resumed

var is_paused: bool = false
var pause_menu_instance: Node = null
var dark_panel: ColorRect = null
var original_time_scale: float = 1.0

# Кнопки для паузы
const VR_PAUSE_BUTTON = JOY_BUTTON_START  # Menu button на левом контроллере Oculus
const KEYBOARD_PAUSE_BUTTON = KEY_ESCAPE  # Клавиша ESC на клавиатуре

func _ready():
	# Обрабатываем ввод даже когда игра на паузе
	set_process_unhandled_input(true)
	print("PauseManager initialized - VR (Menu button) or Keyboard (ESC) to pause")

func _unhandled_input(event):
	# Обрабатываем нажатие кнопки паузы на VR контроллере
	if event is InputEventJoypadButton:
		if event.button_index == VR_PAUSE_BUTTON and event.pressed:
			toggle_pause()
	
	# Обрабатываем нажатие ESC на клавиатуре
	if event is InputEventKey:
		if event.keycode == KEYBOARD_PAUSE_BUTTON and event.pressed and not event.is_echo():
			toggle_pause()

func toggle_pause():
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if is_paused:
		return
	
	# Проверяем, что мы не в главном меню
	var current_scene = get_tree().current_scene
	if current_scene and (current_scene.name == "MainMenuScene" or current_scene.name == "SessionInitScene"):
		print("Cannot pause in main menu or session init")
		return
	
	print("Pausing game...")
	is_paused = true
	
	# Сохраняем оригинальную скорость времени
	original_time_scale = Engine.time_scale
	
	# Замедляем время (но не останавливаем полностью для плавности VR)
	Engine.time_scale = 0.1
	
	# Создаем затемнение
	create_dark_overlay()
	
	# Показываем меню паузы
	show_pause_menu()
	
	# Приглушаем звуки игры (но не UI звуки)
	mute_game_audio()
	
	game_paused.emit()

func resume_game():
	if not is_paused:
		return
	
	print("Resuming game...")
	is_paused = false
	
	# Восстанавливаем время
	Engine.time_scale = original_time_scale
	
	# Убираем затемнение
	remove_dark_overlay()
	
	# Скрываем меню паузы
	hide_pause_menu()
	
	# Восстанавливаем звук
	unmute_game_audio()
	
	game_resumed.emit()

func create_dark_overlay():
	# Создаем CanvasLayer для затемнения поверх всего
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Высокий слой
	canvas_layer.name = "PauseOverlay"
	
	# Создаем темную панель
	dark_panel = ColorRect.new()
	dark_panel.color = Color(0, 0, 0, 0.7)  # Полупрозрачный черный
	dark_panel.size = get_viewport().get_visible_rect().size
	dark_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	canvas_layer.add_child(dark_panel)
	get_tree().root.add_child(canvas_layer)
	
	# Анимация появления
	var tween = create_tween()
	dark_panel.modulate.a = 0
	tween.tween_property(dark_panel, "modulate:a", 0.7, 0.3)

func remove_dark_overlay():
	if dark_panel and is_instance_valid(dark_panel):
		var tween = create_tween()
		tween.tween_property(dark_panel, "modulate:a", 0, 0.3)
		tween.tween_callback(func(): 
			if dark_panel and dark_panel.get_parent():
				dark_panel.get_parent().queue_free()
			dark_panel = null
		)

func show_pause_menu():
	# Загружаем сцену меню паузы
	var pause_menu_scene = load("res://Scenes/UI/PauseMenuScene.tscn")
	if pause_menu_scene:
		pause_menu_instance = pause_menu_scene.instantiate()
		
		# Добавляем как дочерний к корню, чтобы был поверх всего
		get_tree().root.add_child(pause_menu_instance)
		
		# Позиционируем перед камерой
		position_menu_in_front_of_camera()

func hide_pause_menu():
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null

func position_menu_in_front_of_camera():
	if not pause_menu_instance:
		return
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Позиционируем меню на 2 метра перед камерой
		var forward = -camera.global_transform.basis.z
		pause_menu_instance.global_position = camera.global_position + forward * 2.0
		
		# Поворачиваем меню лицом к камере
		pause_menu_instance.look_at(camera.global_position, Vector3.UP)
	else:
		# Если нет 3D камеры (например, в 2D), позиционируем по центру экрана
		var viewport_size = get_viewport().get_visible_rect().size
		pause_menu_instance.position = Vector3(viewport_size.x / 2, viewport_size.y / 2, 0)

func mute_game_audio():
	# Отключаем звуки игры, но оставляем UI звуки
	var master_bus = AudioServer.get_bus_index("Master")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var music_bus = AudioServer.get_bus_index("Music")
	
	if sfx_bus != -1:
		AudioServer.set_bus_mute(sfx_bus, true)
	if music_bus != -1:
		AudioServer.set_bus_mute(music_bus, true)
	
	# Master не отключаем полностью, чтобы слышать UI

func unmute_game_audio():
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var music_bus = AudioServer.get_bus_index("Music")
	
	if sfx_bus != -1:
		AudioServer.set_bus_mute(sfx_bus, false)
	if music_bus != -1:
		AudioServer.set_bus_mute(music_bus, false)

# Функция для принудительной паузы (например, от админки)
func force_pause():
	if not is_paused:
		pause_game()

# Функция для принудительного возобновления
func force_resume():
	if is_paused:
		resume_game()

# Получить текущее состояние паузы (для других систем)
func get_pause_state() -> bool:
	return is_paused
