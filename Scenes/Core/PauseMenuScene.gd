# PauseMenuScene.gd
extends Node3D

var paused_nodes = {}
var is_animating = false

@onready var UI = $UI

var dark_screen: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_to_group("pause_menu")
	
	if UI is CanvasLayer:
		UI.layer = 2
	else:
		push_warning("UI должен быть CanvasLayer!")
	create_dark_screen()


func toggle_pause_remote():
	if not is_animating:
		visible = !visible
		if visible:
			pause_world()
			await show_dark_screen()
			print("Пауза включена через сервер")
		else:
			await hide_dark_screen()
			print("Пауза выключена через сервер")

func create_dark_screen():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1
	add_child(canvas_layer)
	
	dark_screen = ColorRect.new()
	dark_screen.color = Color(0, 0, 0, 0)
	dark_screen.size = get_viewport().get_visible_rect().size
	dark_screen.anchor_left = 0
	dark_screen.anchor_top = 0
	dark_screen.anchor_right = 1
	dark_screen.anchor_bottom = 1
	dark_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(dark_screen)

func _input(event):
	if event.is_action_pressed("pause_game") and not is_animating:
		toggle_pause_remote()

func show_dark_screen():
	is_animating = true
	if dark_screen:
		var tween = create_tween()
		tween.tween_property(dark_screen, "color:a", 0.7, 0.5)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
	await get_tree().create_timer(0.5).timeout
	is_animating = false

func hide_dark_screen():
	is_animating = true
	if dark_screen:
		var tween = create_tween()
		tween.tween_property(dark_screen, "color:a", 0.0, 0.3)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
	await get_tree().create_timer(0.3).timeout
	resume_world()
	is_animating = false

func pause_world():
	paused_nodes.clear()
	var game_root = get_tree().current_scene
	if game_root:
		pause_node_recursive(game_root)

func pause_node_recursive(node):
	if node == self or node.is_in_group("player"):
		return

	var state = {}

	if node.has_method("set_process") and node.is_processing():
		node.set_process(false)
		state["process"] = true

	if node.has_method("set_physics_process") and node.is_physics_processing():
		node.set_physics_process(false)
		state["physics"] = true

	# Исправлено: используем свойство paused вместо метода pause()
	if node is VideoStreamPlayer:
		if not node.paused:  # Проверяем, не на паузе ли уже
			node.paused = true
			state["video"] = true

	if !state.is_empty():
		paused_nodes[node] = state

	for child in node.get_children():
		pause_node_recursive(child)

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
				node.paused = false  # Исправлено: используем paused вместо play()

	paused_nodes.clear()
