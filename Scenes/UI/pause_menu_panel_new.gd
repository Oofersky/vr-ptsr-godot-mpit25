extends CanvasLayer

var paused_nodes = {}
var is_paused = false
var dark_screen: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	create_dark_screen()

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # Изменено на ESC
		toggle_pause()

func toggle_pause():
	if is_paused:
		hide_dark_screen()
		resume_world()
	else:
		pause_world()
		show_dark_screen()
	
	is_paused = !is_paused

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
	print("Пауза включена")

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
	print("Пауза выключена")

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
