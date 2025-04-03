# bullet_pooled.gd - Updated version
extends Area3D

@export var speed : float = 20.0
var velocity : Vector3
@export var hit_effect_scene : String = "res://scenes/hit_effect.tscn"

func _ready():
    collision_layer = 3 # Bullets
    collision_mask = 2 # Hits enemies
    reset()

func reset():
    # Reset bullet state (called when getting from pool)
    visible = true
    monitoring = true
    monitorable = true
    $Lifetime.start()
    velocity = Vector3.ZERO

func _physics_process(delta):
    if visible:
        global_transform.origin += velocity * delta

func _on_area_entered(area):
    if not visible or not is_instance_valid(area):
        return
        
    if area.name == "Hitbox" and area.get_parent().has_method("take_damage") and area.get_parent() != get_tree().get_first_node_in_group("player"):
        area.get_parent().take_damage(10.0)
        
        # Get hit effect from pool
        var object_pool = get_node("/root/ObjectPool")
        if object_pool:
            var hit_effect = object_pool.get_object(hit_effect_scene)
            hit_effect.global_transform.origin = global_transform.origin
            hit_effect.emitting = true
    
    return_to_pool()

func _on_lifetime_timeout():
    return_to_pool()

func return_to_pool():
    # Avoid double returns
    if not visible or not is_instance_valid(self):
        return
        
    # Stop interacting with the world
    monitoring = false
    monitorable = false
    visible = false
    
    # Return to object pool after a short delay
    get_tree().create_timer(0.1).timeout.connect(func():
        if is_instance_valid(self):
            var object_pool = get_node_or_null("/root/ObjectPool")
            if object_pool:
                object_pool.return_object(self)
    )
