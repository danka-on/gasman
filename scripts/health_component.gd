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
    
    # Get UI references
    health_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/HealthBar")
    heal_border = get_node_or_null("/root/Main/HUD/HealBorder")
    
    # Set up health bar
    if health_bar:
        health_bar.max_value = max_health
        health_bar.value = current_health

func _on_player_took_damage(amount):
    if player.get_node_or_null("DamageSound"):
        player.get_node("DamageSound").play()
    
    # Flash red border effect (could be added here)

func _on_player_healed(amount):
    if player.get_node_or_null("HealSound"):
        player.get_node("HealSound").play()
    
    # Show healing effect
    if heal_border:
        for child in heal_border.get_children():
            child.visible = true
            child.color = Color(0, 1, 0, 1)
        
        get_tree().create_timer(0.5).timeout.connect(func():
            for child in heal_border.get_children():
                child.visible = false
                child.color = Color(0, 1, 0, 0)
        )

func add_health(amount):
    current_health += amount
    current_health = clamp(current_health, 0, max_health)
    
    if health_bar:
        health_bar.value = current_health
