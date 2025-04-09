extends Node3D


@onready var can_attack = true
@onready var timer = $Timer
@export var Cool_down = 1.0


func _ready():
    timer.set_wait_time(Cool_down)
    
   
func sword_swing():
    if can_attack:
        $AnimationPlayer.play("swing")
        can_attack = false
        timer.start()
    else:
        return


func _on_timer_timeout() -> void:
    can_attack = true
    
