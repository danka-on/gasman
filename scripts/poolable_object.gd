# poolable_object.gd - New file
extends Node
class_name PoolableObject

# Override this in inheriting classes
func reset():
    visible = true
    
# Call this when you're done with the object
func return_to_pool():
    visible = false
    
    # Short delay to ensure physics is resolved
    get_tree().create_timer(0.1).timeout.connect(func():
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool and is_instance_valid(self):
            object_pool.return_object(self)
    )
