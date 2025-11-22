# UIManager.gd
extends CanvasLayer

enum UIState { MAIN_MENU, MORE_MENU, IN_GAME }
var current_state = UIState.MAIN_MENU

var main_menu_scene = preload("res://MainMenuPanel.tscn")
var more_menu_scene = preload("res://Scenes/UI/MoreMenuPanel.tscn")
var current_panel: CanvasLayer = null  # Изменили тип на CanvasLayer

func _ready():
	change_ui_state(UIState.MAIN_MENU)

func change_ui_state(new_state: UIState):
	# Очищаем предыдущее состояние
	if current_panel:
		remove_child(current_panel)
		current_panel.queue_free()
		current_panel = null
	
	current_state = new_state
	
	match new_state:
		UIState.MAIN_MENU:
			current_panel = main_menu_scene.instantiate()
			add_child(current_panel)
			
			# Ищем кнопку в дочерних элементах CanvasLayer
			var menu_button = current_panel.get_node("MainMenuPanel/MenuButton")
			if menu_button:
				menu_button.pressed.connect(func(): change_ui_state(UIState.MORE_MENU))
			
			get_tree().paused = false
			
		UIState.MORE_MENU:
			current_panel = more_menu_scene.instantiate()
			add_child(current_panel)
			
			# Подключаем кнопки MoreMenuPanel
			var more_menu_panel = current_panel.get_node("MoreMenuPanel")
			if more_menu_panel:
				var settings_button = more_menu_panel.get_node("SettingsEMDR")
				var fast_exit_button = more_menu_panel.get_node("FastExitButton")
				var safe_place_button = more_menu_panel.get_node("SafePlaceButton")
				var emdr_button = more_menu_panel.get_node("EMDRButton")
				var close_button = more_menu_panel.get_node("MenuCloseButton")
				
				if settings_button:
					settings_button.pressed.connect(_on_settings_pressed)
				if fast_exit_button:
					fast_exit_button.pressed.connect(_on_fast_exit_pressed)
				if safe_place_button:
					safe_place_button.pressed.connect(_on_safe_place_pressed)
				if emdr_button:
					emdr_button.pressed.connect(_on_emdr_pressed)
				if close_button:
					close_button.pressed.connect(func(): change_ui_state(UIState.MAIN_MENU))
			
			get_tree().paused = true
			
		UIState.IN_GAME:
			get_tree().paused = false

# Обработчики кнопок
func _on_settings_pressed():
	print("Settings EMDR pressed")

func _on_fast_exit_pressed():
	print("Fast Exit pressed")
	get_tree().quit()

func _on_safe_place_pressed():
	print("Safe Place pressed")

func _on_emdr_pressed():
	print("EMDR pressed")

# Для переключения по ESC
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		match current_state:
			UIState.MAIN_MENU:
				change_ui_state(UIState.IN_GAME)
			UIState.IN_GAME:
				change_ui_state(UIState.MORE_MENU)
			UIState.MORE_MENU:
				change_ui_state(UIState.MAIN_MENU)
