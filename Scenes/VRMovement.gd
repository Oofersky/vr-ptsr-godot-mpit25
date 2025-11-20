
# Скрипт для управления ходьбой в VR
# Автоматически добавляет и настраивает систему передвижения XRToolsMovementDirect

extends Node

## Сигналы
signal movement_started(hand: String)
signal movement_stopped(hand: String)
signal movement_speed_changed(speed: float)

## Настройки передвижения
@export_group("Movement Settings")
@export var walk_speed: float = 3.0  # Скорость ходьбы (м/с)
@export var sprint_speed: float = 6.0  # Скорость бега (м/с)
@export var strafe_enabled: bool = true  # Разрешить движение вбок
@export var enable_left_hand: bool = true  # Использовать левую руку для передвижения
@export var enable_right_hand: bool = true  # Использовать правую руку для передвижения

## Настройки джойстика
@export_group("Joystick Settings")
@export var input_action: String = "primary"  # Действие для ввода (primary = джойстик)
@export var deadzone: float = 0.2  # Мертвая зона джойстика

## Порядок обработки передвижения
@export var movement_order: int = 10  # Приоритет передвижения

## Ссылки на компоненты
var left_movement: XRToolsMovementDirect = null
var right_movement: XRToolsMovementDirect = null
var player_scene: XROrigin3D = null
var player_body: XRToolsPlayerBody = null

## Внутренние переменные
var _current_speed: float = 0.0
var _is_moving: bool = false
var _active_hand: String = ""


func _ready():
	print("VRMovement: Инициализация системы передвижения...")
	
	# Ждем загрузки сцены
	if get_tree().current_scene == null:
		await get_tree().scene_loaded
		await get_tree().process_frame
	
	# Находим сцену игрока
	player_scene = _find_player_scene()
	if not player_scene:
		await get_tree().process_frame
		player_scene = _find_player_scene()
		if not player_scene:
			push_warning("VRMovement: Не найдена сцена игрока. Попытка через 1 секунду...")
			await get_tree().create_timer(1.0).timeout
			player_scene = _find_player_scene()
			if not player_scene:
				push_error("VRMovement: Не найдена сцена игрока (XROrigin3D)")
				return
	
	# Ждем следующий кадр для загрузки всех узлов
	await get_tree().process_frame
	_setup_movement_systems()


func _find_player_scene() -> XROrigin3D:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	
	# Проверяем, является ли корневая сцена XROrigin3D
	if scene_root is XROrigin3D:
		return scene_root
	
	# Ищем XROrigin3D среди дочерних узлов
	var player = scene_root.find_child("Player", true, false)
	if player and player is XROrigin3D:
		return player
	
	# Ищем любой XROrigin3D в сцене
	var xr_origins = scene_root.find_children("*", "XROrigin3D", true, false)
	if xr_origins.size() > 0:
		return xr_origins[0] as XROrigin3D
	
	return null


func _setup_movement_systems():
	if not player_scene:
		return
	
	# Находим PlayerBody
	player_body = player_scene.find_child("PlayerBody", true, false) as XRToolsPlayerBody
	if not player_body:
		push_warning("VRMovement: PlayerBody не найден. Передвижение может не работать.")
	
	# Находим контроллеры
	var left_controller = _find_controller(player_scene, "left")
	var right_controller = _find_controller(player_scene, "right")
	
	# Настраиваем передвижение для левой руки
	if left_controller and enable_left_hand:
		left_movement = _setup_movement_for_controller(left_controller, "left")
	
	# Настраиваем передвижение для правой руки
	if right_controller and enable_right_hand:
		right_movement = _setup_movement_for_controller(right_controller, "right")
	
	print("VRMovement: Система передвижения настроена успешно")


func _find_controller(origin: XROrigin3D, hand: String) -> XRController3D:
	var controller_name = ""
	if hand == "left":
		controller_name = "LeftXRController3D"
	else:
		controller_name = "RightController3D"
	
	var controller = origin.find_child(controller_name, true, false) as XRController3D
	
	# Если не нашли по имени, ищем по трекеру
	if not controller:
		var controllers = origin.find_children("*", "XRController3D", true, false)
		for ctrl in controllers:
			var ctrl_hand = ctrl.get("tracker")
			if (hand == "left" and ctrl_hand == "left_hand") or \
			   (hand == "right" and ctrl_hand == "right_hand"):
				controller = ctrl
				break
	
	return controller


