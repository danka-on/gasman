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
    # Get the current scene
    var current_scene = get_tree().current_scene
    
    # Clean up all objects in pools
    if Engine.has_singleton("PoolSystem"):
        var pool_system = Engine.get_singleton("PoolSystem")
        pool_system.reset_all_pools()
        DebugSettings.debug_print("game_over", "All object pools have been reset")
    
    # Clean up all remaining scene nodes
    if current_scene:
        # Remove all children from the current scene
        for child in current_scene.get_children():
            if child != self:  # Don't remove the game over screen itself
                child.queue_free()
        
        # Clean up any remaining nodes in groups
        for group in ["enemy", "health_pack", "ammo_pack", "gas_pack", "bullet"]:
            var nodes = get_tree().get_nodes_in_group(group)
            for node in nodes:
                if is_instance_valid(node):
                    node.queue_free()
    
    # Change to the main game scene
    get_tree().change_scene_to_file("res://scenes/main.tscn")

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
