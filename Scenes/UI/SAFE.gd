extends TextureButton

var settings_emdr: Control
var is_panel_visible: bool = false

func _ready() -> void:
	# Пробуем разные пути к узлу
	settings_emdr = $SettingsEMDR  # Прямой потомок
	
	# Если не найден, пробуем другие пути
	if not settings_emdr:
		settings_emdr = get_node("../SettingsEMDR")  # На одном уровне
	
	if not settings_emdr:
		settings_emdr = get_node("../../SettingsEMDR")  # На уровень выше
	
	# Если все еще не найден, ищем по имени во всей сцене
	if not settings_emdr:
		settings_emdr = find_child("SettingsEMDR", true, false) as Control
	
	if not settings_emdr:
		push_error("SettingsEMDR node not found in any location!")
		return
	
	pressed.connect(_on_pressed)
	settings_emdr.visible = false
	settings_emdr.modulate.a = 0.0
	is_panel_visible = false

func _on_pressed() -> void:
	if not settings_emdr:
		return
	
	if is_panel_visible:
		hide_panel()
	else:
		show_panel()
	
	is_panel_visible = !is_panel_visible

func show_panel() -> void:
	settings_emdr.visible = true
	var tween = create_tween()
	tween.tween_property(settings_emdr, "modulate:a", 1.0, 0.3)

func hide_panel() -> void:
	var tween = create_tween()
	tween.tween_property(settings_emdr, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): settings_emdr.visible = false)
