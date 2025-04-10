extends Area3D

@export var speed : float = 20.0
var velocity : Vector3
@export var hit_effect_scene : PackedScene = preload("res://scenes/hit_effect.tscn")
@export var can_ignite_gas: bool = true

func _ready():
    collision_layer = 4 # Bullets - layer 3 (value 4)
    collision_mask = 1 | 8 # Hits enemy bodies (layer 1, value 1) AND gas clouds (layer 4, value 8)
    await get_tree().create_timer(5).timeout 
    'var t = Timer.new()
    t.set_wait_time(5)
    t.set_one_shot(true)
    t.connect("timeout", queue_free)
    add_child(t)
    t.start()
    '
    
    # Debug info
    print("Bullet created with layer: ", collision_layer, " mask: ", collision_mask)

func _physics_process(delta):
    transform.origin += velocity * delta

func hit():
    # Prevent multiple calls
    set_physics_process(false)
    
    var hit_effect = hit_effect_scene.instantiate()
    get_parent().add_child(hit_effect)
    hit_effect.global_transform.origin = global_transform.origin
    
    queue_free()

func _on_body_entered(body):
    print("Bullet hit body: ", body.name)
    if body.has_method("take_damage"):
        if body.is_in_group("enemy"):
            print("Enemy hit! Applying damage.")
            body.take_damage(10)
    hit()

func _on_area_entered(area):
    # Check if this is a gas cloud
    if can_ignite_gas and area.is_in_group("gas_cloud") and area.has_method("bullet_hit"):
        # Trigger the gas cloud explosion
        area.bullet_hit(self)
    
    # Always call hit regardless
    hit()

func _on_lifetime_timeout():
    queue_free()
