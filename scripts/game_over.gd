extends Control

var score : int = 0
var kills : int = 0

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    if $RestartButton:
        $RestartButton.connect("pressed", _on_restart_button_pressed)
    update_display()

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        pass

func _on_restart_button_pressed():
    
    get_tree().change_scene_to_file("res://scenes/Main.tscn")

func set_score_and_kills(new_score: int, new_kills: int):
    score = new_score
    kills = new_kills
    if is_node_ready(): # If _ready() has run
        update_display()

func update_display():
    $ScoreLabel.text = "Score: " + str(score)
    $KillsLabel.text = "Kills: " + str(kills)
