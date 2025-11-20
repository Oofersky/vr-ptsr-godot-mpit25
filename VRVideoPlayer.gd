extends Node3D

@onready var video_player = $VideoViewport/SubViewportContainer/VideoPlayer

func _ready():
	# Загружаем видеофайл .ogv как ресурс
	var video_stream_resource = load("res://sample_1280x720_surfing_with_audio.ogv")
	
	if video_stream_resource == null:
		print("ОШИБКА: Не удалось загрузить видеоресурс!")
		return
	
	# Настраиваем видеоплеер
	video_player.stream = video_stream_resource
	video_player.loop = true
	
	# Запускаем воспроизведение
	video_player.play()
	
	print("360° видео запущено!")
