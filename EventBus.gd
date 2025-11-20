# res://Scripts/Services/EventBus.gd
extends Node

# Глобальные события UI
signal request_safe_place_picker
signal request_settings_menu
signal request_main_menu
signal request_pause_menu
signal request_game_over

# События игры
signal game_started
signal game_paused
signal game_resumed
signal game_over

# Инициализация
func _ready() -> void:
	print("Event Bus initialized")
