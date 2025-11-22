extends TextureButton

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	print(123)
	# Получаем UIManager через группу или автозагрузку
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager:
		ui_manager.switch_to_main_menu()
	else:
		push_error("UIManager not found!")
