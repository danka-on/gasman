extends Node

# This script should be added to the main scene to set up statistics collection

func _ready():
    # Check if we're in the main scene
    var parent = get_parent()
    if not parent or not parent.has_method("spawn_enemy"):
        print("[STATS_SETUP] This script should only be attached to the main scene")
        return
    
    print("[STATS_SETUP] Setting up statistics collection...")
    
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
            print("[STATS_SETUP] WARNING: Main script doesn't have _on_stats_timer_timeout method")
            
        # Add the timer to the main scene
        parent.add_child(stats_timer)
        print("[STATS_SETUP] Added StatsTimer node with interval: %.1f seconds" % stats_timer.wait_time)
    else:
        print("[STATS_SETUP] StatsTimer already exists")
    
    # Enable enemy debugging
    if has_node("/root/DebugSettings"):
        DebugSettings.toggle_debug("enemies", true)
        DebugSettings.toggle_debug("pools", true)
        print("[STATS_SETUP] Enabled enemy and pool debugging")
    
    # Log status
    print("[STATS_SETUP] Statistics collection setup complete") 