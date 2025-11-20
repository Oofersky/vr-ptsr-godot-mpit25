extends CanvasLayer

@onready var counter = $Panel/Counter
@onready var slider = $Panel/MarginContainer/Panel/HSlider
@onready var confirm = $Panel/MarginContainer2/Confirm

func _ready() -> void:
	confirm.pressed.connect(_on_confirm_pressed)  # Правильное подключение сигнала
	slider.value_changed.connect(_on_slider_value_changed)

func _on_slider_value_changed(value: float) -> void:
	counter.text = str(int(round(value)))

func _on_confirm_pressed() -> void:
	print("Значение шкалы:", int(round(slider.value)))
