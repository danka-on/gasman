extends Node3D



@onready var enemy = get_node("/root/Main/enemy")




@onready var can_attack = true
@onready var timer = $Timer
@export var Cool_down = 1.0
@export var damage: float = 25.0
@onready var hitArea = $"Sword Pivot/HitArea"
var player : Node3D




func _ready():
    
    hitArea.monitoring = false
    if enemy:
        print("enemy is lols")
    timer.set_wait_time(Cool_down)
     

func _physics_process(delta: float) -> void:
    if enemy:
        print("enemy is lols FIZEEEEEEEEEK")
        
        
        

        
        
        
func sword_swing():
    
    
    
    if can_attack:
        hitArea.monitoring = true
        $AnimationPlayer.play("swing")
        
        can_attack = false
        timer.start()
    else:
        return


func _on_timer_timeout() -> void:
    can_attack = true
    



func _on_hit_area_body_entered(body: Node3D) -> void:
    
    if body.is_in_group('enemy'): #and body.has_method("take_damage"):
        body.take_damage(damage)
       
