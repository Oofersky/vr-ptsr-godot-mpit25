extends Node3D

var xr_interface: XRInterface

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR Initialised!")
		
		# Turn off v-sync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		# Change viewport to HMD
		get_viewport().use_xr = true
	else:
		print("OpenXR is npt initialised, please cheak VR hardware!")
