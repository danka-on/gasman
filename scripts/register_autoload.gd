@tool
extends EditorScript

func _run():
    # Check if the autoloads already exist
    var object_pool_exists = ProjectSettings.get_setting("autoload/ObjectPool")
    var logger_exists = ProjectSettings.get_setting("autoload/Logger")
    
    if not object_pool_exists:
        ProjectSettings.set_setting("autoload/ObjectPool", "*res://scripts/object_pool.gd")
        print("Registered ObjectPool autoload")
        
    if not logger_exists:
        ProjectSettings.set_setting("autoload/Logger", "*res://scripts/logger.gd")
        print("Registered Logger autoload")
        
    # Save settings
    ProjectSettings.save()
    print("Autoload registration complete")
