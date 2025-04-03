extends CharacterBody3D

signal enemy_died

@export var speed : float = 3.0
@export var max_health : float = 50.0
@export var active_pursuit_range : float = 20.0  # Only actively chase within this range
var current_health : float = max_health
var gravity : float = 9.8
var player = null
@export var damage : float = 10.0
@export var damage_cooldown : float = 1.0
var can_damage = true
var last_damage_time : float = 0.0
var update_tick : int = 0
var tick_interval : int = 0  # Will be set randomly to stagger AI updates

@export var gas_pack_scene : String = "res://scenes/gas_pack.tscn"
@export var health_pack_scene : String = "res://scenes/health_pack.tscn"
@export var ammo_pack_scene : String = "res://scenes/ammo_pack.tscn"
@export var explosion_scene : String = "res://scenes/Explosion.tscn"

@export var explosion_radius : float = 5.0 # Blast radius
@export var explosion_damage : float = 20.0 # Damage to player
@export var explosion_force : float = 10.0 # Knockback strength

@export var drop_chance : float = 0.5 # 50% chance to drop

@onready var enemy_mesh = $EnemyMesh # Reference to mesh
@onready var hitbox = $Hitbox # Add reference

# Store a reference to the red and normal materials to avoid constant recreation
var red_material = null
var normal_material = null

enum State {IDLE, PURSUE, ATTACK}
var current_state = State.IDLE
var distance_to_player : float = 999999.0

func _ready():
    current_health = max_health
    
    # Add to 'enemies' group for easier management
    add_to_group("enemies")
    
    # Set a random tick interval to stagger AI updates
    tick_interval = randi() % 5 + 1  # Random interval between 1 and 5
    
    if enemy_mesh:
        # Create materials once
        if not red_material:
            red_material = StandardMaterial3D.new()
            red_material.albedo_color = Color(1, 0, 0, 1)
            red_material.emission_enabled = true
            red_material.emission = Color(1, 0, 0, 1)
            red_material.emission_energy_multiplier = 2.0
            
        if not normal_material:
            normal_material = StandardMaterial3D.new()
            normal_material.albedo_color = Color(0, 0.5, 0.5, 1)
            normal_material.emission_enabled = false
        
        # Ensure material override exists
        if not enemy_mesh.material_override:
            enemy_mesh.material_override = normal_material.duplicate()
        update_color()
    else:
        print("Ready - EnemyMesh missing: ", enemy_mesh)
        
func _physics_process(delta):
    if not is_instance_valid(self) or not visible:
        return
        
    # Only update AI logic on specific ticks to reduce CPU usage
    update_tick = (update_tick + 1) % tick_interval
    
    # Always apply gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
    
    # Only process complete AI on tick interval
    if update_tick == 0 and is_instance_valid(player):
        distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
        
        # Determine state based on distance
        if distance_to_player <= 1.5:
            current_state = State.ATTACK
        elif distance_to_player <= active_pursuit_range:
            current_state = State.PURSUE
        else:
            current_state = State.IDLE
            
        # Process behavior based on state
        match current_state:
            State.IDLE:
                velocity.x = move_toward(velocity.x, 0, 0.5)
                velocity.z = move_toward(velocity.z, 0, 0.5)
            
            State.PURSUE:
                var direction = (player.global_transform.origin - global_transform.origin).normalized()
                velocity.x = direction.x * speed
                velocity.z = direction.z * speed
                
                # Update color less frequently to reduce overhead
                if enemy_mesh and enemy_mesh.material_override:
                    update_color() 
                    
            State.ATTACK:
                if can_damage:
                    if Time.get_ticks_msec() / 1000.0 - last_damage_time >= damage_cooldown:
                        player.take_damage(damage)
                        last_damage_time = Time.get_ticks_msec() / 1000.0
                        can_damage = false
                        get_tree().create_timer(damage_cooldown).timeout.connect(func():
                            if is_instance_valid(self):
                                can_damage = true
                        )
    
    move_and_slide()

func take_damage(amount: float):
    current_health -= amount
    current_health = clamp(current_health, 0, max_health)
    
    if is_instance_valid(player) and player.has_method("play_hit_sound"):
        player.play_hit_sound()
        
    if enemy_mesh and enemy_mesh.material_override:
        update_color()
    else:
        print("Take damage - EnemyMesh issue: ", enemy_mesh, " Material: ", enemy_mesh.material_override if enemy_mesh else "null")
        
    if current_health <= 0:
        die()

func die():
    # Prevent double deaths
    if not visible or not is_instance_valid(self):
        return
        
    emit_signal("enemy_died")
    
    if is_instance_valid(player):
        player.add_score(5)
        if randf() < drop_chance:
            var drop_options = [health_pack_scene, ammo_pack_scene, gas_pack_scene]
            var drop_scene = drop_options[randi() % drop_options.size()]
            
            # Get from object pool with error handling
            var object_pool = get_node_or_null("/root/ObjectPool")
            if object_pool:
                var instance = object_pool.get_object(drop_scene)
                if instance:
                    instance.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)
    
    # Get explosion from object pool with error handling
    var object_pool = get_node_or_null("/root/ObjectPool")
    if object_pool:
        var explosion = object_pool.get_object(explosion_scene)
        if explosion:
            explosion.global_transform.origin = global_transform.origin
    
    # Check player distance for explosion damage
    if is_instance_valid(player):
        distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
        if distance_to_player <= explosion_radius:
            var direction = (player.global_transform.origin - global_transform.origin).normalized()
            player.take_damage(explosion_damage)
            player.apply_knockback(direction, explosion_force)
    
    # Disable collision
    if is_instance_valid(hitbox):
        hitbox.collision_layer = 0
        hitbox.collision_mask = 0
    
    # Remove from scene after explosion
    hide()
    set_physics_process(false)
    
    # Completely remove after a delay
    get_tree().create_timer(0.5).timeout.connect(func():
        if is_instance_valid(self):
            queue_free()
    )

func _on_hitbox_body_entered(body):
    if body == player and can_damage:
        player.take_damage(damage)
        can_damage = false
        get_tree().create_timer(damage_cooldown).timeout.connect(func():
            if is_instance_valid(self):
                can_damage = true
        )

func update_color():
    # Use the pre-created materials instead of creating new ones each time
    if enemy_mesh and enemy_mesh.material_override:
        if current_health <= 10.0:
            enemy_mesh.material_override = red_material.duplicate()
        else:
            enemy_mesh.material_override = normal_material.duplicate()
