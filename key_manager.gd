# key_manager.gd
extends Node

const KEY_FILE = "user://encryption_keys.cfg"

var encryption_key: PackedByteArray
var encryption_iv: PackedByteArray

var crypto = Crypto.new()

func _ready():
	load_or_generate_keys()

func load_or_generate_keys():
	var config = ConfigFile.new()
	
	if FileAccess.file_exists(KEY_FILE):
		# Загружаем существующие ключи
		if config.load(KEY_FILE) == OK:
			var key_hex = config.get_value("encryption", "key", "")
			var iv_hex = config.get_value("encryption", "iv", "")
			
			if key_hex != "" and iv_hex != "":
				encryption_key = hex_to_bytes(key_hex)
				encryption_iv = hex_to_bytes(iv_hex)
				print("Encryption keys loaded successfully")
				return
	
	# Генерируем новые ключи
	generate_new_keys()
	save_keys()
	print("New encryption keys generated and saved")

func generate_new_keys():
	# Генерируем случайный ключ (32 байта для AES-256)
	encryption_key = crypto.generate_random_bytes(32)
	
	# Генерируем случайный IV (16 байт для AES)
	encryption_iv = crypto.generate_random_bytes(16)

func save_keys():
	var config = ConfigFile.new()
	config.set_value("encryption", "key", bytes_to_hex(encryption_key))
	config.set_value("encryption", "iv", bytes_to_hex(encryption_iv))
	config.save(KEY_FILE)

func get_encryption_key() -> PackedByteArray:
	return encryption_key

func get_encryption_iv() -> PackedByteArray:
	return encryption_iv

func bytes_to_hex(bytes: PackedByteArray) -> String:
	return bytes.hex_encode()

func hex_to_bytes(hex: String) -> PackedByteArray:
	return PackedByteArray(hex.hex_decode())
