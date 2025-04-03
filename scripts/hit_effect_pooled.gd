# hit_effect_pooled.gd - Updated version
extends Node3D

# Property using modern Godot 4 syntax
var _emitting = false
var emitting: 
    get:
        return _emitting
    set(value):
        _emitting = value
        if value and not $Sparks.emitting:
            visible = true
            $Sparks.emitting = true
            get_tree().create_timer(0.7).timeout.connect(func():
                return_to_pool()
            )

func _ready():
    visible = false

func reset():
    visible = true
    # Don't automatically emit particles - let the setter handle that

func return_to_pool():
    if not visible:
        return
        
    visible = false
    $Sparks.emitting = false
    
    var object_pool = get_node_or_null("/root/ObjectPool")
    if object_pool:
        object_pool.return_object(self)
