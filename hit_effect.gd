extends Node3D

func _ready():
	$Sparks.emitting = true
	await get_tree().create_timer(0.7).timeout
	queue_free()
