@tool
extends EditorScript

# This is a utility script to create the PoolableGasCloud.tscn scene
# Run this from the Godot editor using the "Run Current Script" button

func _run():
    # Indicate start
    print("Creating PoolableGasCloud.tscn from GasCloud.tscn")
    
    # Load the original scene
    var gas_cloud_scene = load("res://scenes/gas_cloud.tscn")
    if not gas_cloud_scene:
        print("ERROR: Failed to load gas_cloud.tscn!")
        return
    
    # Instance the scene to modify
    var gas_cloud_instance = gas_cloud_scene.instantiate()
    if not gas_cloud_instance:
        print("ERROR: Failed to instantiate gas_cloud.tscn!")
        return
    
    print("Successfully loaded and instantiated gas_cloud.tscn")
    
    # Load the poolable gas cloud script
    var poolable_script = load("res://scripts/poolable_gas_cloud.gd")
    if not poolable_script:
        print("ERROR: Failed to load poolable_gas_cloud.gd!")
        return
    
    # Apply the poolable script to the scene
    gas_cloud_instance.set_script(poolable_script)
    print("Applied poolable_gas_cloud.gd script to the scene")
    
    # Save as new scene
    var new_scene = PackedScene.new()
    var result = new_scene.pack(gas_cloud_instance)
    if result != OK:
        print("ERROR: Failed to pack scene! Error code: " + str(result))
        return
    
    result = ResourceSaver.save(new_scene, "res://scenes/PoolableGasCloud.tscn")
    if result != OK:
        print("ERROR: Failed to save scene! Error code: " + str(result))
        return
    
    print("Successfully created res://scenes/PoolableGasCloud.tscn!")
    print("IMPORTANT: You may need to adjust the scene in the editor to ensure all properties are correctly set.")
    
    # Cleanup
    gas_cloud_instance.queue_free() 
