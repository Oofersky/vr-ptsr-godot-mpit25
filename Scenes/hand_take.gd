# hand_take.gd
# Скрипт для управления захватом объектов в VR
# Автоматически добавляет и настраивает XRToolsFunctionPickup на контроллерах

extends Node

## Сигналы для событий захвата
signal object_grabbed(object: Node3D, hand: String)
signal object_released(object: Node3D, hand: String)
signal object_highlighted(object: Node3D, hand: String)
signal object_unhighlighted(object: Node3D, hand: String)

## Настройки захвата
@export_group("Grab Settings")
@export var grab_distance: float = 0.3  # Расстояние захвата в метрах
@export var ranged_grab_distance: float = 5.0  # Расстояние дальнего захвата
@export var ranged_grab_angle: float = 5.0  # Угол дальнего захвата
@export var throw_impulse_factor: float = 1.0  # Множитель силы броска

## Ссылки на компоненты захвата
var left_pickup: XRToolsFunctionPickup = null
var right_pickup: XRToolsFunctionPickup = null
var player_scene: Node3D = null

## Кэш для отслеживания объектов
var _left_grabbed_object: Node3D = null
var _right_grabbed_object: Node3D = null


func _ready():
	print("HandTake: Инициализация системы захвата объектов...")
	
	# Если скрипт добавлен как autoload, ждем загрузки сцены
	if get_tree().current_scene == null:
		# Ждем, пока сцена загрузится
		await get_tree().scene_loaded
		await get_tree().process_frame
	
	# Находим сцену игрока
	player_scene = _find_player_scene()
	if not player_scene:
		# Пробуем найти через несколько кадров (на случай, если сцена еще загружается)
		await get_tree().process_frame
		player_scene = _find_player_scene()
		if not player_scene:
			push_warning("HandTake: Не найдена сцена игрока (XROrigin3D). Попытка через 1 секунду...")
			await get_tree().create_timer(1.0).timeout
			player_scene = _find_player_scene()
			if not player_scene:
				push_error("HandTake: Не найдена сцена игрока (XROrigin3D)")
				return
	
	# Ждем следующий кадр, чтобы убедиться, что все узлы загружены
	await get_tree().process_frame
	_setup_pickup_systems()


func _find_player_scene() -> Node3D:
	# Ищем XROrigin3D в дереве сцены
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


func _setup_pickup_systems():
	if not player_scene:
		return
	
	# Находим контроллеры
	var left_controller = _find_controller(player_scene, "left")
	var right_controller = _find_controller(player_scene, "right")
	
	if not left_controller:
		push_warning("HandTake: Левый контроллер не найден")
	if not right_controller:
		push_warning("HandTake: Правый контроллер не найден")
	
	# Настраиваем захват для левой руки
	if left_controller:
		left_pickup = _setup_pickup_for_controller(left_controller, "left")
	
	# Настраиваем захват для правой руки
	if right_controller:
		right_pickup = _setup_pickup_for_controller(right_controller, "right")
	
	# Подключаем сигналы
	_connect_pickup_signals()
	
	print("HandTake: Система захвата объектов настроена успешно")


func _find_controller(origin: Node3D, hand: String) -> XRController3D:
	# Ищем контроллер по имени
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


func _setup_pickup_for_controller(controller: XRController3D, hand: String) -> XRToolsFunctionPickup:
	# Проверяем, есть ли уже XRToolsFunctionPickup
	var existing_pickup = XRToolsFunctionPickup.find_instance(controller)
	if existing_pickup:
		print("HandTake: Найден существующий XRToolsFunctionPickup для %s руки" % hand)
		_configure_pickup(existing_pickup)
		return existing_pickup
	
	# Создаем новый XRToolsFunctionPickup
	print("HandTake: Создание нового XRToolsFunctionPickup для %s руки" % hand)
	
	# Загружаем сцену XRToolsFunctionPickup
	var pickup_scene = load("res://addons/godot-xr-tools/functions/function_pickup.tscn")
	if not pickup_scene:
		push_error("HandTake: Не удалось загрузить сцену function_pickup.tscn")
		return null
	
	var pickup = pickup_scene.instantiate() as XRToolsFunctionPickup
	if not pickup:
		push_error("HandTake: Не удалось создать экземпляр XRToolsFunctionPickup")
		return null
	
	# Настраиваем параметры
	_configure_pickup(pickup)
	
	# Добавляем к контроллеру
	# Ищем CollisionHand или добавляем напрямую к контроллеру
	var collision_hand = controller.find_child("*CollisionHand*", true, false)
	if collision_hand:
		collision_hand.add_child(pickup)
		pickup.name = "FunctionPickup"
	else:
		controller.add_child(pickup)
		pickup.name = "FunctionPickup"
	
	print("HandTake: XRToolsFunctionPickup добавлен к %s контроллеру" % hand)
	return pickup


