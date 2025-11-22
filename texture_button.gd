extends TextureButton

func _ready() -> void:
	connect("pressed", Callable(self, "_on_sud_confirmed"))
#
func _on_sud_confirmed():
	print(123)
