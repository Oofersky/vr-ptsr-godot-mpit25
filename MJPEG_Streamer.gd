# MJPEG_Streamer.gd
extends Node

var server: TCPServer
var clients: Array[StreamPeerTCP] = []
var stream_port: int = 8080
var is_streaming: bool = false
var frame_timer: Timer
var network_timer: Timer
var network_label: Label3D
var is_capturing: bool = false
var available_ports = [8080, 8081, 8082, 9080, 9081, 9082, 10080, 10081]  # Список портов для попытки

func _ready():
	setup_network_display()
	try_start_server()
	setup_frame_timer()
	setup_network_timer()

func setup_network_display():
	# Создаем 3D текст для отображения сетевой информации в VR
	network_label = Label3D.new()
	network_label.text = "Checking network..."
	network_label.position = Vector3(0, 0.3, -1.5)  # Перед камерой
	network_label.scale = Vector3(0.3, 0.3, 0.3)    # Подбираем размер
	network_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Всегда повернут к камере
	
	# Добавляем как дочерний узел к текущей сцене
	get_tree().current_scene.add_child(network_label)

func setup_network_timer():
	# Таймер для периодической проверки сети
	network_timer = Timer.new()
	network_timer.wait_time = 3.0  # Проверяем каждые 3 секунды
	network_timer.timeout.connect(update_network_status)
	add_child(network_timer)
	network_timer.start()
	
	# Первоначальная проверка
	update_network_status()

func update_network_status():
	var ip = get_wifi_ip()
	if ip and is_streaming:
		var url = "http://" + ip + ":" + str(stream_port)
		network_label.text = "✅ STREAM READY\nIP: " + ip + "\nPort: " + str(stream_port) + "\nURL: " + url
		print("Stream available at: ", url)
	elif not is_streaming:
		network_label.text = "❌ FIREWALL BLOCKED\n\nPort " + str(stream_port) + " is blocked\nTrying different ports..."
		print("Firewall blocking port ", stream_port)
	else:
		network_label.text = "❌ NO WIFI NETWORK\n\nConnect to WiFi to stream"
		print("No WiFi network detected")

func try_start_server():
	# Пытаемся запустить сервер на разных портах
	for port in available_ports:
		if start_mjpeg_server(port):
			stream_port = port
			is_streaming = true
			print("Successfully started server on port: ", port)
			return
	
	# Если ни один порт не сработал
	push_error("Failed to start server on any port! Firewall may be blocking all ports.")
	is_streaming = false

func start_mjpeg_server(port: int) -> bool:
	server = TCPServer.new()
	
	# Пытаемся запустить сервер на указанном порту
	if server.listen(port, "0.0.0.0") == OK:
		print("MJPEG Server started on port ", port)
		print_network_info()
		return true
	else:
		print("Failed to start MJPEG server on port ", port)
		return false

func get_wifi_ip() -> String:
	var interfaces = IP.get_local_interfaces()
	
	for interface in interfaces:
		var name = interface.get("name", "").to_lower()
		var addresses = interface.get("addresses", [])
		
		# Пропускаем нежелательные интерфейсы
		if (name.contains("loopback") or name.contains("docker") or 
			name.contains("virtual") or name.contains("vmnet")):
			continue
		
		# Проверяем все адреса интерфейса
		for address in addresses:
			if address is String and is_real_wifi_ip(address):
				print("Found WiFi interface: ", name, " - IP: ", address)
				return address
	
	return ""

func is_real_wifi_ip(ip: String) -> bool:
	# Игнорируем link-local адреса (169.254.x.x)
	if ip.begins_with("169.254."):
		return false
	
	# Принимаем только настоящие частные IP-адреса:
	# 10.0.0.0 - 10.255.255.255
	if ip.begins_with("10."):
		return true
	
	# 172.16.0.0 - 172.31.255.255
	if ip.begins_with("172."):
		var parts = ip.split(".")
		if parts.size() >= 2:
			var second_octet = parts[1].to_int()
			if second_octet >= 16 and second_octet <= 31:
				return true
	
	# 192.168.0.0 - 192.168.255.255
	if ip.begins_with("192.168."):
		return true
	
	return false

