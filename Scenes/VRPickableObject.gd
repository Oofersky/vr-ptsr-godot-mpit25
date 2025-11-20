# VRPickableObject.gd
# Вспомогательный скрипт для объектов, которые можно захватывать в VR
# Расширяет XRToolsPickable из XR Tools

extends XRToolsPickable
class_name VRPickableObject

## Сигналы
signal grabbed_by_hand(hand: String)
signal released_from_hand(hand: String)
signal thrown(velocity: Vector3)

## Настройки объекта
@export_group("Pickable Settings")
@export var pickable_enabled: bool = true
# press_to_hold наследуется от XRToolsPickable (уже есть в родительском классе)
@export var can_be_thrown: bool = true  # Можно ли бросать объект
@export var throw_velocity_multiplier: float = 1.0  # Множитель скорости броска

## Настройки физики при захвате
@export_group("Physics Settings")
@export var freeze_on_pickup: bool = true  # Замораживать ли физику при захвате
@export var restore_physics_on_release: bool = true  # Восстанавливать ли физику при отпускании

## Настройки визуализации
@export_group("Visual Settings")
@export var highlight_material: Material = null  # Материал для подсветки при наведении
@export var highlight_enabled: bool = true

## Внутренние переменные
var _original_materials: Array[Material] = []
var _is_highlighted: bool = false
var _is_grabbed: bool = false


func _ready():
	# Вызываем родительский _ready
	super._ready()
	
	# Настраиваем компонент XRToolsPickable (мы сами являемся им)
	enabled = pickable_enabled
	# press_to_hold уже наследуется от XRToolsPickable, можно настроить в инспекторе
	
	# Подключаем сигналы родительского класса
	_connect_signals()
	
	# Сохраняем оригинальные материалы
	_save_original_materials()
	
	# Устанавливаем правильный слой коллизий для захватываемых объектов
	# Слой 3 = Pickable Objects (из project.godot)
	collision_layer = 0b0000_0000_0000_0000_0000_0000_0000_0100  # Слой 3


func _connect_signals():
	# Подключаем сигналы XRToolsPickable (мы сами являемся XRToolsPickable)
	if not grabbed.is_connected(_on_grabbed):
		grabbed.connect(_on_grabbed)
	
	if not released.is_connected(_on_released):
		released.connect(_on_released)
	
	if not picked_up.is_connected(_on_picked_up):
		picked_up.connect(_on_picked_up)
	
	if not dropped.is_connected(_on_dropped):
		dropped.connect(_on_dropped)


func _save_original_materials():
	# Сохраняем оригинальные материалы для восстановления
	_original_materials.clear()
	
	# Получаем материалы из всех MeshInstance3D
	var mesh_instances = _get_all_mesh_instances(self)
	for mesh in mesh_instances:
		for i in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_surface_override_material(i)
			if mat:
				_original_materials.append(mat)


func _get_all_mesh_instances(node: Node) -> Array:
	var result = []
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(_get_all_mesh_instances(child))
	
	return result


func _on_grabbed(pickable: XRToolsPickable, by: Node3D):
	_is_grabbed = true
	
	# Определяем, какая рука захватила объект
	var hand = _determine_hand(by)
	grabbed_by_hand.emit(hand)
	
	print("VRPickableObject: Объект %s захвачен %s рукой" % [name, hand])


func _on_released(pickable: XRToolsPickable, by: Node3D):
	_is_grabbed = false
	
	# Определяем, какая рука отпустила объект
	var hand = _determine_hand(by)
	released_from_hand.emit(hand)
	
	# Если объект был брошен, вычисляем скорость
	if can_be_thrown and by is XRToolsFunctionPickup:
		var pickup = by as XRToolsFunctionPickup
		if pickup.picked_up_object == pickable:
			# Вычисляем скорость броска
			var throw_velocity = _calculate_throw_velocity(pickup)
			if throw_velocity.length() > 0.1:
				thrown.emit(throw_velocity)
	
	print("VRPickableObject: Объект %s отпущен %s рукой" % [name, hand])


func _on_picked_up(pickable: XRToolsPickable):
	# Объект поднят
	pass


func _on_dropped(pickable: XRToolsPickable):
	# Объект отпущен
	pass


func _determine_hand(by: Node3D) -> String:
	# Определяем, какая рука захватила объект
	if not by:
		return "unknown"
	
	# Проверяем путь к контроллеру
	var path = str(by.get_path())
	if "left" in path.to_lower() or "Left" in path:
		return "left"
	elif "right" in path.to_lower() or "Right" in path:
		return "right"
	
	return "unknown"


func _calculate_throw_velocity(pickup: XRToolsFunctionPickup) -> Vector3:
	# Вычисляем скорость броска на основе движения контроллера
	# Это упрощенная версия - в реальности XRToolsFunctionPickup уже делает это
	var controller = pickup.get_controller()
	if not controller:
		return Vector3.ZERO
	
	# Получаем линейную скорость контроллера
	var linear_velocity = controller.get_velocity()
	return linear_velocity * throw_velocity_multiplier


## Публичные методы

## Запросить подсветку объекта
## Переопределяет метод из XRToolsPickable для добавления кастомной подсветки
func request_highlight(from: Node, on: bool = true) -> void:
	# Вызываем родительский метод для правильной работы системы подсветки XR Tools
	super.request_highlight(from, on)
	
	# Если кастомная подсветка отключена, используем только стандартную
	if not highlight_enabled:
		return
	
	# Применяем кастомную подсветку через материалы
	if on and not _is_highlighted:
		_apply_highlight()
		_is_highlighted = true
	elif not on and _is_highlighted:
		_remove_highlight()
		_is_highlighted = false


func _apply_highlight():
	if not highlight_material:
		return
	
	# Применяем материал подсветки ко всем MeshInstance3D
	var mesh_instances = _get_all_mesh_instances(self)
	for mesh in mesh_instances:
		for i in range(mesh.get_surface_override_material_count()):
			# Создаем копию материала для подсветки
			var highlight = highlight_material.duplicate()
			mesh.set_surface_override_material(i, highlight)


func _remove_highlight():
	# Восстанавливаем оригинальные материалы
	var mesh_instances = _get_all_mesh_instances(self)
	var mat_index = 0
	for mesh in mesh_instances:
		for i in range(mesh.get_surface_override_material_count()):
			if mat_index < _original_materials.size():
				mesh.set_surface_override_material(i, _original_materials[mat_index])
				mat_index += 1


## Проверить, захвачен ли объект
func is_grabbed() -> bool:
	return _is_grabbed


## Включить/выключить возможность захвата
func set_pickable_enabled(enabled_state: bool):
	pickable_enabled = enabled_state
	enabled = enabled_state
