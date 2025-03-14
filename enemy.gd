extends CharacterBody3D

@export var speed : float = 3.0
@export var max_health : float = 50.0
var current_health : float = max_health
var gravity : float = 9.8
var player = null
@export var damage : float = 10.0
@export var damage_cooldown : float = 1.0
var can_damage = true

func _ready():
	current_health = max_health

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if player:
		var direction = (player.global_transform.origin - global_transform.origin).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()

func take_damage(amount: float):
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	if current_health <= 0:
		die()

func die():
	queue_free()

func _on_hitbox_body_entered(body):
	if body == player and can_damage:
		player.take_damage(damage)
		can_damage = false
		if is_inside_tree(): # Check if still in scene tree
			await get_tree().create_timer(damage_cooldown).timeout
		can_damage = true
