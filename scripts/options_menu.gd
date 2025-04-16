extends Control

var resolutions = [
    Vector2i(1024, 768),
    Vector2i(1280, 720),
    Vector2i(1366, 768),
    Vector2i(1600, 900),
    Vector2i(1920, 1080),
    Vector2i(2560, 1440),
    Vector2i(3840, 2160)
]

var pending_settings = {
    "fullscreen": false,
    "resolution": Vector2i(1920, 1080)
}

var is_embedded = false

func _ready():
    is_embedded = Engine.is_editor_hint()
    print("Options: Running in editor: ", is_embedded)
    
    # Load current settings
    var config = ConfigFile.new()
    var err = config.load("user://settings.cfg")
    if err == OK:
        pending_settings.fullscreen = config.get_value("video", "fullscreen", false)
        var res_x = config.get_value("video", "resolution_x", 1920)
        var res_y = config.get_value("video", "resolution_y", 1080)
        pending_settings.resolution = Vector2i(res_x, res_y)
        print("Options: Loaded settings - Fullscreen: ", pending_settings.fullscreen, " Resolution: ", pending_settings.resolution)
    
    # Set initial values
    $VBoxContainer/VideoSettings/FullscreenCheckBox.button_pressed = pending_settings.fullscreen
    
    # Only disable fullscreen in editor
    if is_embedded:
        $VBoxContainer/VideoSettings/FullscreenCheckBox.disabled = true
        $VBoxContainer/VideoSettings/FullscreenCheckBox.tooltip_text = "Fullscreen is not available in the editor"
    else:
        $VBoxContainer/VideoSettings/FullscreenCheckBox.disabled = false
        $VBoxContainer/VideoSettings/FullscreenCheckBox.tooltip_text = ""
    
    # Populate resolution dropdown
    var resolution_dropdown = $VBoxContainer/VideoSettings/ResolutionDropdown
    resolution_dropdown.clear()
    for res in resolutions:
        resolution_dropdown.add_item("%dx%d" % [res.x, res.y])
    
    # Set current resolution in dropdown
    for i in range(resolutions.size()):
        if resolutions[i] == pending_settings.resolution:
            resolution_dropdown.selected = i
            break

func _on_back_button_pressed():
    queue_free()

func _on_fullscreen_check_box_toggled(button_pressed):
    pending_settings.fullscreen = button_pressed
    print("Options: Pending fullscreen setting changed to ", button_pressed)
    
    # If not in editor, apply settings immediately for testing
    if not is_embedded:
        get_node("/root/SettingsManager").apply_settings(
            pending_settings.fullscreen,
            pending_settings.resolution
        )

func _on_resolution_dropdown_item_selected(index):
    pending_settings.resolution = resolutions[index]
    print("Options: Pending resolution changed to ", resolutions[index])
    
    # If not in editor, apply settings immediately for testing
    if not is_embedded:
        get_node("/root/SettingsManager").apply_settings(
            pending_settings.fullscreen,
            pending_settings.resolution
        )

func _on_confirm_button_pressed():
    print("Options: Saving settings - Fullscreen: ", pending_settings.fullscreen, " Resolution: ", pending_settings.resolution)
    
    # Save settings to a config file
    var config = ConfigFile.new()
    config.set_value("video", "fullscreen", pending_settings.fullscreen)
    config.set_value("video", "resolution_x", pending_settings.resolution.x)
    config.set_value("video", "resolution_y", pending_settings.resolution.y)
    
    var err = config.save("user://settings.cfg")
    if err == OK:
        print("Options: Settings saved successfully")
        if is_embedded:
            # Show a message that settings will take effect when running the game
            $VBoxContainer/MessageLabel.text = "Settings saved! These changes will take effect when you run the game outside the editor."
            $VBoxContainer/MessageLabel.show()
            await get_tree().create_timer(3.0).timeout
            $VBoxContainer/MessageLabel.hide()
        else:
            # Apply settings immediately if not in editor
            get_node("/root/SettingsManager").apply_settings(
                pending_settings.fullscreen,
                pending_settings.resolution
            )
    else:
        print("Options: Error saving settings: ", err)
        $VBoxContainer/MessageLabel.text = "Error saving settings! Please try again."
        $VBoxContainer/MessageLabel.show()
        await get_tree().create_timer(3.0).timeout
        $VBoxContainer/MessageLabel.hide()
        return  # Don't close the menu if saving failed
    
    # Close the options menu
    queue_free() 
