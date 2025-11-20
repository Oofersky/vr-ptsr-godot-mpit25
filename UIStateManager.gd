# res://Scripts/Services/XRUIStateManager.gd
extends Node

# Сигналы для XR UI
signal ui_state_changed(new_state_name, previous_state_name)
signal safe_place_picker_requested

# Перечисление состояний UI для XR
enum UIState {
	NONE,
	MAIN_MENU,
	SETTINGS_MENU,
	SAFE_PLACE_PICKER,
	PAUSE_MENU,
	INVENTORY
}

# Ссылки на сцены UI
var _ui_scenes = {
	UIState.MAIN_MENU: preload("res://Scenes/UI/MainMenuPanel.tscn"),
	#UIState.SETTINGS_MENU: preload("res://Scenes/UI/Sett"),
	UIState.SAFE_PLACE_PICKER: preload("res://Scenes/UI/SafePlacePickerMenuPanel.tscn"),
	UIState.PAUSE_MENU: preload("res://Scenes/UI/PauseMenuPanel.tscn"),
}

# Ссылка на Viewport2Din3D компонент
var xr_ui_viewport: Node = null

# Текущее состояние
var current_state: int = UIState.NONE:
	set(value):
		var previous = current_state
		current_state = value
		ui_state_changed.emit(current_state, previous)

func _ready() -> void:
	# Находим Viewport2Din3D в сцене
	_find_xr_ui_viewport()
	
	# Подписываемся на глобальные события
	EventBus.connect("request_safe_place_picker", Callable(self, "_on_safe_place_picker_requested"))
	EventBus.connect("request_settings_menu", Callable(self, "_on_settings_menu_requested"))
	
	print("XR UI State Manager initialized")

# Поиск Viewport2Din3D в сцене
func _find_xr_ui_viewport() -> void:
	# Ищем по тегу или имени
	xr_ui_viewport = get_tree().root.find_child("XRUIViewport", true, false)
	
	if not xr_ui_viewport:
		push_error("XRUIViewport not found! Make sure it exists in the scene tree.")
		return
	
	# Проверяем, что это действительно Viewport с Content
	if not xr_ui_viewport.has_method("set_content_scene") and not xr_ui_viewport.has_node("Content"):
		push_error("XRUIViewport does not have expected interface for content management.")
		xr_ui_viewport = null

# Изменение состояния UI
func change_ui_state(new_state: int) -> void:
	if current_state == new_state:
		return
	
	if not _ui_scenes.has(new_state):
		push_error("UI state not registered: ", new_state)
		return
	
	if not xr_ui_viewport:
		push_error("XRUIViewport not available. Cannot change UI state.")
		return
	
	# Загружаем новую сцену
	var new_scene = _ui_scenes[new_state]
	if not new_scene:
		push_error("Failed to load UI scene for state: ", new_state)
		return
	
	var ui_instance = new_scene.instantiate()
	
	# Обновляем контент в Viewport2Din3D
	if xr_ui_viewport.has_method("set_content_scene"):
		# Если есть специальный метод
		xr_ui_viewport.set_content_scene(ui_instance)
	elif xr_ui_viewport.has_node("Content"):
		# Если есть дочерний узел Content
		var content_node = xr_ui_viewport.get_node("Content")
		for child in content_node.get_children():
			child.queue_free()
		content_node.add_child(ui_instance)
	else:
		push_error("XRUIViewport has no known way to set content")
		return
	
	# Обновляем состояние
	current_state = new_state
	print("XR UI changed to state: ", new_state)

# Обработчики событий
func _on_safe_place_picker_requested() -> void:
	change_ui_state(UIState.SAFE_PLACE_PICKER)
	safe_place_picker_requested.emit()

func _on_settings_menu_requested() -> void:
	change_ui_state(UIState.SETTINGS_MENU)
