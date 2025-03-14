extends Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Show mouse cursor
	if $RestartButton:
		$RestartButton.connect("pressed", _on_restart_button_pressed)

func _on_restart_button_pressed():
	get_tree().change_scene_to_file("res://Main.tscn") # Restart game
