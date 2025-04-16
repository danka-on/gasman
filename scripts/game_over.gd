extends Control

var score = 0
var kills = 0

func _ready():
    # Make sure the game is unpaused when showing game over
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    if $VBoxContainer/RestartButton:
        $VBoxContainer/RestartButton.connect("pressed", _on_restart_button_pressed)
    if $VBoxContainer/MenuButton:
        $VBoxContainer/MenuButton.connect("pressed", _on_menu_button_pressed)
    update_display()

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        pass

func _on_restart_button_pressed():
    # Reload the current scene
    get_tree().reload_current_scene()

func _on_menu_button_pressed():
    # Change to the start screen scene
    get_tree().change_scene_to_file("res://scenes/start_screen.tscn")

func set_score_and_kills(player_score: int, player_kills: int):
    score = player_score
    kills = player_kills
    if is_node_ready(): # If _ready() has run
        update_display()

func update_display():
    $VBoxContainer/ScoreLabel.text = "Score: " + str(score)
    $VBoxContainer/KillsLabel.text = "Kills: " + str(kills)
