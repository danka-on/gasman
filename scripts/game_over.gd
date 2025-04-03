# game_over.gd - Improved version
extends Control

var score : int = 0
var kills : int = 0

func _ready():
    # Make sure mouse is visible
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    
    # Connect button signal
    if $RestartButton and not $RestartButton.pressed.is_connected(_on_restart_button_pressed):
        $RestartButton.pressed.connect(_on_restart_button_pressed)
    
    update_display()

func _on_restart_button_pressed():
    # Change scene with error handling
    var err = get_tree().change_scene_to_file("res://scenes/main.tscn")
    if err != OK:
        push_error("Failed to change to main scene: " + str(err))

func set_score_and_kills(new_score: int, new_kills: int):
    score = new_score
    kills = new_kills
    if is_node_ready():
        update_display()

func update_display():
    if $ScoreLabel:
        $ScoreLabel.text = "Score: " + str(score)
    if $KillsLabel:
        $KillsLabel.text = "Kills: " + str(kills)
