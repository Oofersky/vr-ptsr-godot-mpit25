extends TextureButton

var settings_emdr: Control
var is_panel_visible: bool = false

func _ready() -> void:
	# Ищем SettingsEMDR в корне сцены MoreMenuPanel
	settings_emdr = get_tree().current_scene.find_child("SettingsEMDR", true, false) as Control
	
	# Альтернативный способ - ищем относительно корня UI
	if not settings_emdr:
		var ui_manager = get_node("/root/UIManager")
		if ui_manager and ui_manager.current_container:
			settings_emdr = ui_manager.current_container.find_child("SettingsEMDR", true, false) as Control
	
	if not settings_emdr:
		print("SafePlaceButton: SettingsEMDR node not found!")
		# Выводим отладочную информацию о структуре
		print("Current scene structure:")
		_print_node_tree(get_tree().current_scene, 0)
		return
	
	print("SafePlaceButton: SettingsEMDR found successfully")
	pressed.connect(_on_pressed)
	settings_emdr.visible = false
	settings_emdr.modulate.a = 0.0
	is_panel_visible = false

func _print_node_tree(node: Node, indent: int):
	var indent_str = "  ".repeat(indent)
	print(indent_str + "└─ " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_node_tree(child, indent + 1)

# Остальной код без изменений
func _on_pressed() -> void:
	if not settings_emdr:
		print("SafePlaceButton: SettingsEMDR is null!")
		return
	
	print("SafePlaceButton: Toggling panel, current state: ", is_panel_visible)
	
	if is_panel_visible:
		hide_panel()
	else:
		show_panel()
	
	is_panel_visible = !is_panel_visible

func show_panel() -> void:
	print("SafePlaceButton: Showing panel")
	settings_emdr.visible = true
	var tween = create_tween()
	tween.tween_property(settings_emdr, "modulate:a", 1.0, 0.3)

func hide_panel() -> void:
	print("SafePlaceButton: Hiding panel")
	var tween = create_tween()
	tween.tween_property(settings_emdr, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		settings_emdr.visible = false
		print("SafePlaceButton: Panel hidden")
	)
