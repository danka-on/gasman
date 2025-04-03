# explosion_pooled.gd - Updated version
extends Node3D

func _ready():
    reset()
    
func reset():
    # Called when getting from pool
    visible = true
    $Blast.emitting = true
    $BoomSound.play()
    
    # Return to pool after effect completes
    get_tree().create_timer(0.7).timeout.connect(func():
        if is_instance_valid(self):
            return_to_pool()
    )

func return_to_pool():
    if not visible or not is_instance_valid(self):
        return
        
    visible = false
    $Blast.emitting = false
    
    var object_pool = get_node_or_null("/root/ObjectPool")
    if object_pool:
        object_pool.return_object(self)
