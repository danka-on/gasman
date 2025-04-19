extends Label

class_name HudDamageNumber

@export var damage_text: String = "0"
@export var color: Color = Color(1, 0, 0)  # Default red color
@export var duration: float = 1.0
@export var float_distance: float = 50.0  # How far to float up
@export var text_size: int = 24

var tween = null
var active = false

func _ready():
    print("[HUD_DAMAGE] Initialized: ID " + str(get_instance_id()))
    reset()
    # Don't start animation in _ready, wait for display call

# Function to display the damage number
func display():
    if active:
        # Already displaying, cancel first
        if tween and tween.is_valid():
            tween.kill()
    
    active = true
    visible = true
    
    # Set initial properties
    self.text = damage_text
    add_theme_color_override("font_color", color)
    add_theme_font_size_override("font_size", text_size)
    
    print("[HUD_DAMAGE] Displaying: ID " + str(get_instance_id()) + ", Value: " + damage_text)
    
    # Create the animation
    tween = create_tween()
    tween.set_parallel(true)
    
    # Float upward
    tween.tween_property(self, "position:y", position.y - float_distance, duration)
    
    # Fade out
    tween.tween_property(self, "modulate:a", 0.0, duration)
    
    # Wait for animation to complete and then free the node
    await tween.finished
    print("[HUD_DAMAGE] Animation finished: ID " + str(get_instance_id()))
    prepare_for_pool()

# Reset the damage number for reuse
func reset():
    # Reset state
    active = false
    visible = false
    position = Vector2.ZERO
    
    # Reset label properties
    self.text = "0"
    modulate = Color(1, 1, 1, 1)
    
    print("[HUD_DAMAGE] Reset: ID " + str(get_instance_id()))

# Called when returning to the pool
func prepare_for_pool():
    print("[HUD_DAMAGE] Preparing for pool: ID " + str(get_instance_id()))
    
    active = false
    visible = false
    
    if tween and tween.is_valid():
        tween.kill()
        print("[HUD_DAMAGE] Cancelled active tween")
    
    # First remove from parent if we have one
    if get_parent():
        print("[HUD_DAMAGE] Removing from parent")
        get_parent().remove_child(self)
    
    # Get PoolSystem directly from singleton reference
    # Then try to return to pool using direct reference to singleton
    if Engine.has_singleton("PoolSystem") or is_instance_valid(PoolSystem):
        if PoolSystem.has_pool("hud_damage_numbers"):
            print("[HUD_DAMAGE] Releasing to PoolSystem: ID " + str(get_instance_id()))
            # Ensure we're properly removed from our parent first
            if get_parent():
                get_parent().remove_child(self)
            PoolSystem.release_object(self)
        else:
            print("[HUD_DAMAGE] No pool for HUD damage - queue_free: ID " + str(get_instance_id()))
            queue_free()
    else:
        print("[HUD_DAMAGE] PoolSystem not found or invalid - queue_free: ID " + str(get_instance_id()))
        queue_free() 
