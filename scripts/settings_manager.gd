extends Node

var is_embedded = false

func _ready():
	print("SettingsManager: Loading settings...")
	# Check if we're running in an embedded environment
	is_embedded = Engine.is_editor_hint()
	print("SettingsManager: Running in editor: ", is_embedded)
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		print("SettingsManager: Successfully loaded settings file")
		var fullscreen = config.get_value("video", "fullscreen", false)
		var resolution_x = config.get_value("video", "resolution_x", 1920)
		var resolution_y = config.get_value("video", "resolution_y", 1080)
		
		print("SettingsManager: Loaded settings - Fullscreen: ", fullscreen, " Resolution: ", resolution_x, "x", resolution_y)
		
		if not is_embedded:
			apply_settings(fullscreen, Vector2i(resolution_x, resolution_y))
	else:
		print("SettingsManager: No settings file found, using defaults")
		if not is_embedded:
			apply_settings(false, Vector2i(1920, 1080))

func apply_settings(fullscreen: bool, resolution: Vector2i):
	print("SettingsManager: Applying settings - Fullscreen: ", fullscreen, " Resolution: ", resolution)
	
	if fullscreen:
		print("SettingsManager: Entering fullscreen mode")
		# Set fullscreen mode first
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Let the display server handle the resolution in fullscreen mode
	else:
		print("SettingsManager: Setting windowed mode")
		# First, ensure we're in windowed mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Set the window size
		DisplayServer.window_set_size(resolution)
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_position = (screen_size - resolution) / 2
		DisplayServer.window_set_position(window_position)
		print("SettingsManager: Window positioned at: ", window_position)
	
	# Verify final settings
	print("SettingsManager: Final window mode: ", DisplayServer.window_get_mode())
	print("SettingsManager: Final window size: ", DisplayServer.window_get_size()) 