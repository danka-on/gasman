extends CharacterBody3D

@export var speed : float = 3.0
@export var max_health : float = 50.0
var current_health : float = max_health
var gravity : float = 9.8
var player = null
@export var damage : float = 10.0
@export var damage_cooldown : float = 1.0
var can_damage = true

@export var health_pack_scene : PackedScene = preload("res://health_pack.tscn")
@export var ammo_pack_scene : PackedScene = preload("res://ammo_pack.tscn")
@export var explosion_scene : PackedScene = preload("res://Explosion.tscn")

@export var explosion_radius : float = 5.0 # Blast radius
@export var explosion_damage : float = 20.0 # Damage to player
@export var explosion_force : float = 10.0 # Knockback strength

@export var drop_chance : float = 0.5 # 50% chance to drop

@onready var enemy_mesh = $EnemyMesh # Reference to mesh

func _ready():
	current_health = max_health
	if enemy_mesh:
		# Ensure material override exists
		if not enemy_mesh.material_override:
			enemy_mesh.material_override = StandardMaterial3D.new()
		# Clear surface material if present
		if enemy_mesh.get_surface_override_material(0):
			enemy_mesh.set_surface_override_material(0, null)
		update_color()
	else:
		print("Ready - EnemyMesh missing: ", enemy_mesh)
		
func _physics_process(delta):
	if enemy_mesh and enemy_mesh.material_override: # Safe check
		update_color() # Initial update here
		
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
	if player and player.has_method("play_hit_sound"):
		player.play_hit_sound()
	if enemy_mesh and enemy_mesh.material_override:
		update_color()
	else:
		print("Take damage - EnemyMesh issue: ", enemy_mesh, " Material: ", enemy_mesh.material_override if enemy_mesh else "null")
	if current_health <= 0:
		die()

func die():
	if player:
		player.add_score(5)
		if randf() < drop_chance:
			var drop = health_pack_scene if randf() < 0.5 else ammo_pack_scene
			var instance = drop.instantiate()
			instance.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)
			get_parent().add_child(instance)
	
	var explosion = explosion_scene.instantiate()
	explosion.global_transform.origin = global_transform.origin
	get_parent().add_child(explosion)
	
	var blast_area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = explosion_radius # 5.0
	collision_shape.shape = sphere_shape
	blast_area.add_child(collision_shape)
	# Center the sphere slightly above ground
	blast_area.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)
	blast_area.collision_layer = 2
	blast_area.collision_mask = 1
	get_parent().add_child(blast_area)
	
	await get_tree().create_timer(0.05).timeout
	var bodies = blast_area.get_overlapping_bodies()
	
	for body in bodies:
		if body == player:
			var player_pos = player.global_transform.origin
			var blast_pos = blast_area.global_transform.origin
			
			player.take_damage(explosion_damage)
			var direction = (player_pos - blast_pos).normalized()
			player.apply_knockback(direction, explosion_force) # Use exported force
			
	await get_tree().create_timer(0.1).timeout
	blast_area.queue_free()
	
	hide()
	set_physics_process(false)
	await get_tree().create_timer(0.7).timeout
	queue_free()

	

func _on_hitbox_body_entered(body):
	if body == player and can_damage:
		player.take_damage(damage)
		can_damage = false
		if is_inside_tree():
			await get_tree().create_timer(damage_cooldown).timeout
		can_damage = true

func update_color():
	var new_material = enemy_mesh.material_override.duplicate()
	if current_health <= 10.0:
		new_material.albedo_color = Color(1, 0, 0, 1) # Red
		new_material.emission_enabled = true
		new_material.emission = Color(1, 0, 0, 1) # Red glow
		new_material.emission_energy = 2.0 # Glow intensity
	else:
		new_material.albedo_color = Color(0, 0.5, 0.5, 1) # Teal
		new_material.emission_enabled = false # No glow
	enemy_mesh.material_override = new_material
