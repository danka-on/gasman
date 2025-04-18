extends Node

## Debug settings autoload for centralized debug configuration
## Add this to Project > Project Settings > Autoload to make it accessible globally

# Master debug flag - when false, all debugging is disabled regardless of individual settings
var debug_enabled: bool = true

# System-specific debug flags
var debug_pools: bool = false       # Object pooling system
var debug_explosions: bool = false  # Explosion effects
var debug_bullets: bool = false     # Bullet behavior
var debug_enemies: bool = false     # Enemy AI and behavior
var debug_player: bool = false      # Player mechanics
var debug_gas: bool = false         # Gas cloud system
var debug_ui: bool = false          # UI elements
var debug_performance: bool = false # Performance monitoring

# Log levels
enum LogLevel {VERBOSE, INFO, WARNING, ERROR, NONE}
var log_level: LogLevel = LogLevel.INFO

# Add enemies to our debug categories
var _debug_categories = {
    "general": true,  # General debugging (always on)
    "pools": false,   # Pool system debugging
    "explosions": false, # Explosion-specific debugging
    "gas_clouds": false, # Gas cloud debugging
    "enemies": false,  # Enemy debugging
    "particles": false, # Particle system debugging
    "performance": false # Performance monitoring
}

func _ready() -> void:
    print("Debug settings initialized")
    
    # Load debug settings from configuration if available
    # This allows toggling debug in production builds without recompiling
    if FileAccess.file_exists("user://debug_settings.cfg"):
        load_settings()
    else:
        save_settings() # Create default settings file

## Print debug message if the specified system's debugging is enabled
func debug_print(system: String, message: String, level: LogLevel = LogLevel.INFO) -> void:
    if not debug_enabled:
        return
        
    # Skip if below current log level
    if level < log_level:
        return
        
    # Check specific system flag
    var system_enabled = false
    match system:
        "pools": system_enabled = debug_pools
        "explosions": system_enabled = debug_explosions
        "bullets": system_enabled = debug_bullets
        "enemies": system_enabled = debug_enemies
        "player": system_enabled = debug_player
        "gas": system_enabled = debug_gas
        "ui": system_enabled = debug_ui
        "performance": system_enabled = debug_performance
        _: system_enabled = true # Default to enabled for unknown systems
    
    if system_enabled:
        var prefix = ""
        match level:
            LogLevel.VERBOSE: prefix = "[VERBOSE]"
            LogLevel.INFO: prefix = "[INFO]"
            LogLevel.WARNING: prefix = "[WARNING]"
            LogLevel.ERROR: prefix = "[ERROR]"
        
        print("[%s]%s %s" % [system.to_upper(), prefix, message])

## Toggle a specific debug system
func toggle_debug(system: String, enabled: bool = true) -> void:
    # Update our categories dictionary
    if _debug_categories.has(system):
        _debug_categories[system] = enabled
    
    # Also update legacy variables for backward compatibility
    match system:
        "all": debug_enabled = enabled
        "pools": debug_pools = enabled
        "explosions": debug_explosions = enabled
        "bullets": debug_bullets = enabled
        "enemies": debug_enemies = enabled
        "player": debug_player = enabled
        "gas": debug_gas = enabled
        "ui": debug_ui = enabled
        "performance": debug_performance = enabled
    
    save_settings()
    print("Debug for %s set to: %s" % [system, str(enabled)])

## Enable all debugging systems
func enable_all_debugging() -> void:
    debug_enabled = true
    debug_pools = true
    debug_explosions = true
    debug_bullets = true
    debug_enemies = true
    debug_player = true
    debug_gas = true
    debug_ui = true
    debug_performance = true
    
    save_settings()
    print("All debugging systems enabled")

## Disable all debugging systems
func disable_all_debugging() -> void:
    debug_enabled = false
    
    save_settings()
    print("All debugging systems disabled")

