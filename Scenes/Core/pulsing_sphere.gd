# PulsingSphere.gd
extends Node3D

@onready var animation_player = $MeshInstance3D/AnimationPlayer
@onready var mesh_instance = $MeshInstance3D

func _ready():
	# Автоматически запускаем анимацию
	animation_player.play("pulse")

# Методы для внешнего контроля
func start_pulsing():
	animation_player.play("pulse")

func stop_pulsing():
	animation_player.stop()
	mesh_instance.scale = Vector3.ONE  # Возвращаем к нормальному размеру

func set_pulse_speed(speed: float):
	animation_player.speed_scale = speed
