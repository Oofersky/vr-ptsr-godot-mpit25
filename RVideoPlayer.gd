# VRVideoPlayer.gd - прикрепляем к корневому Node3D
extends Node3D

@onready var video_player = $SubViewport/VideoStreamPlayer
@onready var viewport = $SubViewport
@onready var sphere = $Sphere

func _ready():
	# Загружаем видео файл .ogv
	var video_stream = load("res://output.ogv")
	video_player.stream = video_stream
	video_player.expand = true
	video_player.loops = true
	
	# Настраиваем материал сферы с проекцией видео
	setup_sphere_material()
	
	# Запускаем воспроизведение
	video_player.play()
	print("360° видео запущено на сфере!")

func setup_sphere_material():
	# Создаем материал для сферы
	var material = StandardMaterial3D.new()
	
	# Критически важные настройки для VR видео:
	material.flags_unshaded = true      # Игнорировать освещение
	material.flags_transparent = false  # Без прозрачности  
	material.cull_mode = StandardMaterial3D.CULL_DISABLED  # Видимость с обеих сторон
	material.vertex_color_use_as_albedo = false
	
	# Связываем текстуру Viewport с материалом сферы
	var viewport_texture = viewport.get_texture()
	material.albedo_texture = viewport_texture
	
	# Применяем материал к сфере
	sphere.material_override = material

func _input(event):
	# Управление воспроизведением пробелом
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if video_player.playing:
				video_player.pause()
				print("Пауза")
			else:
				video_player.play()
				print("Воспроизведение")
