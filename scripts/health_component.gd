extends Node

var player = null  # Will reference the parent player node

# Health variables
@export var max_health : float = 100.0
var current_health : float = max_health

# References for UI effects
var health_bar = null
var heal_border = null

func _ready():
    current_health = max_health
    
    # Get UI references - call deferred to ensure scene is ready
    call_deferred("update_ui_references")

func update_ui_references():
    # Get UI references safely
    health_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/HealthBar")
    heal_border = get_node_or_null("/root/Main/HUD/HealBorder")
    
    # Set up health bar
    if health_bar:
        health_bar.max_value = max_health
        health_bar.value = current_health

func _on_player_took_damage(amount):
    if not is_instance_valid(player):
        return
        
    if player.get_node_or_null("DamageSound"):
        player.get_node("DamageSound").play()
    
    # Update UI
    if health_bar:
        health_bar.value = current_health
    
    # Flash red border effect (could be added here)
    # Example of how you might implement a damage flash:
    # var damage_flash = get_node_or_null("/root/Main/HUD/DamageFlash")
    # if damage_flash:
    #     damage_flash.modulate = Color(1, 0, 0, 0.3)  # Red with transparency
    #     damage_flash.visible = true
    #     get_tree().create_timer(0.2).timeout.connect(func():
    #         damage_flash.visible = false
    #     )

func _on_player_healed(amount):
    if not is_instance_valid(player):
        return
        
    if player.get_node_or_null("HealSound"):
        player.get_node("HealSound").play()
    
    # Show healing effect
    if heal_border:
        for child in heal_border.get_children():
            child.visible = true
            child.color = Color(0, 1, 0, 0.3) # Semi-transparent green
        
        # Auto-hide after effect
        get_tree().create_timer(0.5).timeout.connect(func():
            if is_instance_valid(heal_border):
                for child in heal_border.get_children():
                    child.visible = false
        )
    
    # Update UI
    if health_bar:
        health_bar.value = current_health

func add_health(amount):
    if not is_instance_valid(player):
        return
        
    current_health += amount
    current_health = clamp(current_health, 0, max_health)
    
    if health_bar:
        health_bar.value = current_health
