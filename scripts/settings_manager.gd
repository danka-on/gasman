extends Node

var is_embedded = false

func _ready():
	DebugSettings.debug_print("settings_manager", "Loading settings...")
	# Check if we're running in an embedded environment
	is_embedded = Engine.is_editor_hint()
	DebugSettings.debug_print("settings_manager", "Running in editor: %s" % str(is_embedded))
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		DebugSettings.debug_print("settings_manager", "Successfully loaded settings file")
		var fullscreen = config.get_value("video", "fullscreen", false)
		var resolution_x = config.get_value("video", "resolution_x", 1920)
		var resolution_y = config.get_value("video", "resolution_y", 1080)
		
		DebugSettings.debug_print("settings_manager", "Loaded settings - Fullscreen: %s Resolution: %dx%d" % [str(fullscreen), resolution_x, resolution_y])
		
		if not is_embedded:
			apply_settings(fullscreen, Vector2i(resolution_x, resolution_y))
	else:
		DebugSettings.debug_print("settings_manager", "No settings file found, using defaults")
		if not is_embedded:
			apply_settings(false, Vector2i(1920, 1080))

func apply_settings(fullscreen: bool, resolution: Vector2i):
	DebugSettings.debug_print("settings_manager", "Applying settings - Fullscreen: %s Resolution: %s" % [str(fullscreen), str(resolution)])
	
	if fullscreen:
		DebugSettings.debug_print("settings_manager", "Entering fullscreen mode")
		# Set fullscreen mode first
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Let the display server handle the resolution in fullscreen mode
	else:
		DebugSettings.debug_print("settings_manager", "Setting windowed mode")
		# First, ensure we're in windowed mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Set the window size
		DisplayServer.window_set_size(resolution)
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_position = (screen_size - resolution) / 2
		DisplayServer.window_set_position(window_position)
		DebugSettings.debug_print("settings_manager", "Window positioned at: %s" % str(window_position))
	
	# Verify final settings
	DebugSettings.debug_print("settings_manager", "Final window mode: %s" % str(DisplayServer.window_get_mode()))
	DebugSettings.debug_print("settings_manager", "Final window size: %s" % str(DisplayServer.window_get_size())) 