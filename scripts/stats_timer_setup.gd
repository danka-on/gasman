extends Node

# This script should be added to the main scene to set up statistics collection

@onready var player = get_node("/root/Player")  # Adjust the path as necessary

func _ready():
    # Check if we're in the main scene
    var parent = get_parent()
    if not parent or not parent.has_method("spawn_enemy"):
        DebugSettings.debug_print("stats_setup", "This script should only be attached to the main scene")
        return
    
    DebugSettings.debug_print("stats_setup", "Setting up statistics collection...")
    
    # Create the stats timer if it doesn't exist
    if not parent.has_node("StatsTimer"):
        var stats_timer = Timer.new()
        stats_timer.name = "StatsTimer"
        stats_timer.wait_time = 10.0
        stats_timer.autostart = true
        
        # Connect to the _on_stats_timer_timeout method in the main script
        if parent.has_method("_on_stats_timer_timeout"):
            stats_timer.timeout.connect(parent._on_stats_timer_timeout)
        else:
            DebugSettings.debug_print("stats_setup", "WARNING: Main script doesn't have _on_stats_timer_timeout method", DebugSettings.LogLevel.WARNING)
            
        # Add the timer to the main scene
        parent.add_child(stats_timer)
        DebugSettings.debug_print("stats_setup", "Added StatsTimer node with interval: %.1f seconds" % stats_timer.wait_time)
    else:
        DebugSettings.debug_print("stats_setup", "StatsTimer already exists")
    
    # Enable enemy debugging
    if has_node("/root/DebugSettings") and player and player.debugging_mode:
        DebugSettings.toggle_debug("enemies", true)
        DebugSettings.toggle_debug("pools", true)
        DebugSettings.debug_print("stats_setup", "Enabled enemy and pool debugging")
    
    # Log status
    DebugSettings.debug_print("stats_setup", "Statistics collection setup complete") 