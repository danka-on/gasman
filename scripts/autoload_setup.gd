# autoload_setup.gd
# 
# Steps to set this up in your project:
# 1. Save this file in your project
# 2. Go to Project > Project Settings > AutoLoad
# 3. Add the ObjectPool.gd script and set its name to "ObjectPool"
# 4. Click Add and ensure it's set to Singleton
#
# The object pool will now be globally accessible in your project!
#
# Example usage in any script:
# var bullet = get_node("/root/ObjectPool").get_object("res://bullet.tscn")

# This script helps set up autoloads programmatically
extends Node

func _ready():
    # Register ObjectPool as autoload if not already registered
    var autoloads = ProjectSettings.get_setting("autoload/ObjectPool")
    if not autoloads:
        # Set ObjectPool.gd as autoload
        ProjectSettings.set_setting("autoload/ObjectPool", "*res://scripts/object_pool.gd")
        # Save project settings
        ProjectSettings.save()
        print("ObjectPool autoload registered!")
    else:
        print("ObjectPool already registered as autoload")
