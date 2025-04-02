extends Node3D

var emitting = false setget set_emitting, get_emitting

func _ready():
    visible = false

func set_emitting(value):
    if value and not $Sparks.emitting:
        visible = true
        $Sparks.emitting = true
        get_tree().create_timer(0.7).timeout.connect(func():
            return_to_pool()
        )

func get_emitting():
    return $Sparks.emitting

func return_to_pool():
    var object_pool = get_node("/root/ObjectPool")
    if object_pool:
        object_pool.return_object(self)
