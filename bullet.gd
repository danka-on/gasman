extends Area3D

@export var speed : float = 20.0
var velocity : Vector3
@export var hit_effect_scene : PackedScene = preload("res://hit_effect.tscn")

func _ready():
    collision_layer = 3 # Bullets
    collision_mask = 2 # Hits enemies

func _physics_process(delta):
    global_transform.origin += velocity * delta

func _on_area_entered(area):
    if area.name == "Hitbox" and area.get_parent().has_method("take_damage") and area.get_parent() != get_tree().get_first_node_in_group("player"):
        area.get_parent().take_damage(10.0)
        var hit_effect = hit_effect_scene.instantiate()
        hit_effect.global_transform.origin = global_transform.origin
        get_parent().add_child(hit_effect)
        print("Hit registered at: ", global_transform.origin)
    queue_free()

func _on_lifetime_timeout():
    queue_free()