func print_network_info():
	var ip = get_wifi_ip()
	if ip:
		print("=== NETWORK INFO ===")
		print("Stream URL: http://", ip, ":", stream_port)
		print("On your computer, open browser to this URL")
		print("If connection fails, check Windows Firewall settings")
		print("====================")
	else:
		print("⚠️  No WiFi network detected")

func setup_frame_timer():
	frame_timer = Timer.new()
	frame_timer.wait_time = 1.0 / 30.0  # 30 FPS
	frame_timer.timeout.connect(_on_frame_timeout)
	add_child(frame_timer)
	frame_timer.start()

func _on_frame_timeout():
	if not is_capturing and not clients.is_empty():
		capture_and_send_frame()

func _process(_delta):
	if not is_streaming:
		return
  
	# Принимаем новые подключения
	if server.is_connection_available():
		var client = server.take_connection()
		if client != null:
			clients.append(client)
			send_http_headers(client)
			print("New client connected")
  
	# Удаляем отключившихся клиентов
	cleanup_clients()

func capture_and_send_frame():
	if clients.is_empty():
		return
	
	# Запускаем асинхронный захват кадра
	is_capturing = true
	_capture_frame_async()

func _capture_frame_async():
	# Ждем следующий кадр рендеринга
	await get_tree().process_frame
	
	var frame = capture_frame()
	if not frame.is_empty():
		send_frame_to_clients(frame)
	
	is_capturing = false

func capture_frame() -> PackedByteArray:
	var viewport = get_viewport()
	
	# Получаем текстуру viewport и конвертируем в изображение
	var viewport_texture = viewport.get_texture()
	var image = viewport_texture.get_image()
	
	# Масштабируем если нужно для производительности
	if image.get_width() > 1280 or image.get_height() > 720:
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	
	# Сохраняем в JPEG - правильный метод для Godot 4
	return image.save_jpg_to_buffer(0.8)  # Качество 80% (0.0-1.0)

func send_http_headers(client: StreamPeerTCP):
	var headers = (
		"HTTP/1.0 200 OK\r\n" +
		"Content-Type: multipart/x-mixed-replace; boundary=frame\r\n" +
		"Access-Control-Allow-Origin: *\r\n" +
        "\r\n"
	)
	client.put_data(headers.to_utf8_buffer())

func send_frame_to_clients(frame: PackedByteArray):
	var boundary = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + str(frame.size()) + "\r\n\r\n"
	var data = boundary.to_utf8_buffer() + frame + "\r\n".to_utf8_buffer()
  
	var disconnected_clients: Array[int] = []
  
	for i in range(clients.size()):
		var client = clients[i]
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var error = client.put_data(data)
			if error != OK:
				disconnected_clients.append(i)
		else:
			disconnected_clients.append(i)
  
	# Удаляем отключившихся клиентов в обратном порядке
	disconnected_clients.reverse()
	for i in disconnected_clients:
		clients.remove_at(i)

func cleanup_clients():
	var disconnected_clients: Array[int] = []
	for i in range(clients.size()):
		if clients[i].get_status() != StreamPeerTCP.STATUS_CONNECTED:
			disconnected_clients.append(i)
  
	# Разворачиваем массив и удаляем
	disconnected_clients.reverse()
	for i in disconnected_clients:
		clients.remove_at(i)

func _exit_tree():
	# При закрытии приложения останавливаем сервер
	if server:
		server.stop()
	is_streaming = false
	if frame_timer:
		frame_timer.stop()
	if network_timer:
		network_timer.stop()
	if network_label and is_instance_valid(network_label):
		network_label.queue_free()