## Save current debug settings to file
func save_settings() -> void:
    var config = ConfigFile.new()
    
    config.set_value("debug", "enabled", debug_enabled)
    config.set_value("debug", "pools", debug_pools)
    config.set_value("debug", "explosions", debug_explosions)
    config.set_value("debug", "bullets", debug_bullets)
    config.set_value("debug", "enemies", debug_enemies)
    config.set_value("debug", "player", debug_player)
    config.set_value("debug", "gas", debug_gas)
    config.set_value("debug", "ui", debug_ui)
    config.set_value("debug", "performance", debug_performance)
    config.set_value("debug", "log_level", log_level)
    
    var err = config.save("user://debug_settings.cfg")
    if err != OK:
        print("Error saving debug settings: " + str(err))

## Load debug settings from file
func load_settings() -> void:
    var config = ConfigFile.new()
    var err = config.load("user://debug_settings.cfg")
    
    if err != OK:
        print("Error loading debug settings: " + str(err))
        return
    
    debug_enabled = config.get_value("debug", "enabled", debug_enabled)
    debug_pools = config.get_value("debug", "pools", debug_pools)
    debug_explosions = config.get_value("debug", "explosions", debug_explosions)
    debug_bullets = config.get_value("debug", "bullets", debug_bullets)
    debug_enemies = config.get_value("debug", "enemies", debug_enemies)
    debug_player = config.get_value("debug", "player", debug_player)
    debug_gas = config.get_value("debug", "gas", debug_gas)
    debug_ui = config.get_value("debug", "ui", debug_ui)
    debug_performance = config.get_value("debug", "performance", debug_performance)
    log_level = config.get_value("debug", "log_level", log_level)
    
    print("Debug settings loaded from file")

# Log enemy statistics for multiple enemies
func log_enemy_stats(enemies: Array) -> void:
    if not is_debug_enabled("enemies") and not is_debug_enabled("pools"):
        return
        
    var active_count = 0
    var total_retrievals = 0
    var total_active_time = 0.0
    var max_retrievals = 0
    var max_retrieval_id = -1
    
    log_info("enemies", "===== ENEMY POOL STATISTICS =====")
    
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.has_method("report_pool_stats"):
            active_count += 1
            
            # Get stats from the enemy
            var stats = enemy.report_pool_stats()
            log_debug("enemies", stats)
            
            # Track aggregate statistics
            total_retrievals += enemy._pool_retrieval_count
            total_active_time += enemy._total_active_time
            
            # Track which enemy has been reused the most
            if enemy._pool_retrieval_count > max_retrievals:
                max_retrievals = enemy._pool_retrieval_count
                max_retrieval_id = enemy.get_instance_id()
                
    # Log summary
    log_info("enemies", "--- Summary ---")
    log_info("enemies", "Active enemies: %d" % active_count)
    log_info("enemies", "Total pool retrievals: %d" % total_retrievals)
    log_info("enemies", "Total active time: %.2f seconds" % total_active_time)
    
    if active_count > 0:
        log_info("enemies", "Average retrievals per enemy: %.2f" % (float(total_retrievals) / active_count))
        log_info("enemies", "Average active time per enemy: %.2f seconds" % (total_active_time / active_count))
    
    if max_retrieval_id >= 0:
        log_info("enemies", "Most reused enemy ID: %d (used %d times)" % [max_retrieval_id, max_retrievals])
        
    log_info("enemies", "=================================")

## Check if debugging is enabled for a specific category
func is_debug_enabled(category: String) -> bool:
    if not debug_enabled:
        return false
        
    if _debug_categories.has(category):
        return _debug_categories[category]
        
    # Fallback to legacy system
    match category:
        "all": return debug_enabled
        "pools": return debug_pools
        "explosions": return debug_explosions
        "bullets": return debug_bullets
        "enemies": return debug_enemies
        "player": return debug_player
        "gas": return debug_gas
        "ui": return debug_ui
        "performance": return debug_performance
    
    return false

## Log a debug level message (most detailed)
func log_debug(category: String, message: String) -> void:
    debug_print(category, message, LogLevel.VERBOSE)
    
## Log an info level message (standard)
func log_info(category: String, message: String) -> void:
    debug_print(category, message, LogLevel.INFO)
    
## Log a warning level message
func log_warning(category: String, message: String) -> void:
    debug_print(category, message, LogLevel.WARNING)
    
## Log an error level message
func log_error(category: String, message: String) -> void:
    debug_print(category, message, LogLevel.ERROR) 
