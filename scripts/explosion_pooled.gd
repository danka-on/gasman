extends Node3D

func _ready():
    reset()
    
func reset():
    # Called when getting from pool
    if visible:
        return
        
    visible = true
    $Blast.emitting = true
    $BoomSound.play()
    
    # Return to pool after effect completes
    get_tree().create_timer(0.7).timeout.connect(func():
        return_to_pool()
    )

func return_to_pool():
    if not visible:
        return
        
    visible = false
    $Blast.emitting = false
    
    var object_pool = get_node_or_null("/root/ObjectPool")
    if object_pool:
        object_pool.return_object(self)
