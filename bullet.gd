extends Area3D

@export var speed : float = 20.0 # Set by player
var velocity : Vector3

func _physics_process(delta):
	global_transform.origin += velocity * delta

func _on_area_entered(area):
	if area.get_parent().has_method("take_damage"): # Check if it’s an enemy
		area.get_parent().take_damage(10.0) # Deal 10 damage
	queue_free() # Bullet disappears on hit

func _on_lifetime_timeout():
	queue_free() # Bullet disappears after time