func _setup_movement_for_controller(controller: XRController3D, hand: String) -> XRToolsMovementDirect:
	# Проверяем, есть ли уже XRToolsMovementDirect
	var existing_movement = XRTools.find_xr_child(controller, "*", "XRToolsMovementDirect") as XRToolsMovementDirect
	if existing_movement:
		print("VRMovement: Найден существующий XRToolsMovementDirect для %s руки" % hand)
		_configure_movement(existing_movement)
		return existing_movement
	
	# Создаем новый XRToolsMovementDirect
	print("VRMovement: Создание нового XRToolsMovementDirect для %s руки" % hand)
	
	var movement_scene = load("res://addons/godot-xr-tools/functions/movement_direct.tscn")
	if not movement_scene:
		push_error("VRMovement: Не удалось загрузить сцену movement_direct.tscn")
		return null
	
	var movement = movement_scene.instantiate() as XRToolsMovementDirect
	if not movement:
		push_error("VRMovement: Не удалось создать экземпляр XRToolsMovementDirect")
		return null
	
	# Настраиваем параметры
	_configure_movement(movement)
	
	# Добавляем к контроллеру
	# Ищем CollisionHand или добавляем напрямую к контроллеру
	var collision_hand = controller.find_child("*CollisionHand*", true, false)
	if collision_hand:
		collision_hand.add_child(movement)
		movement.name = "MovementDirect"
	else:
		controller.add_child(movement)
		movement.name = "MovementDirect"
	
	print("VRMovement: XRToolsMovementDirect добавлен к %s контроллеру" % hand)
	return movement


func _configure_movement(movement: XRToolsMovementDirect):
	# Настраиваем параметры передвижения
	movement.max_speed = walk_speed
	movement.strafe = strafe_enabled
	movement.input_action = input_action
	movement.order = movement_order
	movement.enabled = true


## Публичные методы

## Установить скорость ходьбы
func set_walk_speed(speed: float):
	walk_speed = speed
	_update_movement_speed()


## Установить скорость бега
func set_sprint_speed(speed: float):
	sprint_speed = speed


## Включить/выключить движение вбок
func set_strafe_enabled(enabled: bool):
	strafe_enabled = enabled
	if left_movement:
		left_movement.strafe = enabled
	if right_movement:
		right_movement.strafe = enabled


## Включить/выключить передвижение левой рукой
func set_left_hand_enabled(enabled: bool):
	enable_left_hand = enabled
	if left_movement:
		left_movement.enabled = enabled


## Включить/выключить передвижение правой рукой
func set_right_hand_enabled(enabled: bool):
	enable_right_hand = enabled
	if right_movement:
		right_movement.enabled = enabled


## Получить текущую скорость
func get_current_speed() -> float:
	return _current_speed


## Проверить, движется ли игрок
func is_moving() -> bool:
	return _is_moving


## Получить активную руку для передвижения
func get_active_hand() -> String:
	return _active_hand


## Включить режим бега (увеличить скорость)
func enable_sprint():
	_update_movement_speed(sprint_speed)


## Выключить режим бега (вернуть обычную скорость)
func disable_sprint():
	_update_movement_speed(walk_speed)


## Внутренние методы

func _update_movement_speed(speed: float = -1.0):
	if speed < 0:
		speed = walk_speed
	
	_current_speed = speed
	
	if left_movement:
		left_movement.max_speed = speed
	if right_movement:
		right_movement.max_speed = speed
	
	movement_speed_changed.emit(speed)


## Получить компонент передвижения для левой руки
func get_left_movement() -> XRToolsMovementDirect:
	return left_movement


## Получить компонент передвижения для правой руки
func get_right_movement() -> XRToolsMovementDirect:
	return right_movement