func _configure_pickup(pickup: XRToolsFunctionPickup):
	# Настраиваем параметры захвата
	pickup.grab_distance = grab_distance
	pickup.ranged_distance = ranged_grab_distance
	pickup.ranged_angle = ranged_grab_angle
	pickup.impulse_factor = throw_impulse_factor
	pickup.enabled = true
	
	# Настраиваем маску коллизий для захвата объектов
	# Слой 3 = Pickable Objects (из project.godot)
	pickup.grab_collision_mask = 0b0000_0000_0000_0000_0000_0000_0000_0100  # Слой 3
	pickup.ranged_collision_mask = 0b0000_0000_0000_0000_0000_0000_0000_0100  # Слой 3


func _connect_pickup_signals():
	# Подключаем сигналы левой руки
	if left_pickup:
		if not left_pickup.has_picked_up.is_connected(_on_left_picked_up):
			left_pickup.has_picked_up.connect(_on_left_picked_up)
		if not left_pickup.has_dropped.is_connected(_on_left_dropped):
			left_pickup.has_dropped.connect(_on_left_dropped)
	
	# Подключаем сигналы правой руки
	if right_pickup:
		if not right_pickup.has_picked_up.is_connected(_on_right_picked_up):
			right_pickup.has_picked_up.connect(_on_right_picked_up)
		if not right_pickup.has_dropped.is_connected(_on_right_dropped):
			right_pickup.has_dropped.connect(_on_right_dropped)


func _on_left_picked_up(what: Node3D):
	_left_grabbed_object = what
	object_grabbed.emit(what, "left")
	print("HandTake: Левой рукой захвачен объект: ", what.name)


func _on_left_dropped():
	if _left_grabbed_object:
		object_released.emit(_left_grabbed_object, "left")
		print("HandTake: Левой рукой отпущен объект: ", _left_grabbed_object.name)
		_left_grabbed_object = null


func _on_right_picked_up(what: Node3D):
	_right_grabbed_object = what
	object_grabbed.emit(what, "right")
	print("HandTake: Правой рукой захвачен объект: ", what.name)


func _on_right_dropped():
	if _right_grabbed_object:
		object_released.emit(_right_grabbed_object, "right")
		print("HandTake: Правой рукой отпущен объект: ", _right_grabbed_object.name)
		_right_grabbed_object = null


## Публичные методы для управления захватом

## Получить объект, захваченный левой рукой
func get_left_grabbed_object() -> Node3D:
	return _left_grabbed_object


## Получить объект, захваченный правой рукой
func get_right_grabbed_object() -> Node3D:
	return _right_grabbed_object


## Проверить, захвачен ли объект
func is_object_grabbed(object: Node3D) -> bool:
	return _left_grabbed_object == object or _right_grabbed_object == object


## Принудительно отпустить объект из левой руки
func force_release_left():
	if left_pickup and left_pickup.picked_up_object:
		left_pickup.picked_up_object.let_go(left_pickup, Vector3.ZERO, Vector3.ZERO)


## Принудительно отпустить объект из правой руки
func force_release_right():
	if right_pickup and right_pickup.picked_up_object:
		right_pickup.picked_up_object.let_go(right_pickup, Vector3.ZERO, Vector3.ZERO)


## Принудительно отпустить все объекты
func force_release_all():
	force_release_left()
	force_release_right()


## Получить компонент захвата для левой руки
func get_left_pickup() -> XRToolsFunctionPickup:
	return left_pickup


## Получить компонент захвата для правой руки
func get_right_pickup() -> XRToolsFunctionPickup:
	return right_pickup
