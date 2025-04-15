extends Area3D

signal enemy_hit(is_headshot: bool)  # Modified signal to include headshot info

@export var speed : float = 20.0
var velocity : Vector3
@export var hit_effect_scene : PackedScene = preload("res://scenes/hit_effect.tscn")
@export var can_ignite_gas: bool = true

func _ready():
    add_to_group("bullet")  # Add bullet to group for detection
    collision_layer = 4  # Bullets - layer 3 (value 4)
    collision_mask = 2 | 8  # Detect hitboxes (layer 2) AND gas clouds (layer 4, value 8)
    
    # Debug info
    print("Bullet created with layer: ", collision_layer, " mask: ", collision_mask)
    
    #bullet despawn after 5 seconds
    await get_tree().create_timer(5).timeout 
    queue_free()
    
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
            body.take_damage(10, false)  # Specify this is not gas damage
            emit_signal("enemy_hit", false)  # Signal normal hit
    hit()

func _on_area_entered(area):
    print("Bullet entered area: ", area.name)
    # Check if this is a hitbox
    if area.get_parent().is_in_group("enemy"):
        if area.name == "HeadHitbox":
            area.get_parent().take_damage(10, false, true)  # Headshot
            emit_signal("enemy_hit", true)  # Signal headshot
        elif area.name == "Hitbox":
            area.get_parent().take_damage(10, false, false)  # Body shot
            emit_signal("enemy_hit", false)  # Signal normal hit
    
    # Check if this is a gas cloud
    elif can_ignite_gas and area.is_in_group("gas_cloud") and area.has_method("bullet_hit"):
        area.bullet_hit(self)
    
    hit()

func _on_lifetime_timeout():
    queue_free()
    
    
    
