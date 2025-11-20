extends Button

@export var scene_path: String = "res://Scenes/Core/PeachScene.tscn"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed():
	print("Кнопка нажата - выполняем переход на сцену")
	
	if ResourceLoader.exists(scene_path):
		print("Сцена найдена: ", scene_path)
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Ошибка: Сцена не найдена по пути: " + scene_path)
