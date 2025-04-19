extends Node3D

class_name DamageNumber

@export var text: String = "0"
@export var color: Color = Color(1, 1, 1)  # Default white color
@export var duration: float = 1.0
@export var float_height: float = 2.0
@export var scale_start: float = 0.5
@export var scale_end: float = 1.0
@export var spawn_height_offset: float = 0.0  # Added exportable spawn height offset
@export var text_size: int = 32  # Added text size variable

@onready var label: Label3D = $Label3D
var player = null
var active = false
var tween = null
var returning_to_pool = false  # Flag to prevent recursive pool returns
var being_reset_by_pool = false  # Flag to indicate reset is happening from pool system
var pool_return_initiated = false  # New flag to track if we started the pool return process

func _ready():
    # Find player on first instantiation
    if player == null:
        player = get_node_or_null("/root/Main/Player")
    # Initialize but don't start animation yet
    reset()
    print("[DAMAGE_NUMBER] Initialized: ID " + str(get_instance_id()))

# Function called to display the damage number
func display():
    if active:
        # Already displaying, cancel first
        if tween and tween.is_valid():
            tween.kill()
    
    active = true
    visible = true
    
    # Set initial properties
    label.text = text
    label.modulate = color  # Set the color on the Label3D
    label.outline_modulate = Color(0, 0, 0, 1)  # Black outline
    label.scale = Vector3(scale_start, scale_start, scale_start)
    label.font_size = text_size  # Apply the text size
    label.modulate.a = 1.0 # Reset alpha
    
    # Log the display
    print("[DAMAGE_NUMBER] Displaying: ID " + str(get_instance_id()) + ", Value: " + text)
    
    # Create the animation
    tween = create_tween()
    tween.set_parallel(true)
    
    # Float upward from the spawn position
    tween.tween_property(self, "position:y", position.y + float_height, duration)
    
    # Scale up
    tween.tween_property(label, "scale", Vector3(scale_end, scale_end, scale_end), duration * 0.2)
    
    # Fade out
    tween.tween_property(label, "modulate:a", 0.0, duration)
    
    # Wait for animation to complete and then return to pool
    await tween.finished
    print("[DAMAGE_NUMBER] Animation finished: ID " + str(get_instance_id()))
    prepare_for_pool()

func _process(_delta):
    if active and is_instance_valid(player):
        # Get the player's camera
        var camera = player.get_node("Head/Camera3D")
        if is_instance_valid(camera):
            # Make the label look at the camera
            look_at(camera.global_transform.origin)
            # Rotate 180 degrees around Y axis to face the camera
            rotate_y(PI)

# Reset the damage number for reuse
func reset():
    # Check if we're already being reset by the pool system
    if being_reset_by_pool:
        # Just reset our flags and return
        being_reset_by_pool = false
        returning_to_pool = false
        print("[DAMAGE_NUMBER] Reset during pool return: ID " + str(get_instance_id()))
        return
    
    # Reset all states
    active = false
    visible = false
    
    # Find player if needed
    if player == null:
        player = get_node_or_null("/root/Main/Player")
    
    # Reset label properties
    if label:
        label.text = "0"
        label.modulate = Color(1, 1, 1, 1)
        label.scale = Vector3(1, 1, 1)
    
    # Reset all flags
    returning_to_pool = false
    pool_return_initiated = false
    
    print("[DAMAGE_NUMBER] Reset: ID " + str(get_instance_id()))

# Called when returning to the pool
func prepare_for_pool():
    # If we already went through this process once and are being called by the pool system
    if pool_return_initiated:
        print("[DAMAGE_NUMBER] Pool system calling prepare_for_pool, already handled: ID " + str(get_instance_id()))
        return
    
    # If we're already in the returning_to_pool state, prevent recursion
    if returning_to_pool:
        print("[DAMAGE_NUMBER] Already returning to pool, skipping duplicate call: ID " + str(get_instance_id()))
        return
    
    # Set flags to track that we initiated the pool return process
    returning_to_pool = true
    pool_return_initiated = true
    
    print("[DAMAGE_NUMBER] Preparing for pool: ID " + str(get_instance_id()))
    
    active = false
    visible = false
    
    if tween and tween.is_valid():
        tween.kill()
        print("[DAMAGE_NUMBER] Cancelled active tween")
    
    # Log to debug system if available
    if Engine.has_singleton("DebugSettings"):
        var debug = Engine.get_singleton("DebugSettings")
        if debug and debug.has_method("log_debug") and debug.has_method("is_debug_enabled"):
            if debug.is_debug_enabled("pools"):
                debug.log_debug("pools", "DamageNumber ID:" + str(get_instance_id()) + " returning to pool")
    
    # First remove from parent if we have one
    if get_parent():
        print("[DAMAGE_NUMBER] Removing from parent: ID " + str(get_instance_id()))
        get_parent().remove_child(self)
    
    # Access PoolSystem either as singleton or as direct reference
    var pool_system = null
    if Engine.has_singleton("PoolSystem"):
        pool_system = Engine.get_singleton("PoolSystem")
        print("[DAMAGE_NUMBER] Found PoolSystem via singleton: ID " + str(get_instance_id()))
    elif is_instance_valid(PoolSystem):
        pool_system = PoolSystem
        print("[DAMAGE_NUMBER] Found PoolSystem via global: ID " + str(get_instance_id()))
    
    if pool_system:
        if pool_system.has_pool("damage_numbers"):
            print("[DAMAGE_NUMBER] Releasing to damage_numbers pool: ID " + str(get_instance_id()))
            # Set flag to indicate pool system is about to reset us
            being_reset_by_pool = true
            pool_system.release_object(self)
        else:
            print("[DAMAGE_NUMBER] No damage_numbers pool found, queue_freeing: ID " + str(get_instance_id()))
            queue_free()
    else:
        print("[DAMAGE_NUMBER] PoolSystem not available by any method, queue_freeing: ID " + str(get_instance_id()))
        queue_free()
