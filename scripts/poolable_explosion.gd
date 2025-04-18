extends Node3D

class_name PoolableExplosion

var _lifetime_timer: SceneTreeTimer = null
var _creation_time: float = 0.0
var _id: int = 0

func _ready():
    _id = get_instance_id()
    _creation_time = Time.get_ticks_msec() / 1000.0
    
    debug_print("Created at time: %.2f" % _creation_time)
    add_to_group("explosion")
    # The reset function will be called when the object is retrieved from the pool
    # We don't automatically reset here, as it might be reset in setup process
    if not _lifetime_timer:
        reset()

## Reset the explosion for reuse from the pool
func reset():
    var reset_time = Time.get_ticks_msec() / 1000.0
    debug_print("Reset at time: %.2f (alive for %.2f seconds)" % 
        [reset_time, reset_time - _creation_time])
    
    # Reset transform
    transform = Transform3D.IDENTITY
    
    # Force visibility and physics processing
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT
    
    # Reset visual effects
    if has_node("Blast"):
        debug_print("Starting particle emission")
        var particles = $Blast
        particles.emitting = true
        
        # Debug verification
        if particles.emitting:
            debug_print("Particle emission confirmed ON", DebugSettings.LogLevel.VERBOSE)
        else:
            debug_print("Particles failed to start!", DebugSettings.LogLevel.ERROR)
            
        # Schedule a deferred check to ensure particles are actually emitting
        call_deferred("_verify_particles_emitting")
    else:
        debug_print("No Blast node found!", DebugSettings.LogLevel.WARNING)
    
    # Play sound effect
    if has_node("BoomSound"):
        debug_print("Playing explosion sound", DebugSettings.LogLevel.VERBOSE)
        $BoomSound.play()
        
        # Debug verification
        if $BoomSound.playing:
            debug_print("Sound playback confirmed", DebugSettings.LogLevel.VERBOSE)
        else:
            debug_print("Sound not playing!", DebugSettings.LogLevel.ERROR)
    else:
        debug_print("No BoomSound node found!", DebugSettings.LogLevel.WARNING)
    
    # Ensure visibility
    visible = true
    
    # Cancel any existing lifetime timer
    if _lifetime_timer != null and _lifetime_timer.time_left > 0:
        debug_print("Cancelling existing timer with %.2f seconds left" % _lifetime_timer.time_left, 
            DebugSettings.LogLevel.VERBOSE)
        if _lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
            _lifetime_timer.timeout.disconnect(_on_lifetime_timeout)
    
    # Start a new lifetime timer
    # Use 0.7 seconds to match effect lifetime + buffer
    _lifetime_timer = get_tree().create_timer(0.7)
    _lifetime_timer.timeout.connect(_on_lifetime_timeout)
    debug_print("Started new lifetime timer (0.7 seconds)", DebugSettings.LogLevel.VERBOSE)

func _on_lifetime_timeout():
    var timeout_time = Time.get_ticks_msec() / 1000.0
    debug_print("Lifetime expired at time: %.2f (lived for %.2f seconds)" % 
        [timeout_time, timeout_time - _creation_time])
    
    # Return to pool instead of queue_free
    if PoolManager.instance != null:
        debug_print("Returning to pool...", DebugSettings.LogLevel.VERBOSE)
        PoolManager.instance.release_object(self)
    else:
        debug_print("PoolManager not available, queue_free instead", DebugSettings.LogLevel.WARNING)
        queue_free()

## Called when the explosion is returned to the pool
## This ensures all timers and ongoing processes are stopped
func prepare_for_pool():
    var prepare_time = Time.get_ticks_msec() / 1000.0
    debug_print("Prepared for pool at time: %.2f (used for %.2f seconds)" % 
        [prepare_time, prepare_time - _creation_time])
    
    # Cancel the lifetime timer if it's still running
    if _lifetime_timer != null and _lifetime_timer.time_left > 0:
        debug_print("Cancelling timer with %.2f seconds left before pool return" % 
            _lifetime_timer.time_left, DebugSettings.LogLevel.VERBOSE)
        if _lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
            _lifetime_timer.timeout.disconnect(_on_lifetime_timeout)
    
    # Hide the explosion while it's in the pool
    visible = false
    debug_print("Visibility set to false for pooling", DebugSettings.LogLevel.VERBOSE)
    
    # Stop any ongoing particles
    if has_node("Blast"):
        debug_print("Stopping particle emission for pooling", DebugSettings.LogLevel.VERBOSE)
        $Blast.emitting = false
    else:
        debug_print("No Blast node found during pool preparation!", DebugSettings.LogLevel.WARNING)

# Debug verification function
func _verify_particles_emitting():
    # This is called deferred to ensure it runs after the current frame
    
    # Skip the check if we're no longer visible or active
    # This prevents warnings during pool initialization and when objects are returned to pool
    if not visible or process_mode == Node.PROCESS_MODE_DISABLED:
        debug_print("DEFERRED CHECK: Skipped (object inactive)", DebugSettings.LogLevel.VERBOSE)
        return
    
    if has_node("Blast"):
        var particles = $Blast
        debug_print("DEFERRED CHECK: Particles emitting: %s" % str(particles.emitting), 
            DebugSettings.LogLevel.VERBOSE)
        
        # Try to force emission again if it's not emitting
        if not particles.emitting:
            debug_print("ATTEMPTING FORCE RESTART OF PARTICLES", DebugSettings.LogLevel.WARNING)
            particles.restart()
            particles.emitting = true
            
            # Create new particles if restart fails
            if not particles.emitting:
                debug_print("CRITICAL: Particles won't emit! Trying alternative approach", 
                    DebugSettings.LogLevel.ERROR)
                
                # Remove the old particles
                particles.queue_free()
                
                # Create new particles
                var new_particles = GPUParticles3D.new()
                new_particles.name = "Blast"
                new_particles.emitting = true
                new_particles.amount = 1000
                new_particles.lifetime = 0.25
                new_particles.one_shot = true
                new_particles.explosiveness = 1.0
                
                # Add to scene
                add_child(new_particles)
                debug_print("Created new particles node", DebugSettings.LogLevel.WARNING)
    else:
        debug_print("DEFERRED CHECK: Blast node not found!", DebugSettings.LogLevel.ERROR)

# Helper function to print debug messages using the central debug system
func debug_print(message: String, level: int = DebugSettings.LogLevel.INFO) -> void:
    # Format the message with the object ID
    var formatted_message = "ID:%d - %s" % [_id, message]
    
    # Send to central debug system
    DebugSettings.debug_print("explosions", formatted_message, level) 
