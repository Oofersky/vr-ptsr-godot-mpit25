extends HSlider

@onready var counter = get_tree().get_first_node_in_group("EMDR_Counters")

func _ready() -> void:
	value_changed.connect(_on_value_changed)
	# Если counter не найден, попробуем найти еще раз в _ready, но это маловероятно поможет
	if not counter:
		# Попробуем найти по имени, если группа не сработала
		counter = get_tree().root.find_child("Counter", true, false)
		if not counter:
			print("Counter not found!")
			return
	# Устанавливаем начальное значение
	_on_value_changed(value)

func _on_value_changed(new_value: float) -> void:
	if counter:
		# Предполагаем, что у counter есть свойство text, которое отображает значение
		counter.text = str(int(new_value))
