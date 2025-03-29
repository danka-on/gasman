extends RigidBody3D

@export var ammo_amount : int = 30

func _ready():
	apply_central_impulse(Vector3(0, 5, 0)) # 5 units up

func _on_body_entered(body):
	if body.has_method("add_ammo"):
		body.add_ammo(ammo_amount)
		queue_free()
