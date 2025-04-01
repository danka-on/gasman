extends RigidBody3D

@export var gas_amount : float = 30.0

func _ready():
    apply_central_impulse(Vector3(0, 5, 0)) # Toss up

func _on_body_entered(body):
    if body.is_in_group("player") and not is_queued_for_deletion():
        if body.has_method("add_gas"):
            body.add_gas(gas_amount)
        queue_free()
