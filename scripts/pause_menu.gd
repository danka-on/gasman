extends Control

func _ready():
    # Hide the pause menu initially
    hide()
    
    # Connect the ESC key to toggle pause
    set_process_unhandled_key_input(true)
    
    # Make sure we can process input even when paused
    process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event):
    if event.is_action_pressed("ui_cancel"):  # ESC key
        toggle_pause()
        # Accept the event to prevent it from being processed by other nodes
        get_viewport().set_input_as_handled()

func toggle_pause():
    if get_tree().paused:
        # Unpause the game
        get_tree().paused = false
        hide()
    else:
        # Pause the game
        get_tree().paused = true
        show() 