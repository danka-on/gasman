extends Control

func _ready():
	# Make sure the mouse is visible and not captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start_button_pressed():
	# Change to the main game scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_options_button_pressed():
	# Load and show the options menu
	var options_menu = load("res://scenes/options_menu.tscn").instantiate()
	add_child(options_menu)

func _on_exit_button_pressed():
	# Exit the game
	get_tree().quit() 