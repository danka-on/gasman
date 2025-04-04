extends Node3D

func _ready():
    $Blast.emitting = true
    $BoomSound.play()
    await get_tree().create_timer(0.7).timeout # Match lifetime + buffer
    queue_free()
