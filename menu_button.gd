extends TextureButton

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	print("Main menu button pressed")
	# Получаем UIManager через автозагрузку
	var ui_manager = get_node("/root/UI")
	if ui_manager:
		ui_manager.switch_to_more_menu()
	else:
		push_error("UIManager not found!")
