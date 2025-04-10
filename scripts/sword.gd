extends Node3D










@export var Cool_down = 10.0 #set in player scene
@export var damage: float = 25.0
@onready var hitArea = $"Sword Pivot/HitArea"
var player : Node3D
@onready var can_swing = true




func _ready():
    hitArea.monitoring = false
     

func _physics_process(delta: float) -> void:
    pass
        
        
        

        
        
 
func sword_swing():
    
        
    if can_swing:
        can_swing = false
        hitArea.monitoring = true
        $AnimationPlayer.play("swing")
        await $AnimationPlayer.animation_finished
        hitArea.monitoring = false
        await get_tree().create_timer(Cool_down).timeout
        can_swing = true
    else:
        return
    


func _on_hit_area_body_entered(body: Node3D) -> void:
    
    if body.is_in_group('enemy') and body.has_method("take_damage"):
        body.take_damage(damage)
       
