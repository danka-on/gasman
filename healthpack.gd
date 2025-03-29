extends RigidBody3D

@export var health_amount : float = 25.0

func _ready():
	# Give it a small upward toss
	apply_central_impulse(Vector3(0, 5, 0)) # 5 units up

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(-health_amount)
		queue_free()
